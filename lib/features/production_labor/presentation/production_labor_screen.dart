import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../../core/widgets/pro_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/production_labor_model.dart';
import '../domain/production_labor_provider.dart';

class ProductionLaborScreen extends ConsumerStatefulWidget {
  const ProductionLaborScreen({super.key});

  @override
  ConsumerState<ProductionLaborScreen> createState() => _ProductionLaborScreenState();
}

class _ProductionLaborScreenState extends ConsumerState<ProductionLaborScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedProject = ref.read(projectsProvider).selectedProject;
      final notifier = ref.read(productionLaborProvider.notifier);
      notifier.syncProject(selectedProject?.serverId);
      notifier.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productionLaborProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;

    if (selectedProject?.serverId != state.projectFilter && !state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(productionLaborProvider.notifier);
        notifier.syncProject(selectedProject?.serverId);
        notifier.load();
      });
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Наряды'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed: () => ref.read(productionLaborProvider.notifier).load(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: state.isLoading && state.workOrders.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.error != null && state.workOrders.isEmpty
                ? AppStateView(
                    icon: Icons.engineering_outlined,
                    title: 'Не удалось загрузить наряды',
                    description: state.error,
                    action: OutlinedButton(
                      onPressed: () => ref.read(productionLaborProvider.notifier).load(),
                      child: const Text('Повторить'),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => ref.read(productionLaborProvider.notifier).load(),
                    child: state.workOrders.isEmpty
                        ? const AppStateView(
                            icon: Icons.engineering_outlined,
                            title: 'Нарядов пока нет',
                            description: 'Для выбранного объекта нет выданных нарядов.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: state.workOrders.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) => _WorkOrderCard(
                              workOrder: state.workOrders[index],
                              onRecordOutput: (workOrder, line) => _runAction(
                                () => ref.read(productionLaborProvider.notifier).recordOutput(workOrder, line),
                              ),
                              onCreateTimesheet: (workOrder, line) => _showTimesheetSheet(context, workOrder, line),
                            ),
                          ),
                  ),
      ),
    );
  }

  Future<void> _showTimesheetSheet(
    BuildContext context,
    LaborWorkOrderModel workOrder,
    LaborWorkOrderLineModel line,
  ) async {
    final permitController = TextEditingController();
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Табель смены', style: AppTypography.h2(context)),
              const SizedBox(height: 8),
              Text(line.name, style: AppTypography.bodyMedium(context)),
              if (line.requiresSafetyPermit) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: permitController,
                  decoration: const InputDecoration(labelText: 'Допуск'),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        if (line.requiresSafetyPermit && permitController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Укажите допуск')),
                          );
                          return;
                        }

                        setSheetState(() => submitting = true);
                        try {
                          await ref.read(productionLaborProvider.notifier).createTimesheet(
                                workOrder,
                                line,
                                safetyPermitReference: permitController.text.trim(),
                              );
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        } finally {
                          if (context.mounted) {
                            setSheetState(() => submitting = false);
                          }
                        }
                      },
                child: Text(submitting ? 'Сохранение...' : 'Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _WorkOrderCard extends StatelessWidget {
  const _WorkOrderCard({
    required this.workOrder,
    required this.onRecordOutput,
    required this.onCreateTimesheet,
  });

  final LaborWorkOrderModel workOrder;
  final void Function(LaborWorkOrderModel workOrder, LaborWorkOrderLineModel line) onRecordOutput;
  final void Function(LaborWorkOrderModel workOrder, LaborWorkOrderLineModel line) onCreateTimesheet;

  @override
  Widget build(BuildContext context) {
    final line = workOrder.lines.isNotEmpty ? workOrder.lines.first : null;

    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.engineering_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workOrder.title, style: AppTypography.bodyLarge(context).copyWith(fontWeight: FontWeight.w800)),
                    Text(workOrder.orderNumber, style: AppTypography.caption(context)),
                  ],
                ),
              ),
              Chip(label: Text(workOrder.statusLabel), visualDensity: VisualDensity.compact),
            ],
          ),
          if (line != null) ...[
            const SizedBox(height: 12),
            Text(line.name, style: AppTypography.bodyMedium(context)),
            const SizedBox(height: 4),
            Text(
              'Принято ${_formatNumber(line.acceptedQuantity)} из ${_formatNumber(line.plannedQuantity)} ${line.unit}',
              style: AppTypography.caption(context),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: workOrder.canRecordFact ? () => onRecordOutput(workOrder, line) : null,
                    icon: const Icon(Icons.done_all_rounded),
                    label: const Text('Выработка'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: workOrder.canRecordFact ? () => onCreateTimesheet(workOrder, line) : null,
                    icon: const Icon(Icons.access_time_rounded),
                    label: const Text('Табель'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toStringAsFixed(1);
}
