import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/pro_card.dart';
import '../../data/legal_document_model.dart';

class LegalDocumentList extends StatelessWidget {
  const LegalDocumentList({required this.documents, required this.onOpen, super.key});
  final List<LegalDocumentModel> documents;
  final ValueChanged<LegalDocumentModel> onOpen;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
    itemCount: documents.length,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (context, index) {
      final document = documents[index];
      return ProCard(
        onTap: () => onOpen(document),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(document.title, style: AppTypography.bodyLarge(context).copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text([document.documentTypeLabel, document.documentNumber].whereType<String>().join(' · '), style: AppTypography.caption(context)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text(document.statusLabel, style: AppTypography.bodyMedium(context))),
            if (document.workflow.problemFlags.isNotEmpty) const Icon(Icons.warning_amber_rounded),
          ]),
        ]),
      );
    },
  );
}
