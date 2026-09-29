import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/user_message.dart';
import '../../../core/models/user_context.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/context_provider.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/industrial_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../../auth/domain/auth_provider.dart';
import '../../actions/presentation/mobile_action_search.dart';
import '../../../core/providers/module_provider.dart';
import '../data/assistant_source_navigation.dart';
import '../data/ai_assistant_models.dart';
import '../data/ai_assistant_repository.dart';
import 'ai_assistant_memory_screen.dart';
import 'ai_assistant_sharing_screen.dart';
import 'ai_assistant_credits_screen.dart';
import 'ai_assistant_documents_screen.dart';

class AiAssistantChatScreen extends ConsumerStatefulWidget {
  const AiAssistantChatScreen({
    super.key,
    this.conversationId,
    this.initialPrompt,
  });

  final int? conversationId;
  final String? initialPrompt;

  @override
  ConsumerState<AiAssistantChatScreen> createState() =>
      _AiAssistantChatScreenState();
}

class _AiAssistantChatScreenState extends ConsumerState<AiAssistantChatScreen> {
  static const _sourceBaseUrl = String.fromEnvironment(
    'ASSISTANT_SOURCE_BASE_URL',
    defaultValue: 'https://lk.xn--1-xtbgmf.xn--p1ai',
  );
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<AiMessageModel> _messages = const [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isPreviewLoading = false;
  bool _isExecutingAction = false;
  String? _error;
  String? _actionError;
  int? _conversationId;
  AiActionPreviewModel? _activePreview;
  CancelToken? _sendCancelToken;
  int _requestRevision = 0;
  String? _progress;
  String? _activeRequestId;
  Timer? _progressTimer;
  bool _isQuoting = false;
  String? _quotingRequestId;
  int? _nextHistoryPage;
  bool _loadingHistory = false;
  String _profile = 'normal';
  bool _canWrite = true;
  bool _canManageParticipants = false;
  _PendingChat? _failedRequest;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    ref.listenManual(
      authProvider.select(
        (state) => (state.user?.serverId, state.user?.currentOrganizationId),
      ),
      (previous, next) {
        if (previous != next) _resetForOrganizationChange();
      },
    );
    _controller.text = widget.initialPrompt ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void didUpdateWidget(covariant AiAssistantChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _stopSending();
      _conversationId = widget.conversationId;
      _messages = const [];
      _failedRequest = null;
      _loadingHistory = false;
      _bootstrap();
    }
  }

  @override
  void dispose() {
    final requestId = _activeRequestId;
    if (requestId != null) {
      unawaited(
        ref
            .read(aiAssistantRepositoryProvider)
            .cancelRequest(requestId)
            .catchError((Object _) {}),
      );
    }
    _progressTimer?.cancel();
    _sendCancelToken?.cancel('Экран диалога закрыт.');
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_conversationId != null) {
      await _loadConversation(_conversationId!);
      return;
    }

    setState(() {
      _isLoading = false;
    });

    if ((widget.initialPrompt ?? '').trim().isNotEmpty) {
      await _sendMessage(widget.initialPrompt!.trim());
    }
  }

  Future<void> _loadConversation(int id) async {
    final requestRevision = ++_requestRevision;
    setState(() {
      _isLoading = true;
      _error = null;
      _actionError = null;
      _activePreview = null;
    });

    try {
      final details = await ref
          .read(aiAssistantRepositoryProvider)
          .fetchConversation(id);

      if (!mounted || requestRevision != _requestRevision) return;
      setState(() {
        _conversationId = details.conversation.id;
        _canWrite = details.conversation.canWrite;
        _canManageParticipants = details.conversation.canManageParticipants;
        _messages = details.messages;
        _nextHistoryPage = null;
        _isLoading = false;
      });

      await _loadHistory(id, requestRevision);
      _scrollToBottom();
    } catch (error) {
      if (!mounted || requestRevision != _requestRevision) return;
      setState(() {
        _error = UserMessage.fromError(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHistory(int id, int revision, {int page = 1}) async {
    if (_loadingHistory) return;
    _loadingHistory = true;
    try {
      final result = await ref
          .read(aiAssistantRepositoryProvider)
          .fetchMessages(id, page: page);
      if (!mounted || revision != _requestRevision || id != _conversationId) {
        return;
      }
      setState(() {
        final combined =
            page == 1 ? result.items : [...result.items, ..._messages];
        final ids = <int>{};
        _messages = combined.where((message) => ids.add(message.id)).toList();
        _nextHistoryPage = result.nextPage;
      });
    } catch (error) {
      if (mounted && revision == _requestRevision) {
        _showSnackBar(_resolveError(error));
      }
    } finally {
      _loadingHistory = false;
    }
  }

  Future<void> _pollProgress(String requestId, int revision) async {
    try {
      final progress = await ref
          .read(aiAssistantRepositoryProvider)
          .fetchRequest(requestId);
      if (!mounted || revision != _requestRevision) return;
      final stage = progress['stage']?.toString();
      setState(
        () =>
            _progress = switch (stage) {
              'searching' => 'Проверяем источники',
              'tools' => 'Получаем данные',
              'generating' => 'Готовим ответ',
              'validating' => 'Проверяем ответ',
              _ => 'Ассистент готовит ответ',
            },
      );
    } catch (_) {}
  }

  Future<void> _sendMessage([String? forcedValue, bool retry = false]) async {
    final failed = retry ? _failedRequest : null;
    final message = (failed?.message ?? forcedValue ?? _controller.text).trim();
    if (message.isEmpty ||
        _isLoading ||
        _isSending ||
        _isQuoting ||
        !_canWrite) {
      return;
    }

    final requestId = failed?.requestId ?? _newRequestId();
    final requestRevision = ++_requestRevision;
    final conversationAtSend = failed?.conversationId ?? _conversationId;
    final assistantContext = failed?.context ?? _assistantContext();
    final profile = failed?.profile ?? _profile;
    _isQuoting = true;
    _quotingRequestId = requestId;
    final quote =
        failed?.quote ??
        await _confirmQuote(
          message,
          requestId,
          conversationAtSend,
          assistantContext,
          profile,
        );
    _isQuoting = false;
    if (quote == null ||
        !mounted ||
        requestRevision != _requestRevision ||
        conversationAtSend != _conversationId) {
      return;
    }
    _failedRequest = _PendingChat(
      requestId: requestId,
      message: message,
      conversationId: conversationAtSend,
      context: assistantContext,
      profile: profile,
      quote: quote,
    );
    final optimistic = AiMessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      role: 'user',
      content: message,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages = [..._messages, optimistic];
      _isSending = true;
      _progress = 'Отправляем запрос';
      _error = null;
      _actionError = null;
      _activePreview = null;
      if (forcedValue == null) {
        _controller.clear();
      }
    });

    _scrollToBottom();

    try {
      _activeRequestId = requestId;
      _progressTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _pollProgress(requestId, requestRevision),
      );
      _sendCancelToken = CancelToken();
      if (mounted) setState(() => _progress = 'Ассистент готовит ответ');
      final result = await ref
          .read(aiAssistantRepositoryProvider)
          .sendMessageRequest(
            message: message,
            requestId: requestId,
            quoteId: quote.id,
            maxConfirmed: quote.maxConfirmed,
            profile: profile,
            conversationId: conversationAtSend,
            context: assistantContext,
            cancelToken: _sendCancelToken,
          );

      if (!mounted ||
          requestRevision != _requestRevision ||
          conversationAtSend != _conversationId) {
        return;
      }
      setState(() {
        _conversationId = result.conversationId;
        if (conversationAtSend == null) _canManageParticipants = true;
        _failedRequest = null;
        if (result.message != null) {
          _messages = [..._messages, result.message!];
        }
        _isSending = false;
        _progress = null;
      });
      if (result.creditUsage?.chargingEnabled == false) {
        _showSnackBar(
          'Тестовый режим: списания выключены. Фактическое списание — 0 ед. МОСТ.',
        );
      } else if (result.creditUsage?.actualCharge != null &&
          (double.tryParse(result.creditUsage!.actualCharge!) ?? 0) > 0) {
        _showSnackBar('Списано: ${result.creditUsage!.actualCharge} ед. МОСТ');
      }
    } catch (error) {
      if (!mounted || requestRevision != _requestRevision) return;
      setState(() {
        _messages =
            _messages.where((item) => item.id != optimistic.id).toList();
        _error = _resolveError(error);
        _isSending = false;
        _progress = null;
      });
    } finally {
      if (requestRevision == _requestRevision) {
        _sendCancelToken = null;
        _activeRequestId = null;
        _progressTimer?.cancel();
      }
    }

    _scrollToBottom();
  }

  Future<AiCreditQuoteModel?> _confirmQuote(
    String message,
    String requestId,
    int? conversationId,
    Map<String, dynamic> assistantContext,
    String profile,
  ) async {
    try {
      final quote = await ref
          .read(aiAssistantRepositoryProvider)
          .quoteCredits(
            message: message,
            requestId: requestId,
            profile: profile,
            conversationId: conversationId,
            context: assistantContext,
          );
      if (!mounted || requestId != _quotingRequestId) return null;
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Оценка расхода'),
              content: Text(
                'Оценка до ${quote.amount} ${quote.unit}. Фактическое списание будет рассчитано после ответа.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Продолжить'),
                ),
              ],
            ),
      );
      return confirmed == true
          ? AiCreditQuoteModel(
            id: quote.id,
            maxConfirmed: true,
            amount: quote.amount,
            unit: quote.unit,
          )
          : null;
    } catch (error) {
      if (mounted) _showSnackBar(_resolveError(error));
      return null;
    }
  }

  Future<void> _stopSending() async {
    final requestId = _activeRequestId;
    final token = _sendCancelToken;
    _progressTimer?.cancel();
    _activeRequestId = null;
    _requestRevision++;
    if (mounted) {
      setState(() {
        _isSending = false;
        _progress = null;
      });
    }
    if (requestId != null) {
      try {
        await ref.read(aiAssistantRepositoryProvider).cancelRequest(requestId);
        token?.cancel('Пользователь остановил запрос.');
      } catch (error) {
        if (mounted) {
          _showSnackBar(
            'Сервер не подтвердил остановку. ${_resolveError(error)}',
          );
        }
      }
    }
  }

  void _resetForOrganizationChange() {
    _progressTimer?.cancel();
    _activeRequestId = null;
    _sendCancelToken?.cancel('Организация изменена.');
    _requestRevision++;
    _quotingRequestId = null;
    _loadingHistory = false;
    if (!mounted) return;
    setState(() {
      _messages = const [];
      _conversationId = null;
      _activePreview = null;
      _actionError = null;
      _error = null;
      _isSending = false;
      _progress = null;
      _isLoading = false;
      _isPreviewLoading = false;
      _isExecutingAction = false;
      _canWrite = true;
      _canManageParticipants = false;
      _nextHistoryPage = null;
      _failedRequest = null;
    });
  }

  String _newRequestId() {
    final random = Random.secure();
    String hex(int length) =>
        List.generate(
          length,
          (_) => random.nextInt(16).toRadixString(16),
        ).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-${(8 + random.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
  }

  Future<void> _previewAction(AiAssistantActionModel action) async {
    if (action.type == 'navigate') {
      final navigation = action.target?['navigation'];
      final url =
          (navigation is Map ? navigation['url'] : null) ??
          action.target?['url'];
      final uri = ref
          .read(aiAssistantRepositoryProvider)
          .sourceUri(url?.toString());
      if (uri == null) {
        _showSnackBar('Ссылка недоступна.');
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!_canWrite) return;
    final revision = _requestRevision;
    final conversation = _conversationId;
    if (_isPreviewLoading || _isExecutingAction || !action.allowed) {
      return;
    }

    setState(() {
      _isPreviewLoading = true;
      _actionError = null;
      _activePreview = null;
    });

    try {
      final preview = await ref
          .read(aiAssistantRepositoryProvider)
          .previewAction(action: action, conversationId: _conversationId);

      if (!mounted ||
          revision != _requestRevision ||
          conversation != _conversationId) {
        return;
      }

      setState(() {
        _activePreview = preview;
        _isPreviewLoading = false;
      });
    } catch (error) {
      if (!mounted ||
          revision != _requestRevision ||
          conversation != _conversationId) {
        return;
      }

      setState(() {
        _actionError = _resolveError(error);
        _isPreviewLoading = false;
      });
    }

    _scrollToBottom();
  }

  Future<void> _executeActivePreview() async {
    final revision = _requestRevision;
    final conversation = _conversationId;
    final preview = _activePreview;
    if (preview == null || _isExecutingAction || !preview.executable) {
      return;
    }

    setState(() {
      _isExecutingAction = true;
      _actionError = null;
    });

    try {
      final result = await ref
          .read(aiAssistantRepositoryProvider)
          .executeAction(preview: preview, conversationId: _conversationId);

      if (!mounted ||
          revision != _requestRevision ||
          conversation != _conversationId) {
        return;
      }

      setState(() {
        _activePreview = null;
        _isExecutingAction = false;
        if (_conversationId == null && result.message != null) {
          _messages = [..._messages, result.message!];
        }
      });

      if (_conversationId != null) {
        await _loadConversation(_conversationId!);
      } else if (result.messageText != null) {
        _showSnackBar(result.messageText!);
      }
    } catch (error) {
      if (!mounted ||
          revision != _requestRevision ||
          conversation != _conversationId) {
        return;
      }

      setState(() {
        _actionError = _resolveError(error);
        _isExecutingAction = false;
      });
    }

    _scrollToBottom();
  }

  void _rejectActionPreview() {
    setState(() {
      _activePreview = null;
      _actionError = null;
    });
  }

  String _resolveError(Object error) {
    if (error is ApiException) {
      return switch (error.statusCode) {
        403 => 'Диалог недоступен или у пользователя нет прав.',
        422 => UserMessage.fromError(error),
        429 => UserMessage.fromError(error),
        _ => UserMessage.fromError(error),
      };
    }

    return UserMessage.fromError(error);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openReportArtifact(AiAssistantArtifact artifact) async {
    final revision = _requestRevision;
    AiDownloadedReport? report;
    var opened = false;
    try {
      report = await ref
          .read(aiAssistantRepositoryProvider)
          .downloadReport(artifact);
      if (!mounted || revision != _requestRevision) return;
      opened = (await OpenFilex.open(report.path)).type == ResultType.done;
      if (!opened) _showSnackBar('Не удалось открыть отчёт.');
    } catch (error) {
      if (mounted && revision == _requestRevision) {
        _showSnackBar(_resolveError(error));
      }
    } finally {
      if (report != null) {
        final downloaded = report;
        if (opened) {
          unawaited(
            Future<void>.delayed(
              const Duration(minutes: 2),
              downloaded.dispose,
            ),
          );
        } else {
          await downloaded.dispose();
        }
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  AssistantSourceTarget? _sourceTarget(AiAssistantEvidenceModel evidence) {
    final projectId = evidence.projectId ??
        (evidence.entityType == 'project' ? evidence.entityId : null);
    return resolveAssistantSourceTarget(
      evidence.url,
      sourceBaseUrl: _sourceBaseUrl,
      projectId: projectId,
    );
  }

  String _sourceActionLabel(AiAssistantEvidenceModel evidence) {
    final target = _sourceTarget(evidence);
    if (target == null) return 'Предпросмотр источника';
    if (target.webPath != null) return target.label;
    final destination = visibleMobileDestinations(
      ref.read(supportedMobileModulesProvider),
    ).where((item) => item.matches(target.mobileRoute!));
    return destination.isEmpty
        ? 'Предпросмотр источника'
        : 'Открыть раздел «${destination.first.shortTitle}»';
  }

  Future<void> _openAssistantSource(AiAssistantEvidenceModel evidence) async {
    final target = _sourceTarget(evidence);
    if (target != null && target.mobileRoute != null) {
      final destinations = visibleMobileDestinations(
        ref.read(supportedMobileModulesProvider),
      );
      final matchingDestinations = destinations
          .where((item) => item.matches(target.mobileRoute!))
          .toList(growable: false);
      final destination = matchingDestinations.isEmpty
          ? null
          : matchingDestinations.first;
      final selectedProject = ref.read(projectsProvider).selectedProject;
      final projectContextMatches = target.projectId == null ||
          selectedProject?.serverId.toString() == target.projectId;
      if (destination != null &&
          (!destination.requiresProject || projectContextMatches)) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: destination.builder,
          ),
        );
        return;
      }
    }

    final webPath = target?.webPath ??
        (target?.projectId == null
            ? null
            : '/dashboard/projects/${Uri.encodeComponent(target!.projectId!)}');
    if (webPath != null) {
      final uri = ref
          .read(aiAssistantRepositoryProvider)
          .sourceUri(webPath);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(evidence.title, style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Источник: ${evidence.source ?? evidence.entityType ?? 'данные помощника'}'),
            if (evidence.excerpt != null) ...[
              const SizedBox(height: 8),
              Text(evidence.excerpt!),
            ],
            if (evidence.entityId != null) Text('Запись №${evidence.entityId}'),
            if (evidence.projectId != null) Text('Объект №${evidence.projectId}'),
            if (evidence.fetchedAt != null)
              Text('Получено: ${evidence.fetchedAt!.toLocal().toString().split('.').first}'),
            const SizedBox(height: 12),
            Text('В мобильном приложении для этого источника нет доступного перехода.'),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _assistantContext() {
    final selectedProject = ref.read(projectsProvider).selectedProject;
    final userContext = ref.read(userContextProvider);
    final entityRefs = <Map<String, dynamic>>[];
    final filters = <String, dynamic>{};
    final uiState = <String, dynamic>{
      'assistant_path': 'mobile/ai-assistant/chat',
      'client': 'mobile',
      'user_context': _userContextSlug(userContext),
    };

    if (selectedProject != null) {
      entityRefs.add({
        'type': 'project',
        'id': selectedProject.serverId,
        'label': selectedProject.name,
      });
      filters['project_id'] = selectedProject.serverId;
      uiState['selected_project_id'] = selectedProject.serverId;
      uiState['selected_project_name'] = selectedProject.name;
    }

    return {
      'source_module': 'ai-assistant',
      'source_route': 'mobile/ai-assistant/chat',
      'entity_refs': entityRefs,
      'filters': filters,
      'ui_state': uiState,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Документы',
            icon: const Icon(Icons.description_outlined),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AiAssistantDocumentsScreen(),
                  ),
                ),
          ),

          IconButton(
            tooltip: 'Память',
            icon: const Icon(Icons.psychology_outlined),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AiAssistantMemoryScreen(),
                  ),
                ),
          ),
          IconButton(
            tooltip: 'Баланс',
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AiAssistantCreditsScreen(),
                  ),
                ),
          ),
          if (_conversationId != null && _canManageParticipants)
            IconButton(
              tooltip: 'Доступ к чату',
              icon: const Icon(Icons.group_outlined),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => AiAssistantSharingScreen(
                            conversationId: _conversationId!,
                          ),
                    ),
                  ),
            ),
        ],
        title: Text(
          _conversationId == null ? 'Новый чат' : 'Диалог #$_conversationId',
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            child: Text(
              'Ассистент помогает держать рабочий контекст по проектам, срокам и управленческим решениям.',
              style: AppTypography.bodyMedium(
                context,
              ).copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Material(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTypography.bodyMedium(
                            context,
                          ).copyWith(color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_error != null && _failedRequest != null)
            TextButton(
              onPressed: _isSending ? null : () => _sendMessage(null, true),
              child: const Text('Повторить запрос без повторного списания'),
            ),
          DropdownButton<String>(
            value: _profile,
            items: const [
              DropdownMenuItem(value: 'short', child: Text('Краткий ответ')),
              DropdownMenuItem(value: 'normal', child: Text('Обычный ответ')),
              DropdownMenuItem(
                value: 'detailed',
                child: Text('Подробный ответ'),
              ),
            ],
            onChanged:
                _isSending || _isQuoting
                    ? null
                    : (value) => setState(() => _profile = value ?? 'normal'),
          ),
          if (_nextHistoryPage != null)
            TextButton(
              onPressed:
                  () => _loadHistory(
                    _conversationId!,
                    _requestRevision,
                    page: _nextHistoryPage!,
                  ),
              child: const Text('Ранние сообщения'),
            ),
          Expanded(
            child:
                _isLoading
                    ? const AppLoadingState(message: 'Загружаем диалог')
                    : _messages.isEmpty
                    ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        IndustrialCard(
                          child: AppEmptyState(
                            icon: Icons.smart_toy_outlined,
                            title: 'Ассистент готов',
                            description:
                                'Начните диалог с вопроса по рискам, срокам, финансам или подрядчикам.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              _quickPrompts.map((prompt) {
                                return ActionChip(
                                  label: Text(prompt),
                                  onPressed: () {
                                    _controller.text = prompt;
                                    _sendMessage(prompt);
                                  },
                                );
                              }).toList(),
                        ),
                      ],
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: _messages.length + (_isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isSending && index == _messages.length) {
                          return Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                CircularProgressIndicator(strokeWidth: 2),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _progress ?? 'Ассистент готовит ответ...',
                                  ),
                                ),
                                TextButton(
                                  onPressed: _stopSending,
                                  child: const Text('Стоп'),
                                ),
                              ],
                            ),
                          );
                        }

                        final message = _messages[index];
                        final isUser = message.isUser;
                        final reportArtifacts =
                            isUser
                                ? const <AiAssistantArtifact>[]
                                : message.artifacts
                                    .where((artifact) => artifact.isReport)
                                    .toList(growable: false);
                        final actions =
                            isUser
                                ? const <AiAssistantActionModel>[]
                                : message.actions;
                        final bubbleColor =
                            isUser
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest;
                        final bubbleTextColor =
                            isUser
                                ? _readableForeground(
                                  bubbleColor,
                                  theme.colorScheme.onPrimary,
                                )
                                : theme.colorScheme.onSurface;

                        return Align(
                          alignment:
                              isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.84,
                            ),
                            decoration: BoxDecoration(
                              color: bubbleColor,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (message.content.trim().isNotEmpty)
                                  Text(
                                    message.content,
                                    style: AppTypography.bodyMedium(
                                      context,
                                    ).copyWith(color: bubbleTextColor),
                                  ),
                                if (!isUser &&
                                    (message.evidence.isNotEmpty ||
                                        message.selectedEntities.isNotEmpty ||
                                        message.validationStatus !=
                                            'unverified'))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: _MessageProvenance(
                                      message: message,
                                      onOpen: _openAssistantSource,
                                      actionLabel: _sourceActionLabel,
                                    ),
                                  ),
                                if (reportArtifacts.isNotEmpty)
                                  ...reportArtifacts.map(
                                    (artifact) => Padding(
                                      padding: EdgeInsets.only(
                                        top:
                                            message.content.trim().isEmpty
                                                ? 0
                                                : 12,
                                      ),
                                      child: _ReportArtifactCard(
                                        artifact: artifact,
                                        onOpen:
                                            () => _openReportArtifact(artifact),
                                      ),
                                    ),
                                  ),
                                if (actions.isNotEmpty)
                                  ...actions.map(
                                    (action) => Padding(
                                      padding: EdgeInsets.only(
                                        top:
                                            message.content.trim().isEmpty &&
                                                    reportArtifacts.isEmpty
                                                ? 0
                                                : 12,
                                      ),
                                      child: _AssistantActionCard(
                                        action: action,
                                        isBusy:
                                            _isPreviewLoading ||
                                            _isExecutingAction,
                                        onPreview: () => _previewAction(action),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
          if (_actionError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _ActionErrorPanel(message: _actionError!),
            ),
          if (_activePreview != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _ActionPreviewPanel(
                preview: _activePreview!,
                isExecuting: _isExecutingAction,
                onExecute: _executeActivePreview,
                onCancel: _rejectActionPreview,
              ),
            ),
          if (!_canWrite)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Доступ только для просмотра.'),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'Введите вопрос для ассистента',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed:
                          _isSending || _isQuoting
                              ? null
                              : () => _sendMessage(),
                      child: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _userContextSlug(UserContext context) {
  return switch (context) {
    UserContext.field => 'field',
    UserContext.office => 'office',
  };
}

Color _readableForeground(Color background, Color preferred) {
  if (_contrastRatio(background, preferred) >= 4.5) {
    return preferred;
  }

  final whiteContrast = _contrastRatio(background, Colors.white);
  final blackContrast = _contrastRatio(background, Colors.black87);

  return whiteContrast >= blackContrast ? Colors.white : Colors.black87;
}

class _MessageProvenance extends StatelessWidget {
  const _MessageProvenance({
    required this.message,
    required this.onOpen,
    required this.actionLabel,
  });

  final AiMessageModel message;
  final Future<void> Function(AiAssistantEvidenceModel) onOpen;
  final String Function(AiAssistantEvidenceModel) actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final validationLabel = switch (message.validationStatus) {
      'verified' => 'Проверено',
      'partial' => 'Частично проверено',
      _ => 'Не проверено',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            validationLabel,
            style: AppTypography.caption(context).copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (message.selectedEntities.isNotEmpty)
            Text(
              message.selectedEntities.map((entity) => entity.label).join(', '),
              style: AppTypography.caption(
                context,
              ).copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          if (message.evidence.isNotEmpty)
            ...message.evidence.map(
              (evidence) => TextButton(
                onPressed: () => onOpen(evidence),
                child: Text(
                  '${actionLabel(evidence)}: ${evidence.title}${evidence.fetchedAt == null ? '' : ' · ${evidence.fetchedAt!.toLocal().toString().split('.').first}'}',
                  style: AppTypography.caption(
                    context,
                  ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter =
      firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
  final darker =
      firstLuminance > secondLuminance ? secondLuminance : firstLuminance;

  return (lighter + 0.05) / (darker + 0.05);
}

class _AssistantActionCard extends StatelessWidget {
  const _AssistantActionCard({
    required this.action,
    required this.isBusy,
    required this.onPreview,
  });

  final AiAssistantActionModel action;
  final bool isBusy;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = action.isExecutableCandidate;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  available
                      ? Icons.task_alt_rounded
                      : Icons.lock_outline_rounded,
                  color:
                      available
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.label,
                        style: AppTypography.bodyMedium(
                          context,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (!available) ...[
                        const SizedBox(height: 6),
                        Text(
                          action.reasonIfDisabled ??
                              'Действие недоступно по текущим правам.',
                          style: AppTypography.bodySmall(
                            context,
                          ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (action.requiresConfirmation)
                  Chip(
                    label: const Text('Требует подтверждения'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                const Spacer(),
                if (available)
                  FilledButton.icon(
                    onPressed: isBusy ? null : onPreview,
                    icon:
                        isBusy
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.visibility_rounded),
                    label: const Text('Подготовить'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.lock_outline_rounded),
                    label: const Text('Недоступно'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPreviewPanel extends StatelessWidget {
  const _ActionPreviewPanel({
    required this.preview,
    required this.isExecuting,
    required this.onExecute,
    required this.onCancel,
  });

  final AiActionPreviewModel preview;
  final bool isExecuting;
  final VoidCallback onExecute;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.fact_check_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.title,
                      style: AppTypography.bodyLarge(
                        context,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (preview.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        preview.description,
                        style: AppTypography.bodySmall(
                          context,
                        ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (preview.summaryItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  preview.summaryItems
                      .map(
                        (item) => Chip(
                          label: Text('${item.label}: ${item.value}'),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
            ),
          ],
          if (preview.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...preview.warnings.map(
              (warning) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warning,
                        style: AppTypography.bodySmall(
                          context,
                        ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(
                onPressed: isExecuting ? null : onCancel,
                child: const Text('Отменить'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed:
                    preview.executable && !isExecuting ? onExecute : null,
                icon:
                    isExecuting
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.play_arrow_rounded),
                label: const Text('Выполнить'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionErrorPanel extends StatelessWidget {
  const _ActionErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyMedium(
                  context,
                ).copyWith(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportArtifactCard extends StatelessWidget {
  const _ReportArtifactCard({required this.artifact, required this.onOpen});

  final AiAssistantArtifact artifact;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url =
        artifact.downloadUrl ?? artifact.url ?? artifact.href ?? artifact.path;
    final rows = _artifactRows(artifact);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.description_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artifact.displayTitle,
                        style: AppTypography.bodyMedium(
                          context,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Chip(
                            label: Text(_reportTypeLabel(artifact.reportType)),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text(_artifactTypeLabel(artifact)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    rows
                        .map(
                          (row) => Chip(
                            label: Text('${row.label}: ${row.value}'),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: url == null ? null : onOpen,
                icon: const Icon(Icons.download_rounded),
                label: Text(url == null ? 'Файл недоступен' : 'Открыть отчет'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtifactRow {
  const _ArtifactRow(this.label, this.value);

  final String label;
  final String value;
}

List<_ArtifactRow> _artifactRows(AiAssistantArtifact artifact) {
  final rows = <_ArtifactRow>[];
  final dateFrom = _dateLabel(artifact.filters['date_from']);
  final dateTo = _dateLabel(artifact.filters['date_to']);

  if (dateFrom != null || dateTo != null) {
    rows.add(
      _ArtifactRow(
        'Период',
        [dateFrom, dateTo].whereType<String>().join(' - '),
      ),
    );
  }

  const labels = {
    'project_id': 'Проект',
    'warehouse_id': 'Склад',
    'contractor_id': 'Подрядчик',
    'user_id': 'Сотрудник',
  };

  labels.forEach((key, label) {
    final value = artifact.filters[key];
    if (value is String || value is num) {
      rows.add(_ArtifactRow(label, value.toString()));
    }
  });

  final expiresAt = _dateLabel(artifact.expiresAt);
  if (expiresAt != null) {
    rows.add(_ArtifactRow('Доступен до', expiresAt));
  }

  return rows;
}

String _reportTypeLabel(String? value) {
  return switch (value) {
    'project_profitability' => 'Рентабельность',
    'work_completion' => 'Выполнение работ',
    'material_movements' => 'Движение материалов',
    'contractor_settlements' => 'Расчеты с подрядчиками',
    'warehouse_stock' => 'Остатки склада',
    'time_tracking' => 'Трудозатраты',
    'contract_payments' => 'Платежи по договорам',
    'project_timelines' => 'График работ',
    _ => 'Готовый отчет',
  };
}

String _artifactTypeLabel(AiAssistantArtifact artifact) {
  final raw = (artifact.type ?? artifact.mimeType ?? '').toLowerCase();

  if (raw.contains('pdf')) {
    return 'PDF';
  }

  if (raw.contains('excel') ||
      raw.contains('spreadsheet') ||
      raw.contains('xls')) {
    return 'Excel';
  }

  return 'Файл';
}

String? _dateLabel(Object? value) {
  final raw = value?.toString();
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }

  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
  if (match != null) {
    return '${match.group(3)}.${match.group(2)}.${match.group(1)}';
  }

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    return null;
  }

  return '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
}

const _quickPrompts = [
  'Что в зоне риска по срокам',
  'Собери краткую управленческую сводку',
  'Какие вопросы требуют внимания сегодня',
  'Есть ли перекос по финансам',
];

class _PendingChat {
  const _PendingChat({
    required this.requestId,
    required this.message,
    required this.conversationId,
    required this.context,
    required this.profile,
    required this.quote,
  });
  final String requestId;
  final String message;
  final int? conversationId;
  final Map<String, dynamic> context;
  final String profile;
  final AiCreditQuoteModel quote;
}
