import 'package:flutter/material.dart';

import '../../module_companions/presentation/companion_module_screen.dart';

class ExecutiveDocumentationScreen extends StatelessWidget {
  const ExecutiveDocumentationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CompanionModuleScreen(
      moduleSlug: 'executive-documentation',
      title: 'Исполнительная документация',
      icon: Icons.description_outlined,
    );
  }
}
