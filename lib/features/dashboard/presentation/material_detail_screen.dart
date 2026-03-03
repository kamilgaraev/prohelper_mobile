import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/industrial_card.dart';

class MaterialDetailScreen extends StatelessWidget {
  final String materialId;

  const MaterialDetailScreen({super.key, required this.materialId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text('ДЕТАЛИ МАТЕРИАЛА', 
          style: AppTypography.h2.copyWith(fontSize: 16, letterSpacing: 1.5)
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
                backgroundColor: AppColors.surface,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.inventory_2_rounded, size: 48, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text('БЕТОН М400', 
                      style: AppTypography.h1.copyWith(fontSize: 24, letterSpacing: 1)
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            IndustrialCard(
              child: Column(
                children: [
                  _buildDetailRow('Объем', '12.5 м³'),
                  const Divider(color: AppColors.surfaceLight, height: 24),
                  _buildDetailRow('Поставщик', 'ООО "СтройБетон"'),
                  const Divider(color: AppColors.surfaceLight, height: 24),
                  _buildDetailRow('Время прибытия', '15:40'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.caption),
        Text(value, style: AppTypography.bodySmall.copyWith(
          color: Colors.white, 
          fontWeight: FontWeight.bold,
          fontSize: 14,
        )),
      ],
    );
  }
}
