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
  String? _progressDetail;
  String? _activeRequestId;
  Timer? _progressTimer;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  DateTime? _requestCreatedAt;
  bool _isPolling = false;
  DateTime? _requestStartedAt;
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
      _detachSending();
      _conversationId = widget.conversationId;
      _messages = const [];
      _failedRequest = null;
      _loadingHistory = false;
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _elapsedTimer?.cancel();
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

  Future<void> _pollProgress(
    String requestId,
    int revision,
    int? conversationId,
  ) async {
    if (_isPolling || !mounted || revision != _requestRevision) return;
    if (_requestStartedAt != null &&
        DateTime.now().difference(_requestStartedAt!) >
            const Duration(minutes: 9)) {
      _progressTimer?.cancel();
      _elapsedTimer?.cancel();
      setState(() {
        _isSending = false;
        _progress = null;
        _progressDetail = null;
        _error =
            'Ответ задерживается. Проверьте результат этого запроса позже.';
      });
      return;
    }
    _isPolling = true;
    try {
      final progress = await ref
          .read(aiAssistantRepositoryProvider)
          .fetchChatRequest(requestId, conversationId: conversationId);
      if (!mounted ||
          revision != _requestRevision ||
          requestId != _activeRequestId ||
          conversationId != _conversationId) {
        return;
      }
      if (progress.status == 'completed') {
        _completeRequest(progress.result!, conversationId);
        return;
      }
      if (progress.status == 'failed' || progress.status == 'cancelled') {
        _failRequest(
          progress.status == 'cancelled'
              ? 'Запрос остановлен.'
              : 'Ассистент не смог подготовить ответ. Попробуйте новый запрос.',
          terminal: true,
        );
        return;
      }
      final (title, detail) = _stageDescription(progress.stage);
      setState(() {
        _progress = title;
        _progressDetail = detail;
      });
    } catch (error) {
      if (!mounted ||
          revision != _requestRevision ||
          requestId != _activeRequestId ||
          conversationId != _conversationId) {
        return;
      }
      if (error is ApiException &&
          error.message == 'Получен ответ для другого запроса.') {
        _failRequest(error.message, terminal: true);
        return;
      }
      if (mounted && revision == _requestRevision && _isSending) {
        setState(() {
          _progress = 'Проверяю состояние запроса';
          _progressDetail =
              'Жду связь с сервером, запрос может продолжать обрабатываться.';
        });
      }
    } finally {
      _isPolling = false;
    }
  }

  (String, String) _stageDescription(String? stage) => switch (stage) {
    'queued' => ('Запрос в очереди', 'Ожидаю начала обработки.'),
    'preparing' || 'access' => (
      'Проверяю доступ',
      'Уточняю, какие данные доступны для запроса.',
    ),
    'searching' => (
      'Ищу доступные источники',
      'Подбираю сведения, относящиеся к вопросу.',
    ),
    'tools' => (
      'Получаю данные',
      'Загружаю сведения из доступных разделов МОСТ.',
    ),
    'generating' => (
      'Готовлю ответ',
      'Составляю ответ на основе полученных данных.',
    ),
    'validating' => (
      'Сверяю ответ',
      'Проверяю подготовленный ответ перед показом.',
    ),
    _ => ('Запрос обрабатывается', 'Жду следующего состояния от сервера.'),
  };

  void _startElapsedTimer({bool reset = false}) {
    _elapsedTimer?.cancel();
    if (reset || _requestCreatedAt == null) {
      _requestCreatedAt = DateTime.now();
      _elapsedSeconds = 0;
    }
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isSending) return;
      final wallSeconds =
          DateTime.now().difference(_requestCreatedAt!).inSeconds;
      setState(() => _elapsedSeconds = max(_elapsedSeconds + 1, wallSeconds));
    });
  }

  String get _elapsedLabel =>
      '${(_elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:${(_elapsedSeconds % 60).toString().padLeft(2, '0')}';

  void _completeRequest(AiAssistantChatResult result, int? conversationAtSend) {
    if (!mounted ||
        result.requestId != _activeRequestId ||
        conversationAtSend != _conversationId ||
        (conversationAtSend != null &&
            result.conversationId != conversationAtSend)) {
      return;
    }
    _progressTimer?.cancel();
    _elapsedTimer?.cancel();
    _activeRequestId = null;
    _sendCancelToken = null;
    setState(() {
      _conversationId = result.conversationId;
      if (conversationAtSend == null) _canManageParticipants = true;
      _failedRequest = null;
      if (result.message != null &&
          !_messages.any((item) => item.id == result.message!.id)) {
        _messages = [..._messages, result.message!];
      }
      _isSending = false;
      _progress = null;
      _progressDetail = null;
      _error = null;
    });
    if (result.creditUsage?.chargingEnabled == false) {
      _showSnackBar(
        'Тестовый режим: списания выключены. Фактическое списание — 0 ед. МОСТ.',
      );
    } else if (result.creditUsage?.actualCharge != null &&
        (double.tryParse(result.creditUsage!.actualCharge!) ?? 0) > 0) {
      _showSnackBar('Списано: ${result.creditUsage!.actualCharge} ед. МОСТ');
    }
    _scrollToBottom();
  }

  void _failRequest(String message, {bool terminal = false}) {
    final pending = _failedRequest;
    _progressTimer?.cancel();
    _elapsedTimer?.cancel();
    _activeRequestId = null;
    _sendCancelToken = null;
    setState(() {
      _isSending = false;
      _progress = null;
      _progressDetail = null;
      _error = message;
      if (terminal) {
        if (pending != null) {
          _messages =
              _messages
                  .where((item) => item.id != pending.optimisticId)
                  .toList();
          if (_controller.text.isEmpty) _controller.text = pending.message;
        }
        _failedRequest = null;
      }
    });
  }

  void _detachSending() {
    _progressTimer?.cancel();
    _elapsedTimer?.cancel();
    _sendCancelToken = null;
    _activeRequestId = null;
    _requestRevision++;
    _isSending = false;
    _progress = null;
    _progressDetail = null;
  }

  Future<void> _recoverRequest() async {
    final failed = _failedRequest;
    if (failed == null ||
        _isSending ||
        failed.conversationId != _conversationId) {
      return;
    }
    final revision = ++_requestRevision;
    _activeRequestId = failed.requestId;
    _requestStartedAt = DateTime.now();
    setState(() {
      _isSending = true;
      _error = null;
      _progress = 'Проверяю состояние запроса';
      _progressDetail = 'Ищу результат сохранённого запроса.';
    });
    _startElapsedTimer();
    try {
      AiAssistantChatRequest request;
      try {
        request = await ref
            .read(aiAssistantRepositoryProvider)
            .fetchChatRequest(
              failed.requestId,
              conversationId: failed.conversationId,
            );
      } on ApiException catch (error) {
        if (error.statusCode != 404) rethrow;
        request = await ref
            .read(aiAssistantRepositoryProvider)
            .sendMessageRequest(
              message: failed.message,
              requestId: failed.requestId,
              conversationId: failed.conversationId,
              quoteId: failed.quote.id,
              maxConfirmed: failed.quote.maxConfirmed,
              profile: failed.profile,
              context: failed.context,
            );
      }
      if (!mounted ||
          revision != _requestRevision ||
          !_isSending ||
          failed.conversationId != _conversationId) {
        return;
      }
      if (request.status == 'completed') {
        _completeRequest(request.result!, failed.conversationId);
        return;
      }
      if (request.status == 'failed' || request.status == 'cancelled') {
        _failRequest(
          request.status == 'cancelled'
              ? 'Запрос остановлен.'
              : 'Ассистент не смог подготовить ответ. Попробуйте новый запрос.',
          terminal: true,
        );
        return;
      }
      _progressTimer?.cancel();
      _progressTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _pollProgress(failed.requestId, revision, failed.conversationId),
      );
      await _pollProgress(failed.requestId, revision, failed.conversationId);
    } catch (error) {
      if (mounted && revision == _requestRevision) {
        _failRequest(_resolveError(error));
      }
    }
  }

  Future<void> _sendMessage([String? forcedValue, bool retry = false]) async {
    if (retry) {
      await _recoverRequest();
      return;
    }
    final message = (forcedValue ?? _controller.text).trim();
    if (message.isEmpty ||
        _isLoading ||
        _isSending ||
        _isQuoting ||
        _failedRequest != null ||
        !_canWrite) {
      return;
    }

    final requestId = _newRequestId();
    final requestRevision = ++_requestRevision;
    final conversationAtSend = _conversationId;
    final assistantContext = _assistantContext();
    final profile = _profile;
    _isQuoting = true;
    _quotingRequestId = requestId;
    final quote = await _confirmQuote(
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
    final optimistic = AiMessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      role: 'user',
      content: message,
      createdAt: DateTime.now(),
    );
    _failedRequest = _PendingChat(
      requestId: requestId,
      message: message,
      conversationId: conversationAtSend,
      context: assistantContext,
      profile: profile,
      quote: quote,
      optimisticId: optimistic.id,
    );

    setState(() {
      _messages = [..._messages, optimistic];
      _isSending = true;
      _progress = 'Отправляю запрос';
      _progressDetail = 'Передаю вопрос ассистенту.';
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
      _requestStartedAt = DateTime.now();
      _startElapsedTimer(reset: true);
      _sendCancelToken = CancelToken();
      final request = await ref
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
      if (request.status == 'completed') {
        _completeRequest(request.result!, conversationAtSend);
      } else {
        _progressTimer = Timer.periodic(
          const Duration(seconds: 2),
          (_) => _pollProgress(requestId, requestRevision, conversationAtSend),
        );
        await _pollProgress(requestId, requestRevision, conversationAtSend);
      }
    } catch (error) {
      if (!mounted || requestRevision != _requestRevision) return;
      if (error is ApiException &&
          {400, 401, 403, 404, 409, 422, 429}.contains(error.statusCode)) {
        _failRequest(_resolveError(error), terminal: true);
        return;
      }
      _progressTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _pollProgress(requestId, requestRevision, conversationAtSend),
      );
      setState(() {
        _progress = 'Проверяю состояние запроса';
        _progressDetail =
            'Связь прервалась. Ответ может продолжать готовиться.';
      });
      await _pollProgress(requestId, requestRevision, conversationAtSend);
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
      if (double.tryParse(quote.amount) == 0) return quote;
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
    _elapsedTimer?.cancel();
    _activeRequestId = null;
    final stopRevision = ++_requestRevision;
    if (mounted) {
      setState(() {
        _isSending = false;
        _progress = null;
        _progressDetail = null;
      });
    }
    if (requestId != null) {
      try {
        await ref.read(aiAssistantRepositoryProvider).cancelRequest(requestId);
        if (stopRevision == _requestRevision) _failedRequest = null;
      } catch (error) {
        if (mounted && stopRevision == _requestRevision) {
          _showSnackBar(
            'Сервер не подтвердил остановку. ${_resolveError(error)}',
          );
        }
      } finally {
        token?.cancel('Пользователь остановил запрос.');
      }
    }
  }

  void _resetForOrganizationChange() {
    _progressTimer?.cancel();
    _elapsedTimer?.cancel();
    _activeRequestId = null;
    _sendCancelToken = null;
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
      _progressDetail = null;
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
    final projectId =
        evidence.projectId ??
        (evidence.entityType == 'project' ? evidence.entityId : null);
    return resolveAssistantSourceTarget(
      evidence.url,
      sourceBaseUrl: _sourceBaseUrl,
      projectId: projectId,
    );
  }

  bool _canOpenSource(AiAssistantEvidenceModel evidence) {
    final target = _sourceTarget(evidence);
    if (target == null) return false;
    if (target.webPath != null || target.projectId != null) return true;
    return target.mobileRoute != null &&
        visibleMobileDestinations(
          ref.read(supportedMobileModulesProvider),
        ).any((item) => item.matches(target.mobileRoute!));
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
      final destination =
          matchingDestinations.isEmpty ? null : matchingDestinations.first;
      final selectedProject = ref.read(projectsProvider).selectedProject;
      final projectContextMatches =
          target.projectId == null ||
          selectedProject?.serverId.toString() == target.projectId;
      if (destination != null &&
          (!destination.requiresProject || projectContextMatches)) {
        await Navigator.of(
          context,
        ).push<void>(MaterialPageRoute<void>(builder: destination.builder));
        return;
      }
    }

    final webPath =
        target?.webPath ??
        (target?.projectId == null
            ? null
            : '/dashboard/projects/${Uri.encodeComponent(target!.projectId!)}');
    if (webPath != null) {
      final uri = ref.read(aiAssistantRepositoryProvider).sourceUri(webPath);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (mounted) _showSnackBar('Переход к записи сейчас недоступен.');
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
              child: const Text('Проверить или возобновить запрос'),
            ),
          if (_isSending)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _stopSending,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Стоп'),
              ),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _progress ?? 'Запрос обрабатывается',
                                        style: AppTypography.bodyMedium(
                                          context,
                                        ),
                                      ),
                                      if (_progressDetail != null)
                                        Text(
                                          _progressDetail!,
                                          style: AppTypography.caption(context),
                                        ),
                                      Text(
                                        'Прошло $_elapsedLabel',
                                        style: AppTypography.caption(context),
                                      ),
                                    ],
                                  ),
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
                        final sourceLinks =
                            isUser
                                ? const <AiAssistantEvidenceModel>[]
                                : message.evidence
                                    .where(_canOpenSource)
                                    .toList();
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
                                if (sourceLinks.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: _MessageLinks(
                                      evidence: sourceLinks,
                                      onOpen: _openAssistantSource,
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

class _MessageLinks extends StatelessWidget {
  const _MessageLinks({required this.evidence, required this.onOpen});

  final List<AiAssistantEvidenceModel> evidence;
  final Future<void> Function(AiAssistantEvidenceModel) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children:
          evidence
              .map(
                (item) => TextButton.icon(
                  onPressed: () => onOpen(item),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(
                    item.title,
                    style: AppTypography.caption(
                      context,
                    ).copyWith(color: theme.colorScheme.primary),
                  ),
                ),
              )
              .toList(),
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
    required this.optimisticId,
  });
  final String requestId;
  final String message;
  final int? conversationId;
  final Map<String, dynamic> context;
  final String profile;
  final AiCreditQuoteModel quote;
  final int optimisticId;
}
