import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/storage/encrypted_local_file_cache.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/legal_document_model.dart';
import '../data/legal_document_original_picker.dart';
import '../data/legal_document_repository.dart';
import '../domain/legal_document_provider.dart';
import '../domain/legal_document_state.dart';
import '../../../core/sync/sync_queue_service.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../../core/sync/queued_sync_operation.dart';
import 'widgets/legal_document_detail.dart';
import 'widgets/legal_document_list.dart';

class ContractManagementScreen extends ConsumerStatefulWidget {
  const ContractManagementScreen({super.key});

  @override
  ConsumerState<ContractManagementScreen> createState() =>
      _ContractManagementScreenState();
}

class _ContractManagementScreenState
    extends ConsumerState<ContractManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncAndLoad());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(legalDocumentProvider);
    final projectId = ref.watch(projectsProvider).selectedProject?.serverId;
    if (state.projectId != projectId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncAndLoad());
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Юридические документы'),
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Обновить',
              onPressed:
                  projectId == null
                      ? null
                      : () => ref.read(legalDocumentProvider.notifier).load(),
            ),
          ],
        ),
        body: _body(state, projectId),
      ),
    );
  }

  Widget _body(LegalDocumentState state, int? projectId) {
    if (projectId == null) {
      return const AppEmptyState(
        icon: Icons.domain_disabled_outlined,
        title: 'Выберите объект',
        description: 'Документы открываются по выбранному объекту.',
      );
    }
    if (state.isLoading && state.documents.isEmpty) {
      return const AppLoadingState(message: 'Загружаем документы');
    }
    if (state.error != null && state.documents.isEmpty) {
      return AppErrorState(
        title: 'Не удалось загрузить документы',
        description: state.error!,
        onRetry: () => ref.read(legalDocumentProvider.notifier).load(),
      );
    }
    if (state.documents.isEmpty) {
      return const AppEmptyState(
        icon: Icons.folder_open_outlined,
        title: 'Документов пока нет',
        description: 'Для выбранного объекта юридические документы не найдены.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(legalDocumentProvider.notifier).load(),
      child: Column(
        children: [
          if (state.isPartial)
            MaterialBanner(
              content: Text(
                state.isFromCache
                    ? 'Показаны сохранённые и полученные данные. Синхронизация не завершена.'
                    : 'Показана часть списка. Синхронизация не завершена.',
              ),
              actions: [
                TextButton(
                  onPressed: state.isLoading
                      ? null
                      : () => ref.read(legalDocumentProvider.notifier).load(),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          Expanded(child: LegalDocumentList(documents: state.documents, onOpen: _open)),
        ],
      ),
    );
  }

  void _syncAndLoad() {
    final notifier = ref.read(legalDocumentProvider.notifier);
    notifier.syncProject(ref.read(projectsProvider).selectedProject?.serverId);
    notifier.load();
  }

  void _open(LegalDocumentModel document) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LegalDocumentDetailScreen(id: document.id),
      ),
    );
  }
}

class _LegalDocumentDetailScreen extends ConsumerStatefulWidget {
  const _LegalDocumentDetailScreen({required this.id});

  final int id;

  @override
  ConsumerState<_LegalDocumentDetailScreen> createState() =>
      _LegalDocumentDetailScreenState();
}

class _LegalDocumentDetailScreenState
    extends ConsumerState<_LegalDocumentDetailScreen> {
  late Future<LegalDocumentModel> _future;
  final Set<int> _savedVersions = <int>{};
  String? _syncMessage;
  final Map<int, _PaperOriginalUploadAttempt> _originalUploads =
      <int, _PaperOriginalUploadAttempt>{};

  @override
  void initState() {
    super.initState();
    _future = _loadDocument();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Документ'),
      actions: [
        IconButton(
          tooltip: 'Обновить',
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<LegalDocumentModel>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppLoadingState(message: 'Загружаем документ');
        }
        if (!snapshot.hasData) {
          return AppErrorState(
            title: 'Не удалось загрузить документ',
            description: 'Повторите попытку позже.',
            onRetry: _reload,
          );
        }
        final document = snapshot.data!;

        return LegalDocumentDetail(
          document: document,
          onAction: _action,
          onVersionOpen:
              (version, purpose) => _openVersion(document, version, purpose),
          onVersionSave: _saveVersionOffline,
          savedVersions: Set<int>.unmodifiable(_savedVersions),
          syncMessage: _syncMessage,
          onPaperOriginalUpload:
              (request) => _uploadPaperOriginal(document, request),
          paperOriginalUploads:
              Map<int, PaperOriginalUploadState>.unmodifiable({
                for (final entry in _originalUploads.entries)
                  entry.key: entry.value.state,
              }),
          onPaperOriginalUploadCancel: _cancelPaperOriginalUpload,
          onPaperOriginalUploadRetry:
              (request) => _retryPaperOriginalUpload(document, request),
        );
      },
    ),
  );

  void _reload() {
    setState(() => _future = _loadDocument());
  }

  Future<LegalDocumentModel> _loadDocument() async {
    final notifier = ref.read(legalDocumentProvider.notifier);
    final document = await notifier.detail(widget.id);
    final saved = <int>{};
    for (final version in document.versions) {
      if (await notifier.isVersionSaved(
        documentId: document.id,
        versionId: version.id,
      )) {
        saved.add(version.id);
      }
    }
    final queue = await ref.read(syncQueueServiceProvider.future);
    final queuedOperations = (await queue.all()).where(
      (operation) =>
          operation.moduleSlug == 'legal_archive' &&
          operation.payload['queue_document_id']?.toString() ==
              document.id.toString(),
    );
    final lastOperation =
        queuedOperations.isEmpty ? null : queuedOperations.last;
    final syncMessage = switch (lastOperation?.status) {
      SyncOperationStatuses.conflict =>
        'Состояние документа изменилось. Проверьте его и повторите действие вручную.',
      SyncOperationStatuses.permissionDenied =>
        'Для отправки действия больше нет доступа. Обратитесь к администратору.',
      SyncOperationStatuses.needsEdit =>
        'Действие требует исправления перед отправкой.',
      SyncOperationStatuses.queued || SyncOperationStatuses.sending =>
        'Действие сохранено и будет отправлено после проверки связи.',
      _ => null,
    };
    if (mounted) {
      setState(() {
        _savedVersions
          ..clear()
          ..addAll(saved);
        _syncMessage = syncMessage;
      });
    }
    return document;
  }

  Future<void> _action(LegalDocumentAction action) async {
    final comment = await _comment(action);
    if (!mounted || comment == null) {
      return;
    }
    if ((action.requiresComment || action.requiresReason) &&
        comment.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите комментарий к действию')),
      );

      return;
    }
    try {
      await ref
          .read(legalDocumentProvider.notifier)
          .action(
            id: widget.id,
            action: action,
            comment: action.requiresComment ? comment : null,
            reason: action.requiresReason ? comment : null,
          );
      _reload();
    } on SyncQueuedException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Действие сохранено и будет отправлено после проверки связи',
            ),
          ),
        );
        _reload();
      }
    } on ApiException catch (error) {
      if (mounted) {
        final message = switch (error.statusCode) {
          403 =>
            'Для этого действия больше нет доступа. Обратитесь к администратору.',
          409 =>
            'Состояние документа изменилось. Обновите карточку и проверьте действие.',
          _ => 'Не удалось выполнить действие',
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        if (error.statusCode == 409 || error.statusCode == 403) _reload();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось выполнить действие')),
        );
      }
    }
  }

  Future<void> _openVersion(
    LegalDocumentModel document,
    LegalDocumentVersion version,
    String purpose,
  ) async {
    String? temporaryPath;
    try {
      Uri? uri;
      try {
        uri = await ref
            .read(legalDocumentProvider.notifier)
            .versionUrl(
              documentId: document.id,
              versionId: version.id,
              purpose: purpose,
            );
      } on ApiException catch (error) {
        if (error.statusCode == 401 || error.statusCode == 403) {
          if (error.statusCode == 403) {
            await ref
                .read(legalDocumentProvider.notifier)
                .deleteSavedVersion(
                  documentId: document.id,
                  versionId: version.id,
                );
            if (mounted) setState(() => _savedVersions.remove(version.id));
          }
          rethrow;
        }
        if (!shouldUseOfflineVersionAfterStatus(error.statusCode)) {
          rethrow;
        }
        if (!await ref
            .read(legalDocumentProvider.notifier)
            .isVersionSaved(documentId: document.id, versionId: version.id)) {
          rethrow;
        }
        temporaryPath = await ref
            .read(legalDocumentProvider.notifier)
            .openSavedVersion(
              documentId: document.id,
              versionId: version.id,
              fileName: version.fileName,
            );
      }
      final opened =
          temporaryPath == null
              ? await launchUrl(uri!, mode: LaunchMode.externalApplication)
              : (await OpenFilex.open(temporaryPath)).type == ResultType.done;
      if (!opened) {
        throw StateError('legal_document_url_not_opened');
      }
      if (temporaryPath != null) {
        final cache = ref.read(encryptedLocalFileCacheProvider);
        final openedPath = temporaryPath;
        Future<void>.delayed(const Duration(minutes: 2), () {
          return cache.deleteStagedUpload(openedPath);
        });
      }
    } on ApiException {
      if (temporaryPath != null) {
        try {
          await ref
              .read(encryptedLocalFileCacheProvider)
              .deleteStagedUpload(temporaryPath);
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Файл недоступен. Проверьте права и повторите попытку.',
            ),
          ),
        );
      }
    } catch (_) {
      if (temporaryPath != null) {
        try {
          await ref
              .read(encryptedLocalFileCacheProvider)
              .deleteStagedUpload(temporaryPath);
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть файл')),
        );
      }
    }
  }

  Future<void> _saveVersionOffline(LegalDocumentVersion version) async {
    try {
      await ref
          .read(legalDocumentProvider.notifier)
          .saveVersionForOffline(documentId: widget.id, version: version);
      if (!mounted) return;
      setState(() => _savedVersions.add(version.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл сохранён для работы без сети')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить файл')),
        );
      }
    }
  }

  Future<void> _uploadPaperOriginal(
    LegalDocumentModel document,
    LegalDocumentSignatureRequest request,
  ) async {
    final existing = _originalUploads[request.id];
    if (existing?.state.isUploading == true) {
      return;
    }
    final path =
        await ref.read(legalDocumentOriginalPickerProvider).pickFromCamera();
    if (!mounted || path == null || path.isEmpty) {
      return;
    }
    final attempt = _PaperOriginalUploadAttempt(
      filePath: path,
      signedAt: DateTime.now(),
      documentLockVersion: document.lockVersion,
      idempotencyKey: existing?.idempotencyKey ?? _idempotencyKey(),
    );
    setState(() => _originalUploads[request.id] = attempt);
    await _sendPaperOriginal(document, request, attempt);
  }

  Future<void> _retryPaperOriginalUpload(
    LegalDocumentModel document,
    LegalDocumentSignatureRequest request,
  ) async {
    final attempt = _originalUploads[request.id];
    if (attempt == null || attempt.state.isUploading) {
      return;
    }
    attempt.restart();
    setState(() {});
    await _sendPaperOriginal(document, request, attempt);
  }

  void _cancelPaperOriginalUpload(LegalDocumentSignatureRequest request) {
    final attempt = _originalUploads[request.id];
    if (attempt == null || !attempt.state.isUploading) {
      return;
    }
    attempt.cancel();
    setState(() {});
  }

  Future<void> _sendPaperOriginal(
    LegalDocumentModel document,
    LegalDocumentSignatureRequest request,
    _PaperOriginalUploadAttempt attempt,
  ) async {
    try {
      await ref
          .read(legalDocumentProvider.notifier)
          .uploadPaperOriginal(
            documentId: document.id,
            signatureRequestId: request.id,
            filePath: attempt.filePath,
            signedAt: attempt.signedAt,
            documentLockVersion: attempt.documentLockVersion,
            idempotencyKey: attempt.idempotencyKey,
            cancelToken: attempt.cancelToken,
            onSendProgress: (sent, total) {
              if (!mounted ||
                  total <= 0 ||
                  !identical(_originalUploads[request.id], attempt)) {
                return;
              }
              attempt.updateProgress(sent / total);
              setState(() {});
            },
          );
      if (mounted) {
        _originalUploads.remove(request.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Скан оригинала зарегистрирован')),
        );
        _reload();
      }
    } catch (error) {
      if (mounted) {
        if (error is SyncQueuedException) {
          attempt.markQueued();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Скан сохранён и будет отправлен после проверки связи',
              ),
            ),
          );
          _reload();
        } else if (attempt.wasCancelled) {
          attempt.markCancelled();
        } else if (error is ApiException && error.statusCode == 403) {
          attempt.markFailed();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Для загрузки больше нет доступа. Обратитесь к администратору.',
              ),
            ),
          );
          _reload();
        } else if (error is ApiException && error.statusCode == 409) {
          attempt.markFailed();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Состояние документа изменилось. Обновите карточку перед повтором.',
              ),
            ),
          );
          _reload();
        } else {
          attempt.markFailed();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось загрузить скан оригинала'),
            ),
          );
        }
        setState(() {});
      }
    }
  }

  Future<String?> _comment(LegalDocumentAction action) async {
    if (!action.requiresComment && !action.requiresReason) {
      return '';
    }
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(action.label),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Комментарий'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Отправить'),
              ),
            ],
          ),
    );
    controller.dispose();

    return result;
  }
}

String _idempotencyKey() {
  final suffix = DateTime.now().microsecondsSinceEpoch.toString();

  return '00000000-0000-4000-8000-${suffix.substring(suffix.length - 12)}';
}

class _PaperOriginalUploadAttempt {
  _PaperOriginalUploadAttempt({
    required this.filePath,
    required this.signedAt,
    required this.documentLockVersion,
    required this.idempotencyKey,
  }) : cancelToken = CancelToken(),
       state = const PaperOriginalUploadState.uploading(0);

  final String filePath;
  final DateTime signedAt;
  final int documentLockVersion;
  final String idempotencyKey;
  CancelToken cancelToken;
  PaperOriginalUploadState state;
  bool wasCancelled = false;

  void updateProgress(double value) {
    state = PaperOriginalUploadState.uploading(value.clamp(0, 1).toDouble());
  }

  void cancel() {
    wasCancelled = true;
    cancelToken.cancel('paper_original_upload_cancelled');
  }

  void restart() {
    wasCancelled = false;
    cancelToken = CancelToken();
    state = const PaperOriginalUploadState.uploading(0);
  }

  void markFailed() {
    state = const PaperOriginalUploadState.failed();
  }

  void markQueued() {
    state = const PaperOriginalUploadState.queued();
  }

  void markCancelled() {
    state = const PaperOriginalUploadState.cancelled();
  }
}
