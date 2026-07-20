import 'package:flutter/material.dart';

import '../../data/legal_document_model.dart';

class LegalDocumentActions extends StatelessWidget {
  const LegalDocumentActions({required this.actions, required this.onAction, super.key});
  final List<LegalDocumentAction> actions;
  final ValueChanged<LegalDocumentAction> onAction;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: actions.map((action) => action.enabled
        ? FilledButton(onPressed: () => onAction(action), child: Text(action.label))
        : Tooltip(message: action.blockers.join('\n'), child: OutlinedButton(onPressed: null, child: Text(action.label))))
      .toList(growable: false),
  );
}
