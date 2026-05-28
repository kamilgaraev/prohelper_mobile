import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/design/pro_status.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/industrial_card.dart';
import '../../../core/widgets/pro_action_tile.dart';
import '../../../core/widgets/pro_metric_tile.dart';
import '../../../core/widgets/pro_status_banner.dart';
import '../data/warehouse_media_picker.dart';
import '../data/warehouse_repository.dart';
import '../data/warehouse_summary_model.dart';
import '../domain/warehouse_provider.dart';
import 'warehouse_receipt_sheet.dart';
import 'warehouse_scan_screen.dart';
import 'warehouse_tasks_screen.dart';
import 'project_material_deliveries_screen.dart';

enum _MovementFilter {
  all('Все'),
  receipt('Приход'),
  writeOff('Списание'),
  transfer('Перемещения');

  const _MovementFilter(this.label);

  final String label;
}

Future<bool?> showWarehouseReceiptSheet(
  BuildContext context, {
  required WarehouseSummaryModel summary,
  int? initialWarehouseId,
  WarehouseMaterialOption? initialMaterial,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder:
        (_) => WarehouseReceiptSheet(
          summary: summary,
          initialWarehouseId: initialWarehouseId,
          initialMaterial: initialMaterial,
        ),
  );
}

class WarehouseScreen extends ConsumerStatefulWidget {
  const WarehouseScreen({super.key});

  @override
  ConsumerState<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends ConsumerState<WarehouseScreen> {
  _MovementFilter _selectedFilter = _MovementFilter.all;

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
    final data = state.data;
    final filteredMovements =
        data == null
            ? const <WarehouseMovementModel>[]
            : data.recentMovements
                .where((movement) => _matchesFilter(movement, _selectedFilter))
                .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Склад'), centerTitle: false),
      floatingActionButton:
          data == null
              ? null
              : FloatingActionButton.extended(
                onPressed: () => _openReceiptSheet(context, data),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Оприходовать'),
              ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(warehouseProvider.notifier).load(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (state.isLoading && data == null)
              const SliverFillRemaining(
                child: AppLoadingState(message: 'Загружаем склад'),
              )
            else if (state.error != null && data == null)
              SliverFillRemaining(
                child: AppErrorState(
                  title:
                      state.permissionDenied
                          ? 'Недостаточно прав для склада'
                          : 'Не удалось загрузить склад',
                  description: state.error,
                  onRetry: () => ref.read(warehouseProvider.notifier).load(),
                ),
              )
            else if (data == null)
              const SliverFillRemaining(
                child: AppEmptyState(
                  icon: Icons.warehouse_outlined,
                  title: 'Нет данных по складу',
                  description:
                      'Когда на сервере появятся данные, они отобразятся здесь.',
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _SummarySection(summary: data.summary),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _OperationalHighlights(summary: data.summary),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _ScanEntryCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WarehouseScanScreen(summary: data),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _TaskQueueEntryCard(
                    onTap: () => _openTasksScreen(context, data),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _ProjectDeliveriesEntryCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => const ProjectMaterialDeliveriesScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Склады',
                    subtitle:
                        data.warehouses.isEmpty
                            ? 'Пока нет активных складов.'
                            : 'Открывай остатки, прикрепляй фото и запускай приход прямо с телефона.',
                  ),
                ),
              ),
              if (data.warehouses.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: AppEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Складов пока нет',
                      description:
                          'Когда в организации появятся активные склады, они будут показаны здесь.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final warehouse = data.warehouses[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _WarehouseCard(
                          warehouse: warehouse,
                          onOpenBalances:
                              () => _openBalancesSheet(context, warehouse),
                          onOpenReceipt:
                              () => _openReceiptSheet(
                                context,
                                data,
                                initialWarehouseId: warehouse.id,
                              ),
                          onOpenTasks:
                              () => _openTasksScreen(
                                context,
                                data,
                                initialWarehouseId: warehouse.id,
                              ),
                        ),
                      );
                    }, childCount: data.warehouses.length),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Последние движения',
                    subtitle:
                        'По каждому движению можно открыть галерею и дозагрузить фотографии.',
                  ),
                ),
              ),
              if (data.recentMovements.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            _MovementFilter.values.map((filter) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  selected: _selectedFilter == filter,
                                  label: Text(filter.label),
                                  onSelected:
                                      (_) => setState(() {
                                        _selectedFilter = filter;
                                      }),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                ),
              if (data.recentMovements.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: AppEmptyState(
                      icon: Icons.swap_horiz_rounded,
                      title: 'Движений пока нет',
                      description:
                          'Последние складские операции появятся здесь.',
                    ),
                  ),
                )
              else if (filteredMovements.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: AppEmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'По фильтру ничего не найдено',
                      description:
                          'Попробуй переключить фильтр и посмотреть другие движения.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final movement = filteredMovements[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MovementCard(
                          movement: movement,
                          onOpenGallery:
                              () => _openMovementGallery(context, movement),
                        ),
                      );
                    }, childCount: filteredMovements.length),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  bool _matchesFilter(WarehouseMovementModel movement, _MovementFilter filter) {
    return switch (filter) {
      _MovementFilter.all => true,
      _MovementFilter.receipt => movement.movementType == 'receipt',
      _MovementFilter.writeOff => movement.movementType == 'write_off',
      _MovementFilter.transfer =>
        movement.movementType == 'transfer_in' ||
            movement.movementType == 'transfer_out',
    };
  }

  Future<void> _openBalancesSheet(
    BuildContext context,
    WarehouseCardModel warehouse,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => _WarehouseBalancesSheet(
            warehouse: warehouse,
            onReceiptRequested: () async {
              Navigator.of(context).pop();
              final summary = ref.read(warehouseProvider).data;
              if (summary != null) {
                await _openReceiptSheet(
                  context,
                  summary,
                  initialWarehouseId: warehouse.id,
                );
              }
            },
          ),
    );
  }

  Future<void> _openReceiptSheet(
    BuildContext context,
    WarehouseSummaryModel summary, {
    int? initialWarehouseId,
  }) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => WarehouseReceiptSheet(
            summary: summary,
            initialWarehouseId: initialWarehouseId,
          ),
    );

    if (created != true || !mounted) {
      return;
    }

    await ref.read(warehouseProvider.notifier).load();

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Приход успешно проведен.')));
  }

  Future<void> _openMovementGallery(
    BuildContext context,
    WarehouseMovementModel movement,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => _WarehousePhotoGallerySheet(
            title: movement.materialName!,
            subtitle: movement.documentNumber ?? movement.movementTypeLabel,
            initialPhotos: movement.photoGallery,
            onUpload: (paths) {
              return ref
                  .read(warehouseRepositoryProvider)
                  .uploadMovementPhotos(movement.id, paths);
            },
            onDelete: (fileId) {
              return ref
                  .read(warehouseRepositoryProvider)
                  .deleteMovementPhoto(movement.id, fileId);
            },
          ),
    );

    if (mounted) {
      await ref.read(warehouseProvider.notifier).load();
    }
  }

  Future<void> _openTasksScreen(
    BuildContext context,
    WarehouseSummaryModel summary, {
    int? initialWarehouseId,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => WarehouseTasksScreen(
              summary: summary,
              initialWarehouseId: initialWarehouseId,
            ),
      ),
    );

    if (mounted) {
      await ref.read(warehouseProvider.notifier).load();
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.h2(context)),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTypography.bodyMedium(
            context,
          ).copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ScanEntryCard extends StatelessWidget {
  const _ScanEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ProActionTile(
      title: 'Сканирование склада',
      subtitle:
          'Распознать код и сразу перейти к подходящей складской операции.',
      icon: Icons.qr_code_scanner_rounded,
      onTap: onTap,
    );
  }
}

class _TaskQueueEntryCard extends StatelessWidget {
  const _TaskQueueEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ProActionTile(
      title: 'Очередь складских задач',
      subtitle:
          'Приемка, размещение, перемещение и инвентаризация в одном потоке.',
      icon: Icons.task_alt_rounded,
      tone: ProStatusTone.success,
      onTap: onTap,
    );
  }
}

class _ProjectDeliveriesEntryCard extends StatelessWidget {
  const _ProjectDeliveriesEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ProActionTile(
      title: 'Материалы на объект',
      subtitle: 'Поставки из склада и закупок, приемка доставки на объекте.',
      icon: Icons.local_shipping_outlined,
      tone: ProStatusTone.success,
      onTap: onTap,
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
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.08),
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
                    const SizedBox(height: 4),
                    Text(
                      'Движений за 7 дней: ${summary.recentMovementsCount}',
                      style: AppTypography.caption(context),
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
    final formatted = value.toStringAsFixed(
      value.truncateToDouble() == value ? 0 : 2,
    );
    return '$formatted ₽';
  }
}

class _OperationalHighlights extends StatelessWidget {
  const _OperationalHighlights({required this.summary});

  final WarehouseSummaryData summary;

  @override
  Widget build(BuildContext context) {
    final hasAttention =
        summary.lowStockCount > 0 || summary.reservedItemsCount > 0;

    return ProStatusBanner(
      title: hasAttention ? 'Требует внимания' : 'Склад в норме',
      description:
          hasAttention
              ? 'Низкий остаток: ${summary.lowStockCount}. В резерве: ${summary.reservedItemsCount}.'
              : 'Критических складских сигналов сейчас нет.',
      tone: hasAttention ? ProStatusTone.warning : ProStatusTone.success,
    );
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
    return ProMetricTile(label: title, value: value, icon: icon, color: color);
  }
}

class _WarehouseCard extends StatelessWidget {
  const _WarehouseCard({
    required this.warehouse,
    required this.onOpenBalances,
    required this.onOpenReceipt,
    required this.onOpenTasks,
  });

  final WarehouseCardModel warehouse;
  final VoidCallback onOpenBalances;
  final VoidCallback onOpenReceipt;
  final VoidCallback onOpenTasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(warehouse.name, style: AppTypography.h2(context)),
              ),
              if (warehouse.isMain) ...[
                _WarehouseChip(
                  label: 'Основной',
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.12,
                  ),
                  foregroundColor: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
              ],
              if (_warehouseTypeLabel(warehouse.warehouseType) != null)
                _WarehouseChip(
                  label: _warehouseTypeLabel(warehouse.warehouseType)!,
                  backgroundColor: theme.colorScheme.secondaryContainer
                      .withValues(alpha: 0.6),
                  foregroundColor: theme.colorScheme.onSecondaryContainer,
                ),
            ],
          ),
          if (warehouse.address?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    warehouse.address!,
                    style: AppTypography.bodyMedium(
                      context,
                    ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricItem(
                  label: 'Позиций',
                  value: warehouse.uniqueItemsCount.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricItem(
                  label: 'Остатки',
                  value: _formatCurrency(warehouse.totalValue),
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenBalances,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Остатки'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpenReceipt,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Приход'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenTasks,
              icon: const Icon(Icons.task_alt_outlined),
              label: const Text('Задачи склада'),
            ),
          ),
        ],
      ),
    );
  }

  String? _warehouseTypeLabel(String? warehouseType) {
    return switch (warehouseType?.trim()) {
      'central' => 'Центральный',
      'project' => 'Объектный',
      'external' => 'Внешний',
      null || '' => null,
      _ =>
        throw ArgumentError.value(
          warehouseType,
          'warehouseType',
          'Unknown warehouse type',
        ),
    };
  }

  String _formatCurrency(double value) {
    final formatted = value.toStringAsFixed(
      value.truncateToDouble() == value ? 0 : 2,
    );
    return '$formatted ₽';
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.movement, required this.onOpenGallery});

  final WarehouseMovementModel movement;
  final VoidCallback onOpenGallery;

  @override
  Widget build(BuildContext context) {
    final accentColor = switch (movement.movementType) {
      'receipt' => AppColors.success,
      'write_off' => AppColors.warning,
      'transfer_in' || 'transfer_out' => AppColors.secondary,
      'adjustment' => Colors.blueGrey,
      'return' => Colors.teal,
      _ =>
        throw ArgumentError.value(
          movement.movementType,
          'movementType',
          'Unknown warehouse movement type',
        ),
    };

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  movement.movementTypeLabel,
                  style: AppTypography.caption(
                    context,
                  ).copyWith(color: accentColor, fontWeight: FontWeight.w800),
                ),
              ),
              const Spacer(),
              if (movement.movementDate != null)
                Text(
                  _formatDate(movement.movementDate!),
                  style: AppTypography.caption(context),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            movement.materialName!,
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MetricItem(
                  label: 'Количество',
                  value:
                      '${_formatQuantity(movement.quantity)} ${movement.measurementUnit ?? ''}'
                          .trim(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricItem(
                  label: 'Сумма',
                  value: _formatCurrency(movement.price),
                  alignEnd: true,
                ),
              ),
            ],
          ),
          if (movement.warehouseName?.isNotEmpty == true ||
              movement.projectName?.isNotEmpty == true ||
              movement.documentNumber?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (movement.warehouseName?.isNotEmpty == true)
                  _InfoPill(
                    icon: Icons.warehouse_outlined,
                    text: movement.warehouseName!,
                  ),
                if (movement.projectName?.isNotEmpty == true)
                  _InfoPill(
                    icon: Icons.apartment_outlined,
                    text: movement.projectName!,
                  ),
                if (movement.documentNumber?.isNotEmpty == true)
                  _InfoPill(
                    icon: Icons.description_outlined,
                    text: movement.documentNumber!,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _PhotoPreviewStrip(
            photos: movement.photoGallery,
            emptyText: 'Фото не добавлены',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpenGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
              movement.photoGallery.isEmpty
                  ? 'Открыть галерею'
                  : 'Галерея (${movement.photoGallery.length})',
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  String _formatQuantity(double value) {
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  }

  String _formatCurrency(double value) {
    final formatted = value.toStringAsFixed(
      value.truncateToDouble() == value ? 0 : 2,
    );
    return '$formatted ₽';
  }
}

class _WarehouseBalancesSheet extends ConsumerStatefulWidget {
  const _WarehouseBalancesSheet({
    required this.warehouse,
    required this.onReceiptRequested,
  });

  final WarehouseCardModel warehouse;
  final Future<void> Function() onReceiptRequested;

  @override
  ConsumerState<_WarehouseBalancesSheet> createState() =>
      _WarehouseBalancesSheetState();
}

class _WarehouseBalancesSheetState
    extends ConsumerState<_WarehouseBalancesSheet> {
  late Future<List<WarehouseBalanceModel>> _balancesFuture;

  @override
  void initState() {
    super.initState();
    _balancesFuture = _loadBalances();
  }

  Future<List<WarehouseBalanceModel>> _loadBalances() {
    return ref
        .read(warehouseRepositoryProvider)
        .fetchBalances(widget.warehouse.id);
  }

  Future<void> _refreshBalances() async {
    setState(() {
      _balancesFuture = _loadBalances();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BottomSheetHandle(title: widget.warehouse.name),
            const SizedBox(height: 8),
            Text(
              'Остатки, фото позиций и быстрый переход к приходу.',
              style: AppTypography.bodyMedium(
                context,
              ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _refreshBalances,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Обновить'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onReceiptRequested,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Приход'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<WarehouseBalanceModel>>(
                future: _balancesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const AppLoadingState(
                      message: 'Загружаем остатки',
                      compact: true,
                    );
                  }

                  if (snapshot.hasError) {
                    return AppErrorState(
                      title: 'Не удалось загрузить остатки',
                      description: snapshot.error.toString(),
                      onRetry: _refreshBalances,
                    );
                  }

                  final balances = snapshot.data;
                  if (balances == null) {
                    return AppErrorState(
                      title: 'Не удалось загрузить остатки',
                      description: 'Сервер вернул неполные данные по остаткам.',
                      onRetry: _refreshBalances,
                    );
                  }

                  if (balances.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'На складе пока нет остатков',
                      description:
                          'После первого прихода позиции появятся здесь.',
                    );
                  }

                  return ListView.separated(
                    itemCount: balances.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final balance = balances[index];

                      return _BalanceCard(
                        balance: balance,
                        onOpenGallery: () async {
                          await showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            builder:
                                (_) => _WarehousePhotoGallerySheet(
                                  title: balance.materialName,
                                  subtitle: balance.warehouseName,
                                  initialPhotos: balance.effectivePhotoGallery,
                                  onUpload: (paths) {
                                    return ref
                                        .read(warehouseRepositoryProvider)
                                        .uploadBalancePhotos(
                                          balance.warehouseId,
                                          balance.materialId,
                                          paths,
                                        );
                                  },
                                  onDelete: (fileId) {
                                    return ref
                                        .read(warehouseRepositoryProvider)
                                        .deleteBalancePhoto(
                                          balance.warehouseId,
                                          balance.materialId,
                                          fileId,
                                        );
                                  },
                                ),
                          );

                          await _refreshBalances();
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.onOpenGallery});

  final WarehouseBalanceModel balance;
  final VoidCallback onOpenGallery;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  balance.materialName,
                  style: AppTypography.bodyLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (balance.isLowStock)
                _WarehouseChip(
                  label: 'Низкий остаток',
                  backgroundColor: AppColors.warning.withValues(alpha: 0.12),
                  foregroundColor: AppColors.warning,
                ),
            ],
          ),
          if ((balance.materialCode ?? '').isNotEmpty ||
              (balance.locationCode ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((balance.materialCode ?? '').isNotEmpty)
                  _InfoPill(
                    icon: Icons.qr_code_2_rounded,
                    text: balance.materialCode!,
                  ),
                if ((balance.locationCode ?? '').isNotEmpty)
                  _InfoPill(
                    icon: Icons.place_outlined,
                    text: balance.locationCode!,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricItem(
                  label: 'Доступно',
                  value:
                      '${_formatQuantity(balance.availableQuantity)} ${balance.measurementUnit ?? ''}'
                          .trim(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricItem(
                  label: 'В резерве',
                  value: _formatQuantity(balance.reservedQuantity),
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricItem(
                  label: 'Средняя цена',
                  value: _formatCurrency(balance.averagePrice),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricItem(
                  label: 'Сумма',
                  value: _formatCurrency(balance.totalValue),
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PhotoPreviewStrip(
            photos: balance.effectivePhotoGallery,
            emptyText: 'Нет фотографий позиции',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpenGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
              balance.effectivePhotoGallery.isEmpty
                  ? 'Галерея'
                  : 'Галерея (${balance.effectivePhotoGallery.length})',
            ),
          ),
        ],
      ),
    );
  }

  String _formatQuantity(double value) {
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  }

  String _formatCurrency(double value) {
    final formatted = value.toStringAsFixed(
      value.truncateToDouble() == value ? 0 : 2,
    );
    return '$formatted ₽';
  }
}

class _WarehousePhotoGallerySheet extends ConsumerStatefulWidget {
  const _WarehousePhotoGallerySheet({
    required this.title,
    required this.subtitle,
    required this.initialPhotos,
    required this.onUpload,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final List<WarehousePhotoModel> initialPhotos;
  final Future<List<WarehousePhotoModel>> Function(List<String> photoPaths)
  onUpload;
  final Future<void> Function(int fileId) onDelete;

  @override
  ConsumerState<_WarehousePhotoGallerySheet> createState() =>
      _WarehousePhotoGallerySheetState();
}

class _WarehousePhotoGallerySheetState
    extends ConsumerState<_WarehousePhotoGallerySheet> {
  static const int _maxPhotos = 4;

  late List<WarehousePhotoModel> _photos;
  bool _isUploading = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _photos = List<WarehousePhotoModel>.from(widget.initialPhotos);
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BottomSheetHandle(title: widget.title),
            const SizedBox(height: 8),
            Text(
              widget.subtitle,
              style: AppTypography.bodyMedium(
                context,
              ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _isUploading || _photos.length >= _maxPhotos
                            ? null
                            : _uploadFromCamera,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Камера'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _isUploading || _photos.length >= _maxPhotos
                            ? null
                            : _uploadFromGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Галерея'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Фотографий: ${_photos.length} из $_maxPhotos',
              style: AppTypography.caption(context),
            ),
            const SizedBox(height: 12),
            Expanded(
              child:
                  _photos.isEmpty
                      ? const AppEmptyState(
                        icon: Icons.image_not_supported_outlined,
                        title: 'Фотографий пока нет',
                        description:
                            'Сделай снимок камерой или добавь изображения из галереи.',
                      )
                      : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.92,
                            ),
                        itemCount: _photos.length,
                        itemBuilder: (context, index) {
                          final photo = _photos[index];

                          return GestureDetector(
                            onTap: () => _openViewer(index),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    photo.url,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) => Container(
                                          color:
                                              Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.broken_image_outlined,
                                          ),
                                        ),
                                  ),
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Material(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(999),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        onTap:
                                            _isDeleting
                                                ? null
                                                : () => _deletePhoto(photo.id),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.delete_outline,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadFromCamera() async {
    final remain = _maxPhotos - _photos.length;
    if (remain <= 0) {
      _showMessage('Можно прикрепить не больше 4 фотографий.');
      return;
    }
    final path = await ref.read(warehouseMediaPickerProvider).pickFromCamera();
    if (path != null) {
      await _uploadPhotos([path]);
    }
  }

  Future<void> _uploadFromGallery() async {
    final remain = _maxPhotos - _photos.length;
    if (remain <= 0) {
      _showMessage('Можно прикрепить не больше 4 фотографий.');
      return;
    }
    final paths = await ref
        .read(warehouseMediaPickerProvider)
        .pickFromGallery(limit: remain);
    if (paths.isNotEmpty) {
      await _uploadPhotos(paths.take(remain).toList());
    }
  }

  Future<void> _uploadPhotos(List<String> paths) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final uploaded = await widget.onUpload(paths);
      if (mounted) {
        setState(() {
          _photos = uploaded;
        });
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _deletePhoto(int fileId) async {
    setState(() {
      _isDeleting = true;
    });

    try {
      await widget.onDelete(fileId);
      if (mounted) {
        setState(() {
          _photos = _photos.where((photo) => photo.id != fileId).toList();
        });
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Future<void> _openViewer(int initialIndex) async {
    await showDialog<void>(
      context: context,
      builder:
          (context) => Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(title: Text(widget.title)),
              body: PageView.builder(
                controller: PageController(initialPage: initialIndex),
                itemCount: _photos.length,
                itemBuilder: (context, index) {
                  final photo = _photos[index];
                  return InteractiveViewer(
                    child: Center(
                      child: Image.network(
                        photo.url,
                        fit: BoxFit.contain,
                        errorBuilder:
                            (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              size: 64,
                            ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('ApiException: ', ''))),
    );
  }
}

class _PhotoPreviewStrip extends StatelessWidget {
  const _PhotoPreviewStrip({required this.photos, required this.emptyText});

  final List<WarehousePhotoModel> photos;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Text(emptyText, style: AppTypography.caption(context));
    }

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final photo = photos[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                photo.url,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported_outlined),
                    ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: AppTypography.caption(context),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: AppTypography.bodyLarge(
            context,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _WarehouseChip extends StatelessWidget {
  const _WarehouseChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.caption(
          context,
        ).copyWith(color: foregroundColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(text, style: AppTypography.caption(context)),
        ],
      ),
    );
  }
}

class _BottomSheetHandle extends StatelessWidget {
  const _BottomSheetHandle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(title, style: AppTypography.h2(context)),
        ),
      ],
    );
  }
}
