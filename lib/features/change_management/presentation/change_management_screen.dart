import 'package:flutter/material.dart';

import '../../module_companions/presentation/companion_module_screen.dart';

class ChangeManagementScreen extends StatelessWidget {
  const ChangeManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CompanionModuleScreen(
      moduleSlug: 'change-management',
      title: 'Изменения',
      icon: Icons.change_circle_outlined,
    );
  }
}
