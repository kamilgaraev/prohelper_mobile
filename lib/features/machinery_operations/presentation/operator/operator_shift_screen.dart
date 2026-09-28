import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/error/user_message.dart';
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
              isExpanded: true,
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
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (_) => _FinishShiftDialog(
            assetId: asset.id,
            shiftId: shift.id,
            onSubmit:
                (action) => ref
                    .read(machineryOperationsProvider.notifier)
                    .execute(action),
          ),
    );
    if (accepted == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Смена завершена')));
    }
  }
}

class _FinishShiftDialog extends StatefulWidget {
  const _FinishShiftDialog({
    required this.assetId,
    required this.shiftId,
    required this.onSubmit,
  });

  final int assetId;
  final int shiftId;
  final Future<void> Function(FinishShiftAction action) onSubmit;

  @override
  State<_FinishShiftDialog> createState() => _FinishShiftDialogState();
}

class _FinishShiftDialogState extends State<_FinishShiftDialog> {
  final _meter = TextEditingController();
  final _hours = TextEditingController(text: '8');
  final _fuel = TextEditingController(text: '0');
  final _inspectionNotes = TextEditingController();
  String _inspectionResult = 'serviceable';
  String? _submitError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _meter.dispose();
    _hours.dispose();
    _fuel.dispose();
    _inspectionNotes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      await widget.onSubmit(
        FinishShiftAction(
          widget.assetId,
          shiftId: widget.shiftId,
          actualHours: double.tryParse(_hours.text.replaceAll(',', '.')) ?? 0,
          fuelConsumed: double.tryParse(_fuel.text.replaceAll(',', '.')) ?? 0,
          meterEnd: double.tryParse(_meter.text.replaceAll(',', '.')) ?? 0,
          postShiftInspection: <String, dynamic>{
            'result': _inspectionResult,
            if (_inspectionNotes.text.trim().isNotEmpty)
              'notes': _inspectionNotes.text.trim(),
            'defects': const <Map<String, dynamic>>[],
          },
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = UserMessage.fromError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Завершение смены'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('finish-meter-field'),
              controller: _meter,
              enabled: !_isSubmitting,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Конечный счётчик'),
            ),
            TextField(
              key: const Key('finish-hours-field'),
              controller: _hours,
              enabled: !_isSubmitting,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Фактические часы'),
            ),
            TextField(
              key: const Key('finish-fuel-field'),
              controller: _fuel,
              enabled: !_isSubmitting,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Расход топлива'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _inspectionResult,
              selectedItemBuilder:
                  (context) =>
                      const [
                            'Исправна',
                            'С ограничениями',
                            'Эксплуатация запрещена',
                          ]
                          .map(
                            (label) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
              decoration: const InputDecoration(
                labelText: 'Результат послесменного осмотра',
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
                  _isSubmitting
                      ? null
                      : (value) => setState(
                        () => _inspectionResult = value ?? 'serviceable',
                      ),
            ),
            TextField(
              key: const Key('finish-inspection-notes-field'),
              controller: _inspectionNotes,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Комментарий к осмотру',
              ),
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 12),
              Text(
                _submitError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const Key('finish-dialog-submit'),
            onPressed: _isSubmitting ? null : _submit,
            child:
                _isSubmitting
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Завершить'),
          ),
        ],
      ),
    );
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
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width - 48,
              ),
              child: Text(
                asset.statusLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.precision_manufacturing_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset.name),
                    Text(
                      '${asset.assetCode} · ${asset.projectName ?? 'Объект не указан'}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
