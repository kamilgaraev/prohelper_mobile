import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/pro_card.dart';
import '../../data/legal_document_model.dart';
import 'legal_document_actions.dart';

class LegalDocumentDetail extends StatelessWidget {
  const LegalDocumentDetail({
    required this.document,
    required this.onAction,
    required this.onVersionOpen,
    this.onVersionSave,
    this.savedVersions = const <int>{},
    this.syncMessage,
    required this.onPaperOriginalUpload,
    this.paperOriginalUploads = const <int, PaperOriginalUploadState>{},
    this.onPaperOriginalUploadCancel,
    this.onPaperOriginalUploadRetry,
    super.key,
  });

  final LegalDocumentModel document;
  final ValueChanged<LegalDocumentAction> onAction;
  final Future<void> Function(LegalDocumentVersion version, String purpose)
  onVersionOpen;
  final Future<void> Function(LegalDocumentVersion version)? onVersionSave;
  final Set<int> savedVersions;
  final String? syncMessage;
  final Future<void> Function(LegalDocumentSignatureRequest request)
  onPaperOriginalUpload;
  final Map<int, PaperOriginalUploadState> paperOriginalUploads;
  final ValueChanged<LegalDocumentSignatureRequest>?
  onPaperOriginalUploadCancel;
  final ValueChanged<LegalDocumentSignatureRequest>? onPaperOriginalUploadRetry;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
    children: [
      ProCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(document.title, style: AppTypography.h2(context)),
            const SizedBox(height: 8),
            Text(document.statusLabel),
            if (document.projectName != null) ...[
              const SizedBox(height: 6),
              Text(document.projectName!),
            ],
            if (document.counterpartyName != null) ...[
              const SizedBox(height: 6),
              Text(document.counterpartyName!),
            ],
          ],
        ),
      ),
      if (syncMessage != null) ...[
        const SizedBox(height: 12),
        ProCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sync_problem_outlined),
              const SizedBox(width: 10),
              Expanded(child: Text(syncMessage!)),
            ],
          ),
        ),
      ],
      if (document.workflow.problemFlags.isNotEmpty) ...[
        const SizedBox(height: 12),
        ProCard(
          child: Text(
            'Требует внимания: ${document.workflow.problemFlags.join(', ')}',
          ),
        ),
      ],
      if (document.workflow.actions.isNotEmpty) ...[
        const SizedBox(height: 12),
        LegalDocumentActions(
          actions: document.workflow.actions,
          onAction: onAction,
        ),
      ],
      if (document.obligations.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          'Обязательства',
          style: AppTypography.bodyLarge(
            context,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ...document.obligations.map(
          (obligation) => ProCard(
            child: ListTile(
              title: Text(obligation.title),
              subtitle: Text(
                obligation.dueAt == null
                    ? obligation.status
                    : '${obligation.status} · до ${obligation.dueAt!.day.toString().padLeft(2, '0')}.${obligation.dueAt!.month.toString().padLeft(2, '0')}.${obligation.dueAt!.year}',
              ),
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      Text(
        'Версии',
        style: AppTypography.bodyLarge(
          context,
        ).copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      ...document.versions.map(
        (version) => ProCard(
          child: ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(version.fileName ?? 'Версия ${version.versionNumber}'),
            subtitle: Text(
              version.processingStatus == 'ready'
                  ? (version.contentHash == null
                      ? 'Файл доступен по защищённой ссылке'
                      : 'Контрольная сумма сохранена')
                  : 'Файл готовится к просмотру',
            ),
            trailing: Wrap(
              spacing: 2,
              children: [
                IconButton(
                  tooltip: 'Просмотреть',
                  onPressed:
                      version.processingStatus == 'ready' &&
                              version.previewAvailable
                          ? () => onVersionOpen(version, 'preview')
                          : null,
                  icon: const Icon(Icons.visibility_outlined),
                ),
                IconButton(
                  tooltip: 'Скачать',
                  onPressed:
                      version.processingStatus == 'ready'
                          ? () => onVersionOpen(version, 'download')
                          : null,
                  icon: const Icon(Icons.download_outlined),
                ),
                IconButton(
                  tooltip:
                      savedVersions.contains(version.id)
                          ? 'Сохранено для работы без сети'
                          : 'Сохранить на устройстве',
                  onPressed:
                      onVersionSave == null ||
                              savedVersions.contains(version.id) ||
                              version.processingStatus != 'ready'
                          ? null
                          : () => onVersionSave!(version),
                  icon: Icon(
                    savedVersions.contains(version.id)
                        ? Icons.offline_pin_outlined
                        : Icons.save_alt_outlined,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (document.signatureRequests.any(
        (request) => request.supportsPaperOriginal,
      )) ...[
        const SizedBox(height: 16),
        Text(
          'Оригиналы',
          style: AppTypography.bodyLarge(
            context,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ...document.signatureRequests
            .where((request) => request.supportsPaperOriginal)
            .map((request) {
              final upload =
                  paperOriginalUploads[request.id] ??
                  const PaperOriginalUploadState.idle();

              return ProCard(
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Icon(
                      upload.isUploading
                          ? Icons.upload_file_outlined
                          : Icons.photo_camera_outlined,
                    ),
                    title: Text(upload.title),
                    subtitle:
                        upload.isUploading
                            ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(upload.description),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(value: upload.progress),
                              ],
                            )
                            : Text(upload.description),
                    trailing:
                        upload.isUploading
                            ? TextButton(
                              onPressed:
                                  onPaperOriginalUploadCancel == null
                                      ? null
                                      : () =>
                                          onPaperOriginalUploadCancel!(request),
                              child: const Text('Отменить'),
                            )
                            : upload.canRetry
                            ? TextButton(
                              onPressed:
                                  onPaperOriginalUploadRetry == null
                                      ? null
                                      : () =>
                                          onPaperOriginalUploadRetry!(request),
                              child: const Text('Повторить'),
                            )
                            : const Icon(Icons.chevron_right),
                    onTap:
                        upload.isInteractive
                            ? () => onPaperOriginalUpload(request)
                            : null,
                  ),
                ),
              );
            }),
      ],
    ],
  );
}

enum PaperOriginalUploadPhase { idle, uploading, queued, failed, cancelled }

class PaperOriginalUploadState {
  const PaperOriginalUploadState._(this.phase, {this.progress});

  const PaperOriginalUploadState.idle() : this._(PaperOriginalUploadPhase.idle);

  const PaperOriginalUploadState.uploading(double progress)
    : this._(PaperOriginalUploadPhase.uploading, progress: progress);

  const PaperOriginalUploadState.queued()
    : this._(PaperOriginalUploadPhase.queued);

  const PaperOriginalUploadState.failed()
    : this._(PaperOriginalUploadPhase.failed);

  const PaperOriginalUploadState.cancelled()
    : this._(PaperOriginalUploadPhase.cancelled);

  final PaperOriginalUploadPhase phase;
  final double? progress;

  bool get isUploading => phase == PaperOriginalUploadPhase.uploading;

  bool get canRetry =>
      phase == PaperOriginalUploadPhase.failed ||
      phase == PaperOriginalUploadPhase.cancelled;

  bool get isInteractive => phase == PaperOriginalUploadPhase.idle;

  String get title => switch (phase) {
    PaperOriginalUploadPhase.idle => 'Загрузить скан оригинала',
    PaperOriginalUploadPhase.uploading =>
      'Загрузка скана ${((progress ?? 0) * 100).round()}%',
    PaperOriginalUploadPhase.queued => 'Скан сохранён для отправки',
    PaperOriginalUploadPhase.failed => 'Не удалось загрузить скан',
    PaperOriginalUploadPhase.cancelled => 'Загрузка отменена',
  };

  String get description => switch (phase) {
    PaperOriginalUploadPhase.idle =>
      'Фотография или скан загружаются в защищённое хранилище.',
    PaperOriginalUploadPhase.uploading =>
      'Не закрывайте приложение до завершения загрузки.',
    PaperOriginalUploadPhase.queued =>
      'Отправим файл после проверки связи и входа.',
    PaperOriginalUploadPhase.failed =>
      'Проверьте подключение и повторите загрузку.',
    PaperOriginalUploadPhase.cancelled =>
      'Можно продолжить загрузку того же скана.',
  };
}
