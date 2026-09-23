import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/machinery_operations_model.dart';
import '../../domain/machinery_action.dart';
import '../../domain/machinery_operations_provider.dart';
import '../widgets/machinery_sync_status_panel.dart';

class OperatorShiftScreen extends ConsumerWidget {
  const OperatorShiftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineryOperationsProvider);
    final asset = state.assets.firstOrNull;
    final shift =
        asset == null
            ? null
            : state.shiftReports
                .where(
                  (item) => item.assetId == asset.id && item.status == 'draft',
                )
                .firstOrNull;
    final blockedShift =
        asset == null
            ? null
            : state.shiftReports
                .where(
                  (item) =>
                      item.assetId == asset.id && item.status == 'blocked',
                )
                .firstOrNull;

    return _RoleScaffold(
      title: 'Смена оператора',
      onRefresh: () => ref.read(machineryOperationsProvider.notifier).load(),
      children: [
        const MachinerySyncStatusPanel(),
        if (state.error != null)
          _MessageCard(icon: Icons.error_outline, text: state.error!),
        if (state.isLoading && asset == null)
          const Center(child: CircularProgressIndicator())
        else if (asset == null)
          const _MessageCard(
            icon: Icons.precision_manufacturing_outlined,
            text:
                'Нет назначенной техники. Обратитесь к ответственному за технику.',
          )
        else ...[
          _AssetHeader(asset: asset),
          const SizedBox(height: 12),
          if (blockedShift != null)
            const _MessageCard(
              icon: Icons.block_rounded,
              text:
                  'Предсменный осмотр запретил эксплуатацию. Передайте технику механику или диспетчеру.',
            )
          else if (shift == null)
            _StartShiftCard(asset: asset)
          else if (shift.meterEnd == null)
            _ActiveShiftCard(asset: asset, shift: shift)
          else
            _SubmitShiftCard(asset: asset, shift: shift),
        ],
      ],
    );
  }
}

class _StartShiftCard extends ConsumerStatefulWidget {
  const _StartShiftCard({required this.asset});
  final MachineryAssetModel asset;

  @override
  ConsumerState<_StartShiftCard> createState() => _StartShiftCardState();
}

class _StartShiftCardState extends ConsumerState<_StartShiftCard> {
  late final TextEditingController meter = TextEditingController(
    text: widget.asset.meterHours.toStringAsFixed(1),
  );
  final TextEditingController inspectionNotes = TextEditingController();
  String inspectionResult = 'serviceable';

  @override
  void dispose() {
    meter.dispose();
    inspectionNotes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assignmentId = widget.asset.assignmentId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Следующее действие',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('meter-start-field'),
              controller: meter,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Начальный счётчик',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: inspectionResult,
              decoration: const InputDecoration(
                labelText: 'Результат предсменного осмотра',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'serviceable', child: Text('Исправна')),
                DropdownMenuItem(
                  value: 'restricted',
                  child: Text('С ограничениями'),
                ),
                DropdownMenuItem(
                  value: 'unavailable',
                  child: Text('Эксплуатация запрещена'),
                ),
              ],
              onChanged:
                  (value) =>
                      setState(() => inspectionResult = value ?? 'serviceable'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: inspectionNotes,
              decoration: const InputDecoration(
                labelText: 'Комментарий к осмотру',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('start-shift-button'),
                onPressed:
                    assignmentId == null || widget.asset.projectId == null
                        ? null
                        : () => ref
                            .read(machineryOperationsProvider.notifier)
                            .execute(
                              StartShiftAction(
                                widget.asset.id,
                                assignmentId: assignmentId,
                                projectId: widget.asset.projectId!,
                                meterStart:
                                    double.tryParse(
                                      meter.text.replaceAll(',', '.'),
                                    ) ??
                                    0,
                                preShiftInspection: <String, dynamic>{
                                  'result': inspectionResult,
                                  if (inspectionNotes.text.trim().isNotEmpty)
                                    'notes': inspectionNotes.text.trim(),
                                  'defects': const <Map<String, dynamic>>[],
                                },
                              ),
                            ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Начать смену'),
              ),
            ),
            if (assignmentId == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Начало станет доступно после активного назначения.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveShiftCard extends ConsumerWidget {
  const _ActiveShiftCard({required this.asset, required this.shift});
  final MachineryAssetModel asset;
  final MachineryShiftReportModel shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Смена активна',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Начальный счётчик: ${shift.meterStart?.toStringAsFixed(1) ?? '—'}',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('finish-shift-button'),
                onPressed: () => _showFinishDialog(context, ref),
                child: const Text('Завершить смену'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _recordDowntime(ref),
                child: const Text('Зафиксировать простой'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordDowntime(WidgetRef ref) {
    return ref
        .read(machineryOperationsProvider.notifier)
        .execute(
          RecordDowntimeAction(
            asset.id,
            projectId: shift.projectId,
            shiftId: shift.id,
            reasonCode: 'other',
            startedAt: DateTime.now(),
            durationMinutes: 1,
            comment: 'Зафиксировано оператором',
          ),
        );
  }

  Future<void> _showFinishDialog(BuildContext context, WidgetRef ref) async {
    final meter = TextEditingController();
    final hours = TextEditingController(text: '8');
    final fuel = TextEditingController(text: '0');
    final inspectionNotes = TextEditingController();
    var inspectionResult = 'serviceable';
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Завершение смены'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: meter,
                          decoration: const InputDecoration(
                            labelText: 'Конечный счётчик',
                          ),
                        ),
                        TextField(
                          controller: hours,
                          decoration: const InputDecoration(
                            labelText: 'Фактические часы',
                          ),
                        ),
                        TextField(
                          controller: fuel,
                          decoration: const InputDecoration(
                            labelText: 'Расход топлива',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: inspectionResult,
                          decoration: const InputDecoration(
                            labelText: 'Результат послесменного осмотра',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'serviceable',
                              child: Text('Исправна'),
                            ),
                            DropdownMenuItem(
                              value: 'restricted',
                              child: Text('С ограничениями'),
                            ),
                            DropdownMenuItem(
                              value: 'unavailable',
                              child: Text('Эксплуатация запрещена'),
                            ),
                          ],
                          onChanged:
                              (value) => setDialogState(
                                () => inspectionResult = value ?? 'serviceable',
                              ),
                        ),
                        TextField(
                          controller: inspectionNotes,
                          decoration: const InputDecoration(
                            labelText: 'Комментарий к осмотру',
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Завершить'),
                    ),
                  ],
                ),
          ),
    );
    if (accepted == true) {
      await ref
          .read(machineryOperationsProvider.notifier)
          .execute(
            FinishShiftAction(
              asset.id,
              shiftId: shift.id,
              actualHours:
                  double.tryParse(hours.text.replaceAll(',', '.')) ?? 0,
              fuelConsumed:
                  double.tryParse(fuel.text.replaceAll(',', '.')) ?? 0,
              meterEnd: double.tryParse(meter.text.replaceAll(',', '.')) ?? 0,
              postShiftInspection: <String, dynamic>{
                'result': inspectionResult,
                if (inspectionNotes.text.trim().isNotEmpty)
                  'notes': inspectionNotes.text.trim(),
                'defects': const <Map<String, dynamic>>[],
              },
            ),
          );
    }
    meter.dispose();
    hours.dispose();
    fuel.dispose();
    inspectionNotes.dispose();
  }
}

class _SubmitShiftCard extends ConsumerWidget {
  const _SubmitShiftCard({required this.asset, required this.shift});
  final MachineryAssetModel asset;
  final MachineryShiftReportModel shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const Key('submit-shift-button'),
          onPressed:
              () => ref
                  .read(machineryOperationsProvider.notifier)
                  .execute(SubmitShiftAction(asset.id, shiftId: shift.id)),
          icon: const Icon(Icons.send_rounded),
          label: const Text('Передать рапорт на проверку'),
        ),
      ),
    ),
  );
}

class _AssetHeader extends StatelessWidget {
  const _AssetHeader({required this.asset});
  final MachineryAssetModel asset;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      minTileHeight: 72,
      leading: const Icon(Icons.precision_manufacturing_rounded),
      title: Text(asset.name),
      subtitle: Text(
        '${asset.assetCode} · ${asset.projectName ?? 'Объект не указан'}',
      ),
      trailing: Text(asset.statusLabel),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}

class _RoleScaffold extends StatelessWidget {
  const _RoleScaffold({
    required this.title,
    required this.onRefresh,
    required this.children,
  });
  final String title;
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: children,
      ),
    ),
  );
}
