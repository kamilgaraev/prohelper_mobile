import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/industrial_card.dart';
import '../data/project_material_delivery_model.dart';
import '../data/warehouse_repository.dart';

class ProjectResourceAnalyticsScreen extends ConsumerStatefulWidget {
  const ProjectResourceAnalyticsScreen({
    required this.projectId,
    required this.projectName,
    super.key,
  });

  final int projectId;
  final String projectName;

  @override
  ConsumerState<ProjectResourceAnalyticsScreen> createState() =>
      _ProjectResourceAnalyticsScreenState();
}

class _ProjectResourceAnalyticsScreenState
    extends ConsumerState<ProjectResourceAnalyticsScreen> {
  late Future<ProjectMaterialStockModel> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ProjectMaterialStockModel> _load() => ref
      .read(warehouseRepositoryProvider)
      .fetchProjectMaterialStock(projectId: widget.projectId);

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Остатки и расход')),
      body: FutureBuilder<ProjectMaterialStockModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(
              message: 'Загружаем материалы объекта',
            );
          }
          if (snapshot.hasError) {
            return AppErrorState(
              title: 'Не удалось загрузить остатки',
              description: UserMessage.fromError(snapshot.error!),
              onRetry: _refresh,
            );
          }

          final stock = snapshot.data;
          if (stock == null) {
            return AppErrorState(
              title: 'Нет данных по остаткам',
              description: 'Сервер не вернул данные материалов объекта.',
              onRetry: _refresh,
            );
          }

          final items = stock.items
              .where((item) => item.projectId == widget.projectId)
              .toList(growable: false);
          return RefreshIndicator(
            onRefresh: _refresh,
            child:
                items.isEmpty
                    ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 100),
                        AppEmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'Остатков пока нет',
                          description:
                              'Принятые материалы и их расход появятся здесь для объекта «${widget.projectName}».',
                        ),
                      ],
                    )
                    : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        _SummaryCard(summary: stock.summary),
                        const SizedBox(height: 12),
                        for (final item in items) ...[
                          _MaterialCard(item: item),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final ProjectMaterialStockSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Сводка объекта',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _Metric(
            label: 'Остаток',
            value: _quantity(summary.availableQuantity),
          ),
          _Metric(
            label: 'Израсходовано',
            value: _quantity(summary.usedQuantity),
          ),
          _Metric(label: 'Принято', value: _quantity(summary.acceptedQuantity)),
          _Metric(label: 'Материалов', value: '${summary.materialsCount}'),
        ],
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.item});

  final ProjectMaterialStockItemModel item;

  @override
  Widget build(BuildContext context) {
    final unit = item.materialUnit;
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.materialName ?? 'Материал',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _Metric(
            label: 'Остаток',
            value: _quantity(item.availableQuantity, unit),
          ),
          _Metric(
            label: 'Израсходовано',
            value: _quantity(item.usedQuantity, unit),
          ),
          _Metric(
            label: 'Принято',
            value: _quantity(item.acceptedQuantity, unit),
          ),
          if (item.usages.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              'Расход по журналу',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            for (final usage in item.usages)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${usage.entryDate == null ? 'Без даты' : _date(usage.entryDate!)} · '
                  '${usage.workDescription?.trim().isNotEmpty == true ? usage.workDescription : 'Запись журнала'} · '
                  '${_quantity(usage.quantity, usage.measurementUnit ?? unit)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

String _quantity(double value, [String? unit]) {
  final formatted =
      value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value
              .toStringAsFixed(3)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
  return unit == null || unit.isEmpty ? formatted : '$formatted $unit';
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
