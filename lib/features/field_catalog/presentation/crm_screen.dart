import 'package:flutter/material.dart';

import 'field_catalog_screen.dart';

class CrmScreen extends StatelessWidget {
  const CrmScreen({super.key});

  @override
  Widget build(BuildContext context) => const FieldCatalogScreen(
    title: 'CRM',
    catalog: 'crm',
    icon: Icons.business_center_outlined,
    entities: [
      FieldCatalogOption('companies', 'Компании'),
      FieldCatalogOption('contacts', 'Контакты'),
      FieldCatalogOption('leads', 'Лиды'),
      FieldCatalogOption('deals', 'Сделки'),
      FieldCatalogOption('activities', 'Активности'),
    ],
  );
}
