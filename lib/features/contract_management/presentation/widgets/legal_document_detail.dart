import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/pro_card.dart';
import '../../data/legal_document_model.dart';
import 'legal_document_actions.dart';

class LegalDocumentDetail extends StatelessWidget {
  const LegalDocumentDetail({required this.document, required this.onAction, super.key});
  final LegalDocumentModel document;
  final ValueChanged<LegalDocumentAction> onAction;

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
      const SizedBox(height: 16),
      Text('Версии', style: AppTypography.bodyLarge(context).copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      ...document.versions.map((version) => ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(version.fileName ?? 'Версия ${version.versionNumber}'),
        subtitle: Text(version.contentHash == null ? 'Файл доступен по защищённой ссылке' : 'Контрольная сумма сохранена'),
      )),
    ],
  );
}
