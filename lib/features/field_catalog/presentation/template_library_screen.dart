import 'package:flutter/material.dart';

import 'field_catalog_screen.dart';

class TemplateLibraryScreen extends StatelessWidget {
  const TemplateLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) => const FieldCatalogScreen(
    title: 'Шаблоны отчётов',
    catalog: 'templates',
    icon: Icons.view_list_outlined,
    allowSearch: false,
  );
}
