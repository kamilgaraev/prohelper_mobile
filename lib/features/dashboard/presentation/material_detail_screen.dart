import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/industrial_card.dart';

class MaterialDetailScreen extends StatelessWidget {
  final String materialId;

  const MaterialDetailScreen({super.key, required this.materialId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: theme.colorScheme.onSurface),
        title: Text('ДЕТАЛИ МАТЕРИАЛА', 
          style: AppTypography.h2(context).copyWith(fontSize: 16, letterSpacing: 1.5)
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Hero(
              tag: 'material_$materialId',
              child: IndustrialCard(
                height: 200,
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.inventory_2_rounded, size: 48, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 20),
                    Text('БЕТОН М400', 
                      style: AppTypography.h1(context).copyWith(fontSize: 24, letterSpacing: 1)
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            IndustrialCard(
              child: Column(
                children: [
                  _buildDetailRow(context, 'Объем', '12.5 м³'),
                  Divider(color: theme.colorScheme.outline.withOpacity(0.1), height: 24),
                  _buildDetailRow(context, 'Поставщик', 'ООО "СтройБетон"'),
                  Divider(color: theme.colorScheme.outline.withOpacity(0.1), height: 24),
                  _buildDetailRow(context, 'Время прибытия', '15:40'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.caption(context)),
        Text(value, style: AppTypography.bodySmall(context).copyWith(
          color: Theme.of(context).colorScheme.onSurface, 
          fontWeight: FontWeight.bold,
          fontSize: 14,
        )),
      ],
    );
  }
}
