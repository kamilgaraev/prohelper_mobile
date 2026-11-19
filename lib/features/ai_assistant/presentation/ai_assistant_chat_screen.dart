import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:image_picker/image_picker.dart';
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
import '../data/ai_assistant_draft_turn_store.dart';
import '../data/ai_assistant_models.dart';
import '../data/ai_assistant_repository.dart';
import 'ai_assistant_memory_screen.dart';
import 'ai_assistant_sharing_screen.dart';
import 'ai_assistant_credits_screen.dart';
import 'ai_assistant_documents_screen.dart';

const _progressLabels = <String, List<String>>{
  'rag_search': [
    'Ищу информацию',
    'Информация собрана',
    'Поиск информации прерван',
  ],
  'estimates': [
    'Проверяю сметы',
    'Сметы проверены',
    'Не удалось проверить сметы',
  ],
  'estimate_position_search': [
    'Поиск позиций сметы',
    'Поиск позиций сметы завершён',
    'Не удалось завершить поиск позиций сметы',
  ],
  'estimate_position_read': [
    'Чтение позиции сметы',
    'Чтение позиции сметы завершено',
    'Не удалось прочитать позицию сметы',
  ],
  'warehouse': [
    'Проверяю склад',
    'Склад проверен',
    'Не удалось проверить склад',
  ],
  'projects': [
    'Проверяю проекты',
    'Проекты проверены',
    'Не удалось проверить проекты',
  ],
  'contracts': [
    'Проверяю договоры',
    'Договоры проверены',
    'Не удалось проверить договоры',
  ],
  'procurement': [
    'Проверяю закупки',
    'Закупки проверены',
    'Не удалось проверить закупки',
  ],
  'schedule': [
    'Проверяю график',
    'График проверен',
    'Не удалось проверить график',
  ],
  'work_volumes': [
    'Проверяю объёмы работ',
    'Объёмы работ проверены',
    'Не удалось проверить объёмы работ',
  ],
  'materials': [
    'Проверяю материалы',
    'Материалы проверены',
    'Не удалось проверить материалы',
  ],
  'reports': [
    'Проверяю отчёты',
    'Отчёты проверены',
    'Не удалось проверить отчёты',
  ],
  'financial_data': [
    'Проверяю финансовые данные',
    'Финансовые данные проверены',
    'Не удалось проверить финансовые данные',
  ],
  'record_check': [
    'Проверяю запись',
    'Запись проверена',
    'Не удалось проверить запись',
  ],
  'composing': ['Собираю ответ', 'Ответ собран', 'Не удалось собрать ответ'],
};

List<AiAssistantProgressModel> _mergeProgress(
  List<AiAssistantProgressModel> current,
  List<AiAssistantProgressModel> incoming,
) {
  final byId = <int, AiAssistantProgressModel>{
    for (final step in current) step.id: step,
  };
  for (final step in incoming) {
    byId[step.id] = step;
  }
  final result =
      byId.values.toList()..sort((left, right) => left.id.compareTo(right.id));
  return result
      .skip(result.length > 24 ? result.length - 24 : 0)
      .toList(growable: false);
}

String _progressLabel(AiAssistantProgressModel step) =>
    _progressLabels[step.code]?[switch (step.state) {
      'completed' => 1,
      'failed' => 2,
      _ => 0,
    }] ??
    'Запрос обрабатывается';

(String, String?) _progressIdentity(AiAssistantProgressModel step) => (
  step.code,
  step.key,
);

String _currentActivity(
  String? stage,
  List<AiAssistantProgressModel> progress,
) {
  if (const {
    'generating',
    'verifying',
    'cancel_requested',
    'recovering',
  }.contains(stage)) {
    return _stageLabels[stage]!;
  }
  final latestByStep = <(String, String?), AiAssistantProgressModel>{};
  for (final step in progress) {
    latestByStep[_progressIdentity(step)] = step;
  }
  final active =
      latestByStep.values.where((step) => step.state == 'started').toList()
        ..sort((left, right) => right.id.compareTo(left.id));
  if (active.isNotEmpty) {
    return _progressLabel(active.first);
  }
  return _stageLabels[stage] ?? 'Запрос обрабатывается';
}

List<AiAssistantProgressModel> _progressHistory(
  List<AiAssistantProgressModel> progress,
) {
  final byStep = <(String, String?), AiAssistantProgressModel>{};
  for (final step in progress) {
    if (step.state == 'completed' || step.state == 'failed') {
      byStep[_progressIdentity(step)] = step;
    }
  }
  final result =
      byStep.values.toList()
        ..sort((left, right) => left.id.compareTo(right.id));
  return result;
}

const _stageLabels = <String, String>{
  'queued': 'В очереди',
  'reading': 'Анализирую данные',
  'preparing': 'Проверяю доступ',
  'access': 'Проверяю доступ',
  'searching': 'Ищу доступные источники',
  'tools': 'Получаю данные',
  'generating': 'Формирую ответ',
  'verifying': 'Проверяю ответ',
  'validating': 'Проверяю ответ',
  'cancel_requested': 'Останавливаю обработку запроса',
  'cancelled': 'Запрос остановлен',
  'failed': 'Не удалось завершить запрос',
  'sending': 'Отправляю запрос',
  'recovering': 'Проверяю состояние запроса',
};

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
  int _conversationScopeRevision = 0;
  String? _progress;
  List<AiAssistantProgressModel> _progressSteps = const [];
  final Map<int, List<AiAssistantProgressModel>> _progressByMessageId = {};
  String? _activeRequestId;
  AiAssistantRepository? _activeRequestRepository;
  Timer? _progressTimer;
  Timer? _elapsedTimer;
  int? _elapsedSeconds;
  DateTime? _elapsedReferenceAt;
  int _elapsedReferenceSeconds = 0;
  bool _hasServerElapsed = false;
  AiAssistantInterimResult? _interimResult;
  int _interimRevision = 0;
  int? _pollingRevision;
  bool _cancelRequested = false;
  DateTime? _requestStartedAt;
  bool _isQuoting = false;
  String? _quotingRequestId;
  int? _nextHistoryPage;
  int? _historyRevision;
  String _profile = 'normal';
  bool _canWrite = true;
  bool _canManageParticipants = false;
  _PendingChat? _failedRequest;
  final ImagePicker _imagePicker = ImagePicker();
  List<_DraftImage> _draftImages = const [];
  bool _isUploadingImage = false;
  double? _imageUploadProgress;
  String? _imageError;
  int _draftRevision = 0;
  int _uploadRevision = 0;

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
      _quotingRequestId = null;
      _isQuoting = false;
      _draftRevision++;
      _uploadRevision++;
      _conversationId = widget.conversationId;
      _draftImages = const [];
      _isUploadingImage = false;
      _imageUploadProgress = null;
      _imageError = null;
      _messages = const [];
      _progressSteps = const [];
      _progressByMessageId.clear();
      _failedRequest = null;
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _detachSending(updateUi: false);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    if (_conversationId != null) {
      await _loadConversation(_conversationId!);
      return;
    }

    final revision = _requestRevision;
    final scope = _draftScope();
    final draftRequest =
        scope == null
            ? null
            : await ref.read(aiAssistantDraftTurnStoreProvider).read(scope);
    if (!mounted || revision != _requestRevision) return;
    setState(() {
      _isLoading = false;
    });
    if (draftRequest != null) {
      _observeRequest(draftRequest, recovering: true);
      return;
    }

    if ((widget.initialPrompt ?? '').trim().isNotEmpty) {
      await _sendMessage(widget.initialPrompt!.trim());
    }
  }

  AiAssistantDraftScope? _draftScope() {
    final user = ref.read(authProvider).user;
    final userId = user?.serverId;
    final organizationId = user?.currentOrganizationId;
    return userId == null || organizationId == null
        ? null
        : (userId: userId, organizationId: organizationId);
  }

  void _forgetDraftRequest(String requestId) {
    final scope = _draftScope();
    if (scope != null) {
      final store = ref.read(aiAssistantDraftTurnStoreProvider);
      unawaited(store.read(scope).then((_) => store.forget(scope, requestId)));
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
      });

      final historyRequest = await _loadHistory(id, requestRevision);
      if (!mounted || requestRevision != _requestRevision) return;
      setState(() => _isLoading = false);
      final activeRequest = historyRequest ?? details.activeRequest;
      if (!_isSending && activeRequest?.isActive == true) {
        _observeRequest(activeRequest!.requestId, snapshot: activeRequest);
      }
      _scrollToBottom();
    } catch (error) {
      if (!mounted || requestRevision != _requestRevision) return;
      setState(() {
        _error = UserMessage.fromError(error);
        _isLoading = false;
      });
    }
  }

  Future<AiAssistantChatRequest?> _loadHistory(
    int id,
    int revision, {
    int page = 1,
  }) async {
    if (_historyRevision == revision) return null;
    _historyRevision = revision;
    try {
      final result = await ref
          .read(aiAssistantRepositoryProvider)
          .fetchMessages(id, page: page);
      if (!mounted || revision != _requestRevision || id != _conversationId) {
        return null;
      }
      setState(() {
        final combined =
            page == 1 ? result.items : [...result.items, ..._messages];
        final ids = <int>{};
        _messages = combined.where((message) => ids.add(message.id)).toList();
        _nextHistoryPage = result.nextPage;
      });
      return result.activeRequest;
    } catch (error) {
      if (mounted && revision == _requestRevision) {
        _showSnackBar(_resolveError(error));
      }
      return null;
    } finally {
      if (_historyRevision == revision) _historyRevision = null;
    }
  }

  void _observeRequest(
    String requestId, {
    AiAssistantChatRequest? snapshot,
    bool recovering = false,
  }) {
    final revision = ++_requestRevision;
    final conversationId = _conversationId;
    if (requestId != _activeRequestId) _resetTurnProgress();
    _activeRequestId = requestId;
    _activeRequestRepository = ref.read(aiAssistantRepositoryProvider);
    _requestStartedAt = DateTime.now();
    _cancelRequested = snapshot?.isCancellationPending ?? _cancelRequested;
    setState(() {
      _isSending = true;
      _error = null;
      _progressSteps = snapshot?.progress ?? const [];
      _interimResult = null;
      if (snapshot != null) {
        _updateElapsedClock(snapshot);
        _updateInterimResult(snapshot);
      }
      _progress =
          _cancelRequested
              ? 'Останавливаю обработку'
              : _currentActivity(
                recovering
                    ? 'recovering'
                    : snapshot?.stage ?? snapshot?.runStatus,
                _progressSteps,
              );
    });
    _startPolling(requestId, revision, conversationId);
  }

  void _startPolling(String requestId, int revision, int? conversationId) {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollProgress(requestId, revision, conversationId),
    );
    unawaited(_pollProgress(requestId, revision, conversationId));
  }

  Future<void> _pollProgress(
    String requestId,
    int revision,
    int? conversationId,
  ) async {
    if (_pollingRevision == revision ||
        !mounted ||
        revision != _requestRevision ||
        requestId != _activeRequestId) {
      return;
    }
    if (_requestStartedAt != null &&
        DateTime.now().difference(_requestStartedAt!) >
            const Duration(minutes: 9)) {
      _progressTimer?.cancel();
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
      setState(() {
        _isSending = false;
        _progress = null;
        _interimResult = null;
        _error =
            'Ответ задерживается. Проверьте результат этого запроса позже.';
      });
      return;
    }
    _pollingRevision = revision;
    try {
      final repository =
          _activeRequestRepository ??
          ref.read<AiAssistantRepository>(aiAssistantRepositoryProvider);
      var progress = await repository.fetchChatRequest(
        requestId,
        conversationId: conversationId,
      );
      if (!mounted ||
          revision != _requestRevision ||
          requestId != _activeRequestId ||
          conversationId != _conversationId) {
        return;
      }
      if (progress.status == 'not_submitted' && !_cancelRequested) {
        final pending = _failedRequest;
        if (pending == null) {
          _failRequest('Запрос не отправлен. Введите вопрос снова.');
          return;
        }
        progress = await _resubmitRequest(repository, pending);
        if (!mounted ||
            revision != _requestRevision ||
            requestId != _activeRequestId) {
          return;
        }
      }
      _applyRequestSnapshot(progress, conversationId);
    } catch (error) {
      if (!mounted ||
          revision != _requestRevision ||
          requestId != _activeRequestId ||
          conversationId != _conversationId) {
        return;
      }
      if (error is ApiException &&
          error.message == 'Получен ответ для другого запроса.') {
        _failRequest(error.message);
        return;
      }
      if (error is ApiException &&
          const {401, 403, 404, 422}.contains(error.statusCode)) {
        _failRequest(_resolveError(error));
        return;
      }
      if (mounted && revision == _requestRevision && _isSending) {
        setState(() {
          _progress = 'Проверяю состояние запроса';
        });
      }
    } finally {
      if (_pollingRevision == revision) _pollingRevision = null;
    }
  }

  bool _applyRequestSnapshot(
    AiAssistantChatRequest request,
    int? conversationId,
  ) {
    final result = request.result;
    if (request.runStatus == 'completed') {
      if (result == null) return false;
      _completeRequest(result, conversationId, progress: request.progress);
      return true;
    }
    if (request.isTerminal) {
      _failRequest(
        request.runStatus == 'cancelled'
            ? 'Запрос остановлен.'
            : 'Ассистент не смог подготовить ответ. Попробуйте новый запрос.',
      );
      return true;
    }
    final steps = _mergeProgress(_progressSteps, request.progress);
    final previousInterim = _interimResult;
    setState(() {
      _progressSteps = steps;
      _cancelRequested = _cancelRequested || request.isCancellationPending;
      _updateElapsedClock(request);
      _updateInterimResult(request);
      _progress =
          _cancelRequested
              ? 'Останавливаю обработку'
              : _currentActivity(request.stage ?? request.runStatus, steps);
    });
    if (_interimResult != null &&
        _interimResult?.revision != previousInterim?.revision &&
        _scrollController.hasClients &&
        _scrollController.position.extentAfter < 80) {
      _scrollToBottom();
    }
    return false;
  }

  void _updateElapsedClock(AiAssistantChatRequest request) {
    if (!request.isActive) return;
    final now = DateTime.now();
    final acceptedAt = request.acceptedAt;
    final serverElapsed =
        request.elapsedSeconds ??
        (acceptedAt == null
            ? null
            : max(0, now.difference(acceptedAt).inSeconds));
    final current = _elapsedSeconds;
    if (current == null ||
        (serverElapsed != null &&
            (!_hasServerElapsed || serverElapsed > current))) {
      _elapsedSeconds = serverElapsed ?? 0;
      _elapsedReferenceSeconds = _elapsedSeconds!;
      _elapsedReferenceAt = now;
    }
    if (serverElapsed != null) _hasServerElapsed = true;
    _elapsedTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isSending) return;
      final wallSeconds =
          _elapsedReferenceSeconds +
          DateTime.now().difference(_elapsedReferenceAt!).inSeconds;
      setState(() => _elapsedSeconds = max(_elapsedSeconds! + 1, wallSeconds));
    });
  }

  void _updateInterimResult(AiAssistantChatRequest request) {
    final interim =
        request.isActive && !_cancelRequested ? request.interimResult : null;
    if (interim == null) {
      _interimResult = null;
      return;
    }
    if (interim.revision >= _interimRevision) {
      _interimResult = interim;
      _interimRevision = interim.revision;
    }
  }

  void _resetTurnProgress() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _elapsedSeconds = null;
    _elapsedReferenceAt = null;
    _elapsedReferenceSeconds = 0;
    _hasServerElapsed = false;
    _interimResult = null;
    _interimRevision = 0;
  }

  String get _elapsedLabel {
    final elapsed = _elapsedSeconds ?? 0;
    return '${(elapsed ~/ 60).toString().padLeft(2, '0')}:${(elapsed % 60).toString().padLeft(2, '0')}';
  }

  void _completeRequest(
    AiAssistantChatResult result,
    int? conversationAtSend, {
    List<AiAssistantProgressModel> progress = const [],
  }) {
    if (!mounted ||
        result.requestId != _activeRequestId ||
        conversationAtSend != _conversationId ||
        (conversationAtSend != null &&
            result.conversationId != conversationAtSend)) {
      return;
    }
    _progressTimer?.cancel();
    _resetTurnProgress();
    final reloadHistory = _failedRequest == null;
    final completedProgress = _mergeProgress(
      _mergeProgress(_progressSteps, progress),
      result.progress,
    );
    final progressHistory = _progressHistory(completedProgress);
    if (result.message != null && progressHistory.isNotEmpty) {
      _progressByMessageId[result.message!.id] = progressHistory;
    }
    _activeRequestId = null;
    _sendCancelToken = null;
    _activeRequestRepository = null;
    _cancelRequested = false;
    _forgetDraftRequest(result.requestId);
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
      _progressSteps = const [];
      _error = null;
    });
    final chargedMinor = result.publication?.chargedMinor;
    final charge =
        chargedMinor == null
            ? result.creditUsage?.actualCharge
            : formatAiMinor(chargedMinor);
    if (charge != null && (double.tryParse(charge) ?? 0) > 0) {
      _showSnackBar('Списано: $charge ед. МОСТ');
    } else if (result.creditUsage?.chargingEnabled == false) {
      _showSnackBar('Списания выключены. За этот запрос списано 0 ед. МОСТ.');
    }
    if (reloadHistory) {
      unawaited(
        _refreshAfterRecovery(
          result.conversationId,
          _conversationScopeRevision,
        ),
      );
    }
    _scrollToBottom();
  }

  Future<void> _refreshAfterRecovery(
    int conversationId,
    int scopeRevision,
  ) async {
    bool isCurrentScope() =>
        mounted &&
        scopeRevision == _conversationScopeRevision &&
        conversationId == _conversationId;

    try {
      final details = await ref
          .read(aiAssistantRepositoryProvider)
          .fetchConversation(conversationId);
      if (!isCurrentScope()) return;
      final ids = <int>{};
      final userRequests = <String>{};
      setState(() {
        _canWrite = details.conversation.canWrite;
        _canManageParticipants = details.conversation.canManageParticipants;
        _messages = [...details.messages, ..._messages]
            .where((message) {
              if (!ids.add(message.id)) return false;
              final requestId = message.metadata?['request_id'];
              return !message.isUser ||
                  requestId is! String ||
                  requestId.isEmpty ||
                  userRequests.add(requestId);
            })
            .toList(growable: false);
      });
      _scrollToBottom();
    } catch (error) {
      if (isCurrentScope()) {
        _showSnackBar(_resolveError(error));
      }
    }
  }

  void _failRequest(String message) {
    _cancelRequested = false;
    final pending = _failedRequest;
    final requestId = _activeRequestId;
    if (requestId != null) _forgetDraftRequest(requestId);
    _progressTimer?.cancel();
    _resetTurnProgress();
    _activeRequestId = null;
    _sendCancelToken = null;
    _activeRequestRepository = null;
    setState(() {
      _isSending = false;
      _progress = null;
      _progressSteps = const [];
      _error = message;
      if (pending != null) {
        _messages =
            _messages.where((item) => item.id != pending.optimisticId).toList();
        if (_controller.text.isEmpty) _controller.text = pending.message;
      }
      _failedRequest = null;
    });
  }

  void _detachSending({bool updateUi = true}) {
    _progressTimer?.cancel();
    _resetTurnProgress();
    _sendCancelToken?.cancel('Запрос отсоединён от текущего экрана.');
    _sendCancelToken = null;
    _activeRequestId = null;
    _activeRequestRepository = null;
    _cancelRequested = false;
    _requestRevision++;
    _conversationScopeRevision++;
    if (mounted && updateUi) {
      setState(() {
        _isSending = false;
        _progress = null;
        _progressSteps = const [];
      });
    } else {
      _isSending = false;
      _progress = null;
      _progressSteps = const [];
    }
  }

  void _recoverRequest() {
    if (_isSending) return;
    final activeRequestId = _activeRequestId;
    if (activeRequestId != null) {
      _observeRequest(activeRequestId, recovering: true);
    }
  }

  Future<void> _sendMessage([String? forcedValue]) async {
    final attachments = List<_DraftImage>.unmodifiable(_draftImages);
    final message =
        (forcedValue ?? _controller.text).trim().isEmpty &&
                attachments.isNotEmpty
            ? 'Проанализируй прикреплённое изображение.'
            : (forcedValue ?? _controller.text).trim();
    if (message.isEmpty ||
        _isLoading ||
        _isSending ||
        _isQuoting ||
        _isExecutingAction ||
        _activeRequestId != null ||
        _failedRequest != null ||
        !_canWrite) {
      return;
    }

    _cancelRequested = false;
    final requestId = _newRequestId();
    final requestRevision = ++_requestRevision;
    final attachmentRevision = _draftRevision;
    final attachmentIds = attachments.map((item) => item.metadata.id).toList();
    final conversationAtSend = _conversationId;
    final assistantContext = _assistantContext();
    final profile = _profile;
    setState(() => _isQuoting = true);
    _quotingRequestId = requestId;
    final quote = await _confirmQuote(
      message,
      requestId,
      conversationAtSend,
      assistantContext,
      profile,
      attachmentIds,
    );
    if (!mounted || requestId != _quotingRequestId) return;
    setState(() => _isQuoting = false);
    _quotingRequestId = null;
    if (quote == null ||
        requestRevision != _requestRevision ||
        conversationAtSend != _conversationId ||
        attachmentRevision != _draftRevision) {
      return;
    }
    _resetTurnProgress();
    final optimistic = AiMessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      role: 'user',
      content: message,
      createdAt: DateTime.now(),
      metadata: {'request_id': requestId},
      attachments: attachments.map((item) => item.metadata).toList(),
    );
    _failedRequest = _PendingChat(
      requestId: requestId,
      message: message,
      conversationId: conversationAtSend,
      context: assistantContext,
      profile: profile,
      quote: quote,
      attachmentIds: attachmentIds,
      optimisticId: optimistic.id,
    );

    setState(() {
      _messages = [..._messages, optimistic];
      _isSending = true;
      _progress = 'Отправляю запрос';
      _progressSteps = const [];
      _error = null;
      _actionError = null;
      _activePreview = null;
      _draftImages = const [];
      _draftRevision++;
      _imageError = null;
      if (forcedValue == null) {
        _controller.clear();
      }
    });

    _scrollToBottom();

    try {
      _activeRequestId = requestId;
      _activeRequestRepository = ref.read(aiAssistantRepositoryProvider);
      final scope = _draftScope();
      if (conversationAtSend == null && scope != null) {
        ref.read(aiAssistantDraftTurnStoreProvider).track(scope, requestId);
      }
      _requestStartedAt = DateTime.now();
      _sendCancelToken = CancelToken();
      final request = await _activeRequestRepository!.sendMessageRequest(
        message: message,
        requestId: requestId,
        quoteId: quote.id,
        profile: profile,
        conversationId: conversationAtSend,
        context: assistantContext,
        attachmentIds: attachmentIds,
        cancelToken: _sendCancelToken,
      );

      if (!mounted ||
          requestRevision != _requestRevision ||
          requestId != _activeRequestId ||
          conversationAtSend != _conversationId) {
        return;
      }
      if (!_applyRequestSnapshot(request, conversationAtSend)) {
        _startPolling(requestId, requestRevision, conversationAtSend);
      }
    } catch (error) {
      if (!mounted ||
          requestRevision != _requestRevision ||
          requestId != _activeRequestId) {
        return;
      }
      if (error is ApiException &&
          {400, 401, 403, 404, 409, 422, 429}.contains(error.statusCode)) {
        _failRequest(_resolveError(error));
        return;
      }
      setState(() {
        _progress = 'Проверяю состояние запроса';
      });
      _startPolling(requestId, requestRevision, conversationAtSend);
    }

    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    if (_isUploadingImage || _draftImages.length >= 2) return;
    final revision = _draftRevision;
    final uploadRevision = ++_uploadRevision;
    final conversationAtPick = _conversationId;
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );
      if (file == null || !_isCurrentImagePick(revision, conversationAtPick)) {
        return;
      }
      final fileLength = await file.length();
      if (!_isCurrentImagePick(revision, conversationAtPick)) return;
      if (fileLength > 5 * 1024 * 1024) {
        setState(
          () => _imageError = 'Размер изображения не должен превышать 5 МБ.',
        );
        return;
      }
      final bytes = await file.readAsBytes();
      if (!_isCurrentImagePick(revision, conversationAtPick)) return;
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      ui.ImageDescriptor? descriptor;
      int width;
      int height;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        if (!_isCurrentImagePick(revision, conversationAtPick)) return;
        width = descriptor.width;
        height = descriptor.height;
      } finally {
        descriptor?.dispose();
        buffer.dispose();
      }
      if (width > 2048 || height > 2048) {
        setState(
          () =>
              _imageError =
                  'Стороны изображения не должны превышать 2048 пикселей.',
        );
        return;
      }
      final name = file.name;
      final extension = name.split('.').last.toLowerCase();
      final mime = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'jpg' || 'jpeg' => 'image/jpeg',
        _ => file.mimeType ?? '',
      };
      if (!_isCurrentImagePick(revision, conversationAtPick)) return;
      if (!{'image/jpeg', 'image/png', 'image/webp'}.contains(mime)) {
        setState(
          () => _imageError = 'Поддерживаются изображения JPEG, PNG и WEBP.',
        );
        return;
      }
      setState(() {
        _isUploadingImage = true;
        _imageUploadProgress = 0;
        _imageError = null;
      });
      final metadata = await ref
          .read(aiAssistantRepositoryProvider)
          .uploadImage(
            fileName: name,
            mime: mime,
            bytes: bytes,
            conversationId: conversationAtPick,
            onSendProgress: (sent, total) {
              if (!mounted || revision != _draftRevision || total <= 0) return;
              setState(() => _imageUploadProgress = sent / total);
            },
          );
      if (!mounted ||
          revision != _draftRevision ||
          conversationAtPick != _conversationId) {
        return;
      }
      setState(() {
        _draftImages = [..._draftImages, _DraftImage(metadata, bytes)];
        _draftRevision++;
      });
    } catch (error) {
      if (mounted && revision == _draftRevision) {
        setState(() => _imageError = _resolveError(error));
      }
    } finally {
      if (mounted && uploadRevision == _uploadRevision) {
        setState(() {
          _isUploadingImage = false;
          _imageUploadProgress = null;
        });
      }
    }
  }

  bool _isCurrentImagePick(int revision, int? conversationId) =>
      mounted &&
      revision == _draftRevision &&
      conversationId == _conversationId;

  void _removeDraftImage(_DraftImage image) {
    setState(() {
      _draftImages = _draftImages.where((item) => item != image).toList();
      _draftRevision++;
      _imageError = null;
    });
  }

  Future<AiCreditQuoteModel?> _confirmQuote(
    String message,
    String requestId,
    int? conversationId,
    Map<String, dynamic> assistantContext,
    String profile,
    List<String> attachmentIds,
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
            attachmentIds: attachmentIds,
          );
      if (!mounted || requestId != _quotingRequestId) return null;
      if (double.tryParse(quote.amount) == 0) return quote;
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Оценка расхода'),
              content: Text(
                [
                  'Оценка до ${quote.amount} ${quote.unit}. Фактическое списание будет рассчитано после ответа.',
                  if (profile == 'detailed' &&
                      quote.processingDeadlineSeconds != null)
                    'Подробный анализ: ожидание до ${_formatProcessingDeadline(quote.processingDeadlineSeconds!)}.',
                ].join('\n'),
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
      return confirmed == true ? quote : null;
    } catch (error) {
      if (mounted) _showSnackBar(_resolveError(error));
      return null;
    }
  }

  String _formatProcessingDeadline(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes == 0) return '$seconds сек';
    if (remainingSeconds == 0) return '$minutes мин';
    return '$minutes мин $remainingSeconds сек';
  }

  Future<void> _stopSending() async {
    final requestId = _activeRequestId;
    final repository = _activeRequestRepository;
    if (requestId == null || repository == null || _cancelRequested) return;
    final revision = _requestRevision;
    setState(() {
      _cancelRequested = true;
      _progress = 'Останавливаю обработку';
      _interimResult = null;
    });
    try {
      final request = await repository.cancelRequest(requestId);
      if (!mounted ||
          revision != _requestRevision ||
          requestId != _activeRequestId) {
        return;
      }
      if (!_applyRequestSnapshot(request, _conversationId)) {
        _requestStartedAt = DateTime.now();
        _startPolling(requestId, revision, _conversationId);
      }
    } catch (error) {
      if (mounted && revision == _requestRevision) {
        setState(() => _cancelRequested = false);
        _showSnackBar(
          'Сервер не подтвердил остановку. ${_resolveError(error)}',
        );
      }
    }
  }

  Future<AiAssistantChatRequest> _resubmitRequest(
    AiAssistantRepository repository,
    _PendingChat pending,
  ) {
    if (pending.quote.expiresAt != null &&
        !pending.quote.expiresAt!.isAfter(DateTime.now())) {
      throw const ApiException(
        'Оценка истекла. Рассчитайте стоимость снова.',
        statusCode: 422,
      );
    }
    return repository.sendMessageRequest(
      message: pending.message,
      requestId: pending.requestId,
      conversationId: pending.conversationId,
      quoteId: pending.quote.id,
      profile: pending.profile,
      context: pending.context,
      attachmentIds: pending.attachmentIds,
      cancelToken: _sendCancelToken ??= CancelToken(),
    );
  }

  void _resetForOrganizationChange() {
    _detachSending(updateUi: false);
    _quotingRequestId = null;
    _isQuoting = false;
    _controller.clear();
    _uploadRevision++;
    _draftRevision++;
    if (!mounted) return;
    setState(() {
      _messages = const [];
      _progressSteps = const [];
      _progressByMessageId.clear();
      _draftImages = const [];
      _isUploadingImage = false;
      _imageUploadProgress = null;
      _imageError = null;
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
    if (_isSending || _isQuoting || _activeRequestId != null) return;
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
          if (_error != null && _activeRequestId != null)
            TextButton(
              onPressed: _isSending ? null : _recoverRequest,
              child: const Text('Проверить или возобновить запрос'),
            ),
          if (_activeRequestId != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _cancelRequested ? null : _stopSending,
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
                    : _messages.isEmpty && !_isSending
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
                          final history = _progressHistory(_progressSteps);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
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
                                          Semantics(
                                            liveRegion: true,
                                            child: Text(
                                              _progress ??
                                                  'Запрос обрабатывается',
                                              style: AppTypography.bodyMedium(
                                                context,
                                              ),
                                            ),
                                          ),
                                          if (_elapsedSeconds != null)
                                            Text(
                                              'Прошло $_elapsedLabel',
                                              style: AppTypography.caption(
                                                context,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (history.isNotEmpty)
                                  _AssistantProgressHistory(
                                    key: PageStorageKey(_activeRequestId),
                                    steps: history,
                                  ),
                                if (_interimResult case final result?)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: _AssistantInterimCard(
                                      result: result,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }

                        final message = _messages[index];
                        final isUser = message.isUser;
                        final publication = isUser ? null : message.publication;
                        final exportTask = publication?.exportTask;
                        final reportArtifacts =
                            isUser
                                ? const <AiAssistantArtifact>[]
                                : [
                                  ...message.artifacts.where(
                                    (artifact) => artifact.isReport,
                                  ),
                                  if (exportTask != null &&
                                      !message.artifacts.any(
                                        (artifact) => artifact.isReportTask,
                                      ))
                                    exportTask,
                                ];
                        final actions =
                            isUser
                                ? const <AiAssistantActionModel>[]
                                : message.actions
                                    .where(
                                      (action) =>
                                          publication == null ||
                                          action.type != 'navigate',
                                    )
                                    .toList(growable: false);
                        final sourceLinks =
                            isUser || publication != null
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
                                if (message.attachments.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: message.attachments
                                          .map(
                                            (attachment) =>
                                                _AuthenticatedAttachmentImage(
                                                  key: ValueKey(attachment.id),
                                                  attachment: attachment,
                                                ),
                                          )
                                          .toList(growable: false),
                                    ),
                                  ),
                                if (message.content.trim().isNotEmpty)
                                  Text(
                                    message.content,
                                    style: AppTypography.bodyMedium(
                                      context,
                                    ).copyWith(color: bubbleTextColor),
                                  ),
                                if (!isUser &&
                                    _progressByMessageId.containsKey(
                                      message.id,
                                    )) ...[
                                  const SizedBox(height: 10),
                                  _AssistantProgressHistory(
                                    key: PageStorageKey(message.id),
                                    steps: _progressByMessageId[message.id]!,
                                  ),
                                ],
                                if (sourceLinks.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: _MessageLinks(
                                      evidence: sourceLinks,
                                      onOpen: _openAssistantSource,
                                    ),
                                  ),
                                if (publication != null)
                                  _PublishedAssistantDetails(
                                    publication: publication,
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
                                            _isExecutingAction ||
                                            _isSending ||
                                            _isQuoting ||
                                            _activeRequestId != null,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_draftImages.isNotEmpty || _isUploadingImage)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ..._draftImages.map(
                              (image) => Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.memory(
                                      image.bytes,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    right: -6,
                                    top: -6,
                                    child: IconButton.filledTonal(
                                      visualDensity: VisualDensity.compact,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 28,
                                            height: 28,
                                          ),
                                      onPressed:
                                          _isSending
                                              ? null
                                              : () => _removeDraftImage(image),
                                      icon: const Icon(Icons.close, size: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_isUploadingImage)
                              SizedBox(
                                width: 64,
                                height: 64,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: _imageUploadProgress,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (_imageError != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _imageError!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Прикрепить изображение',
                          onPressed:
                              _isSending ||
                                      _isUploadingImage ||
                                      _draftImages.length >= 2
                                  ? null
                                  : _pickImage,
                          icon: const Icon(Icons.image_outlined),
                        ),
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
                              _isSending ||
                                      _isQuoting ||
                                      _isUploadingImage ||
                                      _activeRequestId != null
                                  ? null
                                  : () => _sendMessage(),
                          child: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'До 2 изображений · JPEG, PNG или WEBP · до 5 МБ каждое',
                        style: AppTypography.caption(
                          context,
                        ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
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

class _PublishedAssistantDetails extends StatelessWidget {
  const _PublishedAssistantDetails({required this.publication});

  final AiAssistantPublication publication;

  @override
  Widget build(BuildContext context) {
    final detail = switch (publication.outcome) {
      'no_match' => 'В проверенной области совпадений нет.',
      'ambiguous' => 'Найдено несколько совпадений.',
      'denied' => 'Доступ к данным ограничен.',
      'unavailable' => 'Данные сейчас недоступны.',
      'conflict' => 'Данные изменились. Уточните запрос.',
      _ => null,
    };
    final evidenceTitles =
        publication.evidence.map((item) => item.title).toSet();
    final unavailable =
        publication.uiActions.map((action) => action.label).toSet();
    if (detail == null &&
        publication.coverageStatus != 'partial' &&
        evidenceTitles.isEmpty &&
        unavailable.isEmpty) {
      return const SizedBox.shrink();
    }
    final style = AppTypography.caption(
      context,
    ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail != null) Text(detail, style: style),
          if (publication.coverageStatus == 'partial')
            Text('Проверена часть доступных данных.', style: style),
          if (evidenceTitles.isNotEmpty) ...[
            Text('Источники', style: style),
            for (final title in evidenceTitles) Text(title, style: style),
          ],
          if (unavailable.isNotEmpty) ...[
            for (final label in unavailable) Text(label, style: style),
            Text('Эти действия недоступны в приложении.', style: style),
          ],
        ],
      ),
    );
  }
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
        artifact.isReportTask
            ? null
            : artifact.downloadUrl ??
                artifact.url ??
                artifact.href ??
                artifact.path;
    final rows = _artifactRows(artifact);
    final taskLabel = switch (artifact.status) {
      'ready' => 'Отчёт готов и доступен в админке.',
      'failed' => 'Не удалось подготовить отчёт.',
      'cancelled' => 'Подготовка отчёта остановлена.',
      'expired' => 'Срок доступа к отчёту истёк.',
      _ => 'Отчёт готовится. Статус доступен в админке.',
    };

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
            if (artifact.isReportTask)
              Text(taskLabel, style: AppTypography.bodyMedium(context))
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: url == null ? null : onOpen,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    url == null ? 'Файл недоступен' : 'Открыть отчет',
                  ),
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
    _ => 'Отчёт',
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
    required this.attachmentIds,
    required this.optimisticId,
  });
  final String requestId;
  final String message;
  final int? conversationId;
  final Map<String, dynamic> context;
  final String profile;
  final AiCreditQuoteModel quote;
  final List<String> attachmentIds;
  final int optimisticId;
}

class _DraftImage {
  const _DraftImage(this.metadata, this.bytes);

  final AiImageAttachmentModel metadata;
  final Uint8List bytes;
}

class _AuthenticatedAttachmentImage extends ConsumerStatefulWidget {
  const _AuthenticatedAttachmentImage({super.key, required this.attachment});

  final AiImageAttachmentModel attachment;

  @override
  ConsumerState<_AuthenticatedAttachmentImage> createState() =>
      _AuthenticatedAttachmentImageState();
}

class _AuthenticatedAttachmentImageState
    extends ConsumerState<_AuthenticatedAttachmentImage> {
  late Future<Uint8List> _content;

  @override
  void initState() {
    super.initState();
    _content = _load();
  }

  @override
  void didUpdateWidget(covariant _AuthenticatedAttachmentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.id != widget.attachment.id) {
      _content = _load();
    }
  }

  Future<Uint8List> _load() => ref
      .read(aiAssistantRepositoryProvider)
      .fetchImageContent(widget.attachment.id);

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _content,
    builder: (context, snapshot) {
      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            snapshot.data!,
            width: 160,
            height: 130,
            fit: BoxFit.cover,
          ),
        );
      }
      return Container(
        width: 160,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child:
            snapshot.hasError
                ? const Icon(Icons.broken_image_outlined)
                : const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
      );
    },
  );
}

class _AssistantProgressHistory extends StatelessWidget {
  const _AssistantProgressHistory({super.key, required this.steps});

  final List<AiAssistantProgressModel> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: const Text('Ход работы'),
        children: [
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    step.state == 'failed'
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _progressLabel(step),
                      style: AppTypography.caption(
                        context,
                      ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AssistantInterimCard extends StatelessWidget {
  const _AssistantInterimCard({required this.result});

  final AiAssistantInterimResult result;

  @override
  Widget build(BuildContext context) {
    final caption = AppTypography.caption(
      context,
    ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Промежуточный результат',
            style: AppTypography.bodyMedium(
              context,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            result.isProjectScoped ? 'По проекту' : 'По организации',
            style: caption,
          ),
          const SizedBox(height: 8),
          Text(result.text, style: AppTypography.bodyMedium(context)),
          if (result.sources.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Источники', style: caption),
            for (final source in result.sources.toSet())
              Text(source, style: caption),
          ],
          const SizedBox(height: 8),
          Text('Работа продолжается.', style: caption),
        ],
      ),
    );
  }
}
