import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/industrial_card.dart';
import '../data/project_material_delivery_model.dart';
import '../data/warehouse_repository.dart';

class ProjectMaterialDeliveriesScreen extends ConsumerStatefulWidget {
  const ProjectMaterialDeliveriesScreen({super.key});

  @override
  ConsumerState<ProjectMaterialDeliveriesScreen> createState() =>
      _ProjectMaterialDeliveriesScreenState();
}

class _ProjectMaterialDeliveriesScreenState
    extends ConsumerState<ProjectMaterialDeliveriesScreen> {
  late Future<List<ProjectMaterialDeliveryModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ProjectMaterialDeliveryModel>> _load() {
    return ref
        .read(warehouseRepositoryProvider)
        .fetchProjectMaterialDeliveries();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Материалы на объект')),
      body: FutureBuilder<List<ProjectMaterialDeliveryModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return AppStateView(
              icon: Icons.error_outline_rounded,
              title: 'Не удалось загрузить поставки',
              description: snapshot.error.toString(),
              action: OutlinedButton(
                onPressed: _refresh,
                child: const Text('Повторить'),
              ),
            );
          }

          final items = snapshot.data ?? const <ProjectMaterialDeliveryModel>[];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: items.isEmpty
                ? const AppStateView(
                    icon: Icons.local_shipping_outlined,
                    title: 'Ожидаемых материалов нет',
                    description:
                        'Когда снабжение отправит материал на объект, поставка появится здесь.',
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final delivery = items[index];

                      return _DeliveryCard(
                        delivery: delivery,
                        onReceive:
                            delivery.canReceive
                                ? () => _showReceiveSheet(delivery)
                                : null,
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  Future<void> _showReceiveSheet(ProjectMaterialDeliveryModel delivery) async {
    final quantityController = TextEditingController(
      text:
          delivery.remainingToAccept > 0
              ? _formatQuantity(delivery.remainingToAccept)
              : '',
    );
    final notesController = TextEditingController();

    final received = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (sheetContext) => Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Принять материал', style: AppTypography.h2(context)),
                const SizedBox(height: 8),
                Text(
                  delivery.materialName ?? 'Материал',
                  style: AppTypography.bodyLarge(context),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Количество',
                    helperText:
                        'К приемке: ${_formatQuantity(delivery.remainingToAccept)} ${delivery.materialUnit ?? ''}',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final quantity = double.tryParse(
                        quantityController.text.trim().replaceAll(',', '.'),
                      );
                      if (quantity == null || quantity <= 0) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text('Укажите корректное количество.'),
                          ),
                        );
                        return;
                      }

                      try {
                        await ref
                            .read(warehouseRepositoryProvider)
                            .receiveProjectMaterialDelivery(
                              deliveryId: delivery.id,
                              quantity: quantity,
                              notes: notesController.text,
                            );

                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop(true);
                        }
                      } catch (error) {
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                error
                                    .toString()
                                    .replaceFirst('ApiException: ', ''),
                              ),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Подтвердить приемку'),
                  ),
                ),
              ],
            ),
          ),
    );

    quantityController.dispose();
    notesController.dispose();

    if (received == true && mounted) {
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Материал принят на объект.')),
        );
      }
    }
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.delivery, required this.onReceive});

  final ProjectMaterialDeliveryModel delivery;
  final VoidCallback? onReceive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(delivery.status);

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.local_shipping_outlined, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.materialName ?? 'Материал',
                      style: AppTypography.bodyLarge(
                        context,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      delivery.projectName ?? 'Объект не указан',
                      style: AppTypography.bodyMedium(context).copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                label: delivery.statusLabel ?? _statusLabel(delivery.status),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Заказано',
                  value:
                      '${_formatQuantity(delivery.requestedQuantity)} ${delivery.materialUnit ?? ''}',
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'В пути',
                  value:
                      '${_formatQuantity(delivery.shippedQuantity)} ${delivery.materialUnit ?? ''}',
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Принято',
                  value:
                      '${_formatQuantity(delivery.acceptedQuantity)} ${delivery.materialUnit ?? ''}',
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'План',
                  value: delivery.plannedDeliveryDate ?? 'Не указан',
                  alignEnd: true,
                ),
              ),
            ],
          ),
          if (onReceive != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onReceive,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Принять на объект'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
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
        Text(label, style: AppTypography.caption(context)),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: AppTypography.bodyMedium(
            context,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTypography.caption(
          context,
        ).copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

Color _statusColor(String status) {
  return switch (status.trim().toLowerCase()) {
    'accepted' || 'delivered' => AppColors.success,
    'in_transit' || 'partially_delivered' || 'preparing' => AppColors.warning,
    'problem' || 'cancelled' => AppColors.error,
    'reserved' || 'processing' || 'requested' => AppColors.primary,
    _ => AppColors.textSecondary,
  };
}

String _statusLabel(String status) {
  return switch (status.trim().toLowerCase()) {
    'requested' => 'Запрошено',
    'processing' => 'В обработке',
    'reserved' => 'Зарезервировано',
    'preparing' => 'Готовится',
    'in_transit' => 'В доставке',
    'partially_delivered' => 'Частично принято',
    'delivered' => 'Доставлено',
    'accepted' => 'Принято',
    'problem' => 'Проблема',
    'cancelled' => 'Отменено',
    _ => status,
  };
}

String _formatQuantity(double value) {
  return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
}
