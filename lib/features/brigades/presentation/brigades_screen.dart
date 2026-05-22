import 'package:flutter/material.dart';

import '../../module_companions/presentation/companion_module_screen.dart';

class BrigadesScreen extends StatelessWidget {
  const BrigadesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CompanionModuleScreen(
      moduleSlug: 'brigades',
      title: 'Бригады',
      icon: Icons.groups_2_outlined,
    );
  }
}
