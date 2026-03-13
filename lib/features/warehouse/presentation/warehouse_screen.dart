import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/industrial_card.dart';
import '../data/warehouse_summary_model.dart';
import '../domain/warehouse_provider.dart';

class WarehouseScreen extends ConsumerStatefulWidget {
  const WarehouseScreen({super.key});

  @override
  ConsumerState<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends ConsumerState<WarehouseScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(warehouseProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(warehouseProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Склад'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(warehouseProvider.notifier).load(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (state.isLoading && state.data == null)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.error != null && state.data == null)
              SliverFillRemaining(
                child: AppStateView(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить склад',
                  description: state.error,
                  action: OutlinedButton(
                    onPressed: () => ref.read(warehouseProvider.notifier).load(),
                    child: const Text('Повторить'),
                  ),
                ),
              )
            else if (state.data == null)
              const SliverFillRemaining(
                child: AppStateView(
                  icon: Icons.warehouse_outlined,
                  title: 'Нет данных по складу',
                  description: 'Как только на сервере появятся данные, они отобразятся здесь.',
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _SummarySection(summary: state.data!.summary),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Склады',
                    style: AppTypography.h2(context),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final warehouse = state.data!.warehouses[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _WarehouseCard(warehouse: warehouse),
                      );
                    },
                    childCount: state.data!.warehouses.length,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Последние движения',
                          style: AppTypography.h2(context),
                        ),
                      ),
                      if (state.isLoading)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (state.data!.recentMovements.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: AppStateView(
                      icon: Icons.swap_horiz_rounded,
                      title: 'Движений пока нет',
                      description: 'Последние складские операции появятся здесь.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final movement = state.data!.recentMovements[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MovementCard(movement: movement),
                        );
                      },
                      childCount: state.data!.recentMovements.length,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.summary});

  final WarehouseSummaryData summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Складов',
                value: summary.warehouseCount.toString(),
                icon: Icons.warehouse_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'Позиций',
                value: summary.uniqueItemsCount.toString(),
                icon: Icons.inventory_2_outlined,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Низкий остаток',
                value: summary.lowStockCount.toString(),
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'Резерв',
                value: summary.reservedItemsCount.toString(),
                icon: Icons.inventory_outlined,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        IndustrialCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.paid_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Стоимость доступных остатков',
                      style: AppTypography.bodyMedium(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(summary.totalValue),
                      style: AppTypography.h2(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double value) {
    final formatted = value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
    return '$formatted ₽';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTypography.h2(context),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTypography.caption(context),
          ),
        ],
      ),
    );
  }
}

class _WarehouseCard extends StatelessWidget {
  const _WarehouseCard({required this.warehouse});

  final WarehouseCardModel warehouse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  warehouse.name,
                  style: AppTypography.h2(context),
                ),
              ),
              if (warehouse.isMain)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Основной',
                    style: AppTypography.caption(context).copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (warehouse.address?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              warehouse.address!,
              style: AppTypography.bodyMedium(context).copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Позиций: ${warehouse.uniqueItemsCount}',
                  style: AppTypography.bodyMedium(context),
                ),
              ),
              Text(
                _formatCurrency(warehouse.totalValue),
                style: AppTypography.bodyMedium(context).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    final formatted = value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
    return '$formatted ₽';
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.movement});

  final WarehouseMovementModel movement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  movement.movementTypeLabel,
                  style: AppTypography.bodyLarge(context).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (movement.movementDate != null)
                Text(
                  _formatDate(movement.movementDate!),
                  style: AppTypography.caption(context),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            movement.materialName ?? 'Материал не указан',
            style: AppTypography.bodyMedium(context),
          ),
          const SizedBox(height: 4),
          Text(
            'Количество: ${movement.quantity} ${movement.measurementUnit ?? ''}'.trim(),
            style: AppTypography.bodyMedium(context).copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (movement.warehouseName?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              'Склад: ${movement.warehouseName}',
              style: AppTypography.bodyMedium(context).copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (movement.projectName?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              'Объект: ${movement.projectName}',
              style: AppTypography.bodyMedium(context).copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }
}
