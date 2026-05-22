import 'package:flutter/material.dart';

import '../../module_companions/presentation/companion_module_screen.dart';

class ContractManagementScreen extends StatelessWidget {
  const ContractManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CompanionModuleScreen(
      moduleSlug: 'contract-management',
      title: 'Договоры',
      icon: Icons.assignment_outlined,
    );
  }
}
