import 'package:flutter/material.dart';
import '../knowledge_hub_screen.dart';

class KnowledgeContextHelpButton extends StatelessWidget {
  const KnowledgeContextHelpButton({
    super.key,
    required this.contextKey,
    this.moduleSlug,
    this.permissionKey,
    this.label = 'Нужна помощь?',
  });

  final String contextKey;
  final String? moduleSlug;
  final String? permissionKey;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => KnowledgeHubScreen(contextKey: contextKey)),
      ),
      icon: const Icon(Icons.help_outline_rounded),
      label: Text(label),
    );
  }
}
