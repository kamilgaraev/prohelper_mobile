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
import '../data/ai_assistant_models.dart';
import '../data/ai_assistant_repository.dart';
import 'ai_assistant_memory_screen.dart';
import 'ai_assistant_sharing_screen.dart';
import 'ai_assistant_credits_screen.dart';
import 'ai_assistant_documents_screen.dart';

const _progressLabels = <String, List<String>>{
  'rag_search': ['Ищу информацию', 'Информация собрана'],
  'estimates': ['Проверяю сметы', 'Сметы проверены'],
  'warehouse': ['Проверяю склад', 'Склад проверен'],
  'projects': ['Проверяю проекты', 'Проекты проверены'],
  'contracts': ['Проверяю договоры', 'Договоры проверены'],
  'procurement': ['Проверяю закупки', 'Закупки проверены'],
  'schedule': ['Проверяю график', 'График проверен'],
  'work_volumes': ['Проверяю объёмы работ', 'Объёмы работ проверены'],
  'materials': ['Проверяю материалы', 'Материалы проверены'],
  'reports': ['Проверяю отчёты', 'Отчёты проверены'],
  'financial_data': [
    'Проверяю финансовые данные',
    'Финансовые данные проверены',
  ],
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
    _progressLabels[step.code]?[step.state == 'completed' ? 1 : 0] ??
    'Запрос обрабатывается';

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
  final latestByCode = <String, AiAssistantProgressModel>{};
  for (final step in progress) {
    latestByCode[step.code] = step;
  }
  final active =
      latestByCode.values.where((step) => step.state == 'started').toList()
        ..sort((left, right) => right.id.compareTo(left.id));
  if (active.isNotEmpty) {
    return _progressLabels[active.first.code]?[0] ?? 'Запрос обрабатывается';
  }
  return _stageLabels[stage] ?? 'Запрос обрабатывается';
}

List<AiAssistantProgressModel> _completedSources(
  List<AiAssistantProgressModel> progress,
) {
  final byCode = <String, AiAssistantProgressModel>{};
  for (final step in progress) {
    if (step.state == 'completed') byCode[step.code] = step;
  }
  final result =
      byCode.values.toList()
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
  String? _progress;
  List<AiAssistantProgressModel> _progressSteps = const [];
  final Map<int, List<AiAssistantProgressModel>> _completedProgressByMessageId =
      {};
  String? _activeRequestId;
  AiAssistantRepository? _activeRequestRepository;
  int? _activeRequestOrganizationId;
  Timer? _progressTimer;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  DateTime? _requestCreatedAt;
  bool _isPolling = false;
  bool _cancelRequested = false;
  DateTime? _requestStartedAt;
  bool _isQuoting = false;
  String? _quotingRequestId;
  int? _nextHistoryPage;
  bool _loadingHistory = false;
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
        if (previous != next) _resetForOrganizationChange(previous?.$2);
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
      _draftRevision++;
      _uploadRevision++;
      _conversationId = widget.conversationId;
      _draftImages = const [];
      _isUploadingImage = false;
      _imageUploadProgress = null;
      _imageError = null;
      _messages = const [];
      _progressSteps = const [];
      _completedProgressByMessageId.clear();
      _failedRequest = null;
      _loadingHistory = false;
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _detachSending(cancelServer: true, updateUi: false);
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
        _error =
            'Ответ задерживается. Проверьте результат этого запроса позже.';
      });
      return;
    }
    _isPolling = true;
    try {
      final repository =
          _activeRequestRepository ?? ref.read(aiAssistantRepositoryProvider)!;
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
        if (pending == null) return;
        progress = await _resubmitRequest(repository, pending);
        if (!mounted ||
            revision != _requestRevision ||
            requestId != _activeRequestId) {
          return;
        }
      }
      if (progress.status == 'completed') {
        _completeRequest(
          progress.result!,
          conversationId,
          progress: progress.progress,
        );
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
      final mergedProgress = _mergeProgress(_progressSteps, progress.progress);
      setState(() {
        _progressSteps = mergedProgress;
        _progress =
            progress.status == 'cancel_requested' || _cancelRequested
                ? 'Останавливаю обработку'
                : _currentActivity(progress.stage, mergedProgress);
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
      if (error is ApiException &&
          const {401, 403, 404, 422}.contains(error.statusCode)) {
        _failRequest(_resolveError(error), terminal: true);
        return;
      }
      if (mounted && revision == _requestRevision && _isSending) {
        setState(() {
          _progress = 'Проверяю состояние запроса';
        });
      }
    } finally {
      _isPolling = false;
    }
  }

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

  List<AiAssistantProgressModel> get _visibleCompletedProgress =>
      _completedSources(_progressSteps);

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
    _elapsedTimer?.cancel();
    final completedProgress = _mergeProgress(
      _mergeProgress(_progressSteps, progress),
      result.progress,
    );
    final completedSources = _completedSources(completedProgress);
    if (result.message != null && completedSources.isNotEmpty) {
      _completedProgressByMessageId[result.message!.id] = completedSources;
    }
    _activeRequestId = null;
    _sendCancelToken = null;
    _activeRequestRepository = null;
    _activeRequestOrganizationId = null;
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
    _cancelRequested = false;
    final pending = _failedRequest;
    _progressTimer?.cancel();
    _elapsedTimer?.cancel();
    _activeRequestId = null;
    _sendCancelToken = null;
    _activeRequestRepository = null;
    _activeRequestOrganizationId = null;
    setState(() {
      _isSending = false;
      _progress = null;
      _progressSteps = const [];
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

  void _detachSending({
    bool cancelServer = false,
    bool updateUi = true,
    bool requireOrganizationMatch = false,
    int? expectedOrganizationId,
  }) {
    final requestId = _activeRequestId;
    final token = _sendCancelToken;
    final repository = _activeRequestRepository;
    final organizationId = _activeRequestOrganizationId;
    if (cancelServer &&
        requestId != null &&
        repository != null &&
        (!requireOrganizationMatch ||
            organizationId == expectedOrganizationId)) {
      unawaited(
        repository
            .cancelRequest(requestId)
            .then<void>((_) {}, onError: (Object _) {}),
      );
    }
    _progressTimer?.cancel();
    _elapsedTimer?.cancel();
    token?.cancel('Запрос отсоединён от текущего экрана.');
    _sendCancelToken = null;
    _activeRequestId = null;
    _activeRequestRepository = null;
    _activeRequestOrganizationId = null;
    _requestRevision++;
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

  Future<void> _recoverRequest() async {
    final failed = _failedRequest;
    if (failed == null ||
        _isSending ||
        failed.conversationId != _conversationId) {
      return;
    }
    final revision = ++_requestRevision;
    _activeRequestId = failed.requestId;
    _activeRequestRepository = ref.read(aiAssistantRepositoryProvider);
    _activeRequestOrganizationId =
        ref.read(authProvider).user?.currentOrganizationId;
    final repository = _activeRequestRepository!;
    _requestStartedAt = DateTime.now();
    setState(() {
      _isSending = true;
      _error = null;
      _progress = 'Проверяю состояние запроса';
    });
    _startElapsedTimer();
    try {
      AiAssistantChatRequest request;
      try {
        request = await repository.fetchChatRequest(
          failed.requestId,
          conversationId: failed.conversationId,
        );
      } on ApiException catch (error) {
        if (error.statusCode != 404) rethrow;
        request = await _resubmitRequest(repository, failed);
      }
      if (!mounted ||
          revision != _requestRevision ||
          !_isSending ||
          failed.conversationId != _conversationId) {
        return;
      }
      if (request.status == 'not_submitted' && !_cancelRequested) {
        request = await _resubmitRequest(repository, failed);
        if (!mounted || revision != _requestRevision || !_isSending) return;
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
        _failRequest(
          _resolveError(error),
          terminal:
              error is ApiException && {404, 422}.contains(error.statusCode),
        );
      }
    }
  }

  Future<void> _sendMessage([String? forcedValue, bool retry = false]) async {
    if (retry) {
      await _recoverRequest();
      return;
    }
    _cancelRequested = false;
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
        _failedRequest != null ||
        !_canWrite) {
      return;
    }

    final requestId = _newRequestId();
    final requestRevision = ++_requestRevision;
    final attachmentRevision = _draftRevision;
    final attachmentIds = attachments.map((item) => item.metadata.id).toList();
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
      attachmentIds,
    );
    _isQuoting = false;
    if (quote == null ||
        !mounted ||
        requestRevision != _requestRevision ||
        conversationAtSend != _conversationId ||
        attachmentRevision != _draftRevision) {
      return;
    }
    final optimistic = AiMessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      role: 'user',
      content: message,
      createdAt: DateTime.now(),
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
      _activeRequestOrganizationId =
          ref.read(authProvider).user?.currentOrganizationId;
      _requestStartedAt = DateTime.now();
      _startElapsedTimer(reset: true);
      _sendCancelToken = CancelToken();
      final request = await _activeRequestRepository!.sendMessageRequest(
        message: message,
        requestId: requestId,
        quoteId: quote.id,
        maxConfirmed: quote.maxConfirmed,
        profile: profile,
        conversationId: conversationAtSend,
        context: assistantContext,
        attachmentIds: attachmentIds,
        cancelToken: _sendCancelToken,
      );

      if (!mounted ||
          requestRevision != _requestRevision ||
          conversationAtSend != _conversationId) {
        return;
      }
      final mergedProgress = _mergeProgress(_progressSteps, request.progress);
      setState(() {
        _progressSteps = mergedProgress;
        _progress = _currentActivity(request.stage, mergedProgress);
      });
      if (request.status == 'completed') {
        _completeRequest(
          request.result!,
          conversationAtSend,
          progress: request.progress,
        );
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
      });
      await _pollProgress(requestId, requestRevision, conversationAtSend);
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
      return confirmed == true
          ? AiCreditQuoteModel(
            id: quote.id,
            maxConfirmed: true,
            amount: quote.amount,
            unit: quote.unit,
            processingDeadlineSeconds: quote.processingDeadlineSeconds,
            expiresAt: quote.expiresAt,
          )
          : null;
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
    });
    try {
      final request = await repository.cancelRequest(requestId);
      if (!mounted ||
          revision != _requestRevision ||
          requestId != _activeRequestId) {
        return;
      }
      if (request.status == 'cancelled' || request.status == 'failed') {
        _failRequest('Запрос остановлен.', terminal: true);
      } else if (request.status == 'completed' && request.result != null) {
        _completeRequest(request.result!, _conversationId);
      } else {
        _progressTimer ??= Timer.periodic(
          const Duration(seconds: 2),
          (_) => _pollProgress(requestId, revision, _conversationId),
        );
        await _pollProgress(requestId, revision, _conversationId);
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
      maxConfirmed: pending.quote.maxConfirmed,
      profile: pending.profile,
      context: pending.context,
      attachmentIds: pending.attachmentIds,
    );
  }

  void _resetForOrganizationChange(int? previousOrganizationId) {
    _detachSending(
      cancelServer: true,
      updateUi: false,
      requireOrganizationMatch: true,
      expectedOrganizationId: previousOrganizationId,
    );
    _quotingRequestId = null;
    _uploadRevision++;
    _draftRevision++;
    _loadingHistory = false;
    if (!mounted) return;
    setState(() {
      _messages = const [];
      _progressSteps = const [];
      _completedProgressByMessageId.clear();
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
                                      Text(
                                        'Прошло $_elapsedLabel',
                                        style: AppTypography.caption(context),
                                      ),
                                      if (_visibleCompletedProgress
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        _CompletedAssistantSources(
                                          steps: _visibleCompletedProgress,
                                        ),
                                      ],
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
                                    _completedProgressByMessageId.containsKey(
                                      message.id,
                                    )) ...[
                                  const SizedBox(height: 10),
                                  _CompletedAssistantSources(
                                    steps: _completedSources(
                                      _completedProgressByMessageId[message
                                          .id]!,
                                    ),
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
                              _isSending || _isQuoting || _isUploadingImage
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

class _CompletedAssistantSources extends StatelessWidget {
  const _CompletedAssistantSources({required this.steps});

  final List<AiAssistantProgressModel> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps
          .map((step) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
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
            );
          })
          .toList(growable: false),
    );
  }
}
