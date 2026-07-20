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
    required this.onPaperOriginalUpload,
    super.key,
  });

  final LegalDocumentModel document;
  final ValueChanged<LegalDocumentAction> onAction;
  final Future<void> Function(LegalDocumentVersion version, String purpose) onVersionOpen;
  final Future<void> Function(LegalDocumentSignatureRequest request) onPaperOriginalUpload;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
    children: [
      ProCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(document.title, style: AppTypography.h2(context)),
        const SizedBox(height: 8),
        Text(document.statusLabel),
        if (document.projectName != null) ...[const SizedBox(height: 6), Text(document.projectName!)],
        if (document.counterpartyName != null) ...[const SizedBox(height: 6), Text(document.counterpartyName!)],
      ])),
      if (document.workflow.problemFlags.isNotEmpty) ...[
        const SizedBox(height: 12),
        ProCard(child: Text('Требует внимания: ${document.workflow.problemFlags.join(', ')}')),
      ],
      if (document.workflow.actions.isNotEmpty) ...[
        const SizedBox(height: 12),
        LegalDocumentActions(actions: document.workflow.actions, onAction: onAction),
      ],
      if (document.obligations.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Обязательства', style: AppTypography.bodyLarge(context).copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...document.obligations.map((obligation) => ProCard(child: ListTile(
          title: Text(obligation.title),
          subtitle: Text(obligation.dueAt == null
              ? obligation.status
              : '${obligation.status} · до ${obligation.dueAt!.day.toString().padLeft(2, '0')}.${obligation.dueAt!.month.toString().padLeft(2, '0')}.${obligation.dueAt!.year}'),
        ))),
      ],
      const SizedBox(height: 16),
      Text('Версии', style: AppTypography.bodyLarge(context).copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      ...document.versions.map((version) => ProCard(child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(version.fileName ?? 'Версия ${version.versionNumber}'),
        subtitle: Text(version.processingStatus == 'ready'
            ? (version.contentHash == null ? 'Файл доступен по защищённой ссылке' : 'Контрольная сумма сохранена')
            : 'Файл готовится к просмотру'),
        trailing: Wrap(spacing: 2, children: [
          IconButton(
            tooltip: 'Просмотреть',
            onPressed: version.processingStatus == 'ready' && version.previewAvailable
                ? () => onVersionOpen(version, 'preview')
                : null,
            icon: const Icon(Icons.visibility_outlined),
          ),
          IconButton(
            tooltip: 'Скачать',
            onPressed: version.processingStatus == 'ready'
                ? () => onVersionOpen(version, 'download')
                : null,
            icon: const Icon(Icons.download_outlined),
          ),
        ]),
      ))),
      if (document.signatureRequests.any((request) => request.supportsPaperOriginal)) ...[
        const SizedBox(height: 16),
        Text('Оригиналы', style: AppTypography.bodyLarge(context).copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...document.signatureRequests.where((request) => request.supportsPaperOriginal).map((request) => ProCard(
          child: ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Загрузить скан оригинала'),
            subtitle: const Text('Фотография или скан загружаются в защищённое хранилище.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onPaperOriginalUpload(request),
          ),
        )),
      ],
    ],
  );
}
