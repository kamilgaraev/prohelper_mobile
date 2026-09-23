import 'package:flutter/material.dart';

import 'field_catalog_screen.dart';

class TendersScreen extends StatelessWidget {
  const TendersScreen({super.key});

  @override
  Widget build(BuildContext context) => const FieldCatalogScreen(
    title: 'Тендеры',
    catalog: 'tenders',
    icon: Icons.gavel_rounded,
  );
}
