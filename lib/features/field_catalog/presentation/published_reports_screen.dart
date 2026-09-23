import 'package:flutter/material.dart';

import 'field_catalog_screen.dart';

class PublishedReportsScreen extends StatelessWidget {
  const PublishedReportsScreen({super.key});

  @override
  Widget build(BuildContext context) => const FieldCatalogScreen(
    title: 'Опубликованные отчёты',
    catalog: 'reports',
    icon: Icons.summarize_outlined,
  );
}
