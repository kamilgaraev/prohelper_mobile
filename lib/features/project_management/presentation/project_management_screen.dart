import 'package:flutter/material.dart';

import '../../module_companions/presentation/companion_module_screen.dart';

class ProjectManagementScreen extends StatelessWidget {
  const ProjectManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CompanionModuleScreen(
      moduleSlug: 'project-management',
      title: 'Управление проектом',
      icon: Icons.domain_rounded,
    );
  }
}
