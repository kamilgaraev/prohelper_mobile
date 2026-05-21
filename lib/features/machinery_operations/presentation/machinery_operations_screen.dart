import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../../core/widgets/pro_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/machinery_operations_model.dart';
import '../domain/machinery_operations_provider.dart';

class MachineryOperationsScreen extends ConsumerStatefulWidget {
  const MachineryOperationsScreen({super.key});

  @override
  ConsumerState<MachineryOperationsScreen> createState() =>
      _MachineryOperationsScreenState();
}

class _MachineryOperationsScreenState
    extends ConsumerState<MachineryOperationsScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedProject = ref.read(projectsProvider).selectedProject;
      final notifier = ref.read(machineryOperationsProvider.notifier);
      notifier.syncProject(selectedProject?.serverId);
      notifier.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(machineryOperationsProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;

    if (selectedProject?.serverId != state.projectFilter && !state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(machineryOperationsProvider.notifier);
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
          title: const Text('Техника'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed:
                  () => ref.read(machineryOperationsProvider.notifier).load(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body:
            state.isLoading &&
                    state.assets.isEmpty &&
                    state.shiftReports.isEmpty
                ? const AppLoadingState(message: 'Загружаем технику')
                : state.error != null &&
                    state.assets.isEmpty &&
                    state.shiftReports.isEmpty
                ? AppErrorState(
                  title: 'Не удалось загрузить технику',
                  description: state.error,
                  onRetry:
                      () =>
                          ref.read(machineryOperationsProvider.notifier).load(),
                )
                : RefreshIndicator(
                  onRefresh:
                      () =>
                          ref.read(machineryOperationsProvider.notifier).load(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      _SummaryStrip(state: state),
                      const SizedBox(height: 12),
                      if (state.assets.isEmpty)
                        const AppEmptyState(
                          icon: Icons.precision_manufacturing_outlined,
                          title: 'Техника пока не назначена',
                          description:
                              'Для выбранного объекта нет доступных единиц техники.',
                        )
                      else
                        ...state.assets.map(
                          (asset) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AssetCard(
                              asset: asset,
                              onShift:
                                  (asset) => _runAction(
                                    () => ref
                                        .read(
                                          machineryOperationsProvider.notifier,
                                        )
                                        .createShiftReport(asset),
                                  ),
                              onDowntime:
                                  (asset) => _runAction(
                                    () => ref
                                        .read(
                                          machineryOperationsProvider.notifier,
                                        )
                                        .createDowntime(asset),
                                  ),
                              onFuel:
                                  (asset) => _runAction(
                                    () => ref
                                        .read(
                                          machineryOperationsProvider.notifier,
                                        )
                                        .createFuelIssue(asset),
                                  ),
                            ),
                          ),
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.state});

  final MachineryOperationsState state;

  @override
  Widget build(BuildContext context) {
    final fuel = state.shiftReports.fold<double>(
      0,
      (total, report) => total + report.fuelConsumed,
    );

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Техника',
            value: state.assets.length.toString(),
            icon: Icons.precision_manufacturing_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'Рапорты',
            value: state.shiftReports.length.toString(),
            icon: Icons.assignment_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'ГСМ',
            value: _formatNumber(fuel),
            icon: Icons.local_gas_station_outlined,
          ),
        ),
      ],
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.asset,
    required this.onShift,
    required this.onDowntime,
    required this.onFuel,
  });

  final MachineryAssetModel asset;
  final ValueChanged<MachineryAssetModel> onShift;
  final ValueChanged<MachineryAssetModel> onDowntime;
  final ValueChanged<MachineryAssetModel> onFuel;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.precision_manufacturing_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.name,
                      style: AppTypography.bodyLarge(
                        context,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      asset.assetCode,
                      style: AppTypography.caption(context),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(asset.statusLabel),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onDowntime(asset),
                  icon: const Icon(Icons.pause_circle_outline_rounded),
                  label: const Text('Простой'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onFuel(asset),
                  icon: const Icon(Icons.local_gas_station_outlined),
                  label: const Text('ГСМ'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => onShift(asset),
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: const Text('Рапорт'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.h2(context)),
          Text(label, style: AppTypography.caption(context)),
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
