import 'package:flutter/material.dart';

import '../../module_companions/presentation/companion_module_screen.dart';

class CatalogManagementScreen extends StatelessWidget {
  const CatalogManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CompanionModuleScreen(
      moduleSlug: 'catalog-management',
      title: 'Справочники',
      icon: Icons.category_outlined,
    );
  }
}
