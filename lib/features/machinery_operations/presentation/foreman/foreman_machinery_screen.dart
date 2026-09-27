import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/error/user_message.dart';
import '../../domain/machinery_operations_provider.dart';
import '../widgets/machinery_sync_status_panel.dart';

class ForemanMachineryScreen extends ConsumerWidget {
  const ForemanMachineryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineryOperationsProvider);
    final review =
        state.shiftReports
            .where((shift) => shift.status == 'submitted')
            .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Техника на объекте')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(machineryOperationsProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            const MachinerySyncStatusPanel(),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 8.0;
                    final columns = constraints.maxWidth < 400 ? 2 : 3;
                    final metricWidth =
                        (constraints.maxWidth - spacing * (columns - 1)) /
                        columns;
                    return Wrap(
                      alignment: WrapAlignment.spaceAround,
                      spacing: spacing,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: metricWidth,
                          child: _Metric(
                            label: 'Техника',
                            value: state.assets.length,
                          ),
                        ),
                        SizedBox(
                          width: metricWidth,
                          child: _Metric(
                            label: 'На проверку',
                            value: review.length,
                          ),
                        ),
                        SizedBox(
                          width: metricWidth,
                          child: _Metric(
                            label: 'Проблемы',
                            value:
                                state.assets
                                    .where(
                                      (asset) => asset.problemFlags.isNotEmpty,
                                    )
                                    .length,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Рапорты на проверку',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (review.isEmpty)
              const Card(child: ListTile(title: Text('Очередь проверки пуста')))
            else
              ...review.map((shift) {
                final canApprove = shift.availableActions.contains('approve');
                final canReject = shift.availableActions.contains('reject');
                final canAct = canApprove || canReject;

                return Card(
                  child: ListTile(
                    minTileHeight: 64,
                    leading: const Icon(Icons.fact_check_outlined),
                    title: Text(shift.assetName ?? 'Техника №${shift.assetId}'),
                    subtitle: Text(
                      '${shift.reportDate} · ${shift.actualHours} ч · ${shift.fuelConsumed} л',
                    ),
                    trailing:
                        canAct ? const Icon(Icons.chevron_right_rounded) : null,
                    onTap:
                        canAct
                            ? () => _reviewShiftReport(
                              context,
                              ref,
                              shift.id,
                              canApprove: canApprove,
                              canReject: canReject,
                            )
                            : null,
                  ),
                );
              }),
            const SizedBox(height: 16),
            Text('Парк объекта', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (state.assets.isEmpty && !state.isLoading)
              const Card(child: ListTile(title: Text('Техника не назначена')))
            else
              ...state.assets.map(
                (asset) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Chip(
                          label: Text(asset.statusLabel),
                          visualDensity: VisualDensity.compact,
                        ),
                        ListTile(
                          minTileHeight: 64,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.precision_manufacturing_outlined,
                          ),
                          title: Text(asset.name),
                          subtitle: Text(asset.projectName ?? asset.assetCode),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _reviewShiftReport(
  BuildContext context,
  WidgetRef ref,
  int shiftReportId, {
  required bool canApprove,
  required bool canReject,
}) async {
  final decision = await showDialog<_ShiftReviewDecision>(
    context: context,
    builder:
        (_) => _ShiftReviewDialog(canApprove: canApprove, canReject: canReject),
  );
  if (decision == null || !context.mounted) return;

  try {
    final notifier = ref.read(machineryOperationsProvider.notifier);
    if (decision.approve) {
      await notifier.approveShiftReport(shiftReportId);
    } else {
      await notifier.rejectShiftReport(shiftReportId, decision.reason!);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          decision.approve ? 'Рапорт подтвержден' : 'Рапорт отклонен',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    final errorMessage = UserMessage.fromError(error);
    final refreshGuidance =
        errorMessage.contains('Обновите очередь проверки')
            ? ''
            : ' Обновите очередь проверки перед повтором.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$errorMessage$refreshGuidance Если рапорт остается на проверке, повторите действие.',
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }
}

class _ShiftReviewDecision {
  const _ShiftReviewDecision.approve() : approve = true, reason = null;
  const _ShiftReviewDecision.reject(this.reason) : approve = false;

  final bool approve;
  final String? reason;
}

class _ShiftReviewDialog extends StatefulWidget {
  const _ShiftReviewDialog({required this.canApprove, required this.canReject});

  final bool canApprove;
  final bool canReject;

  @override
  State<_ShiftReviewDialog> createState() => _ShiftReviewDialogState();
}

class _ShiftReviewDialogState extends State<_ShiftReviewDialog> {
  final _reasonController = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Проверка сменного рапорта'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.canApprove && widget.canReject
                ? 'Подтвердить рапорт или отклонить с указанием причины.'
                : widget.canApprove
                ? 'Подтвердить этот сменный рапорт.'
                : 'Отклонить рапорт с указанием причины.',
          ),
          if (widget.canReject) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Причина отклонения',
                errorText: _validationError,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        if (widget.canReject)
          TextButton(
            onPressed: () {
              final reason = _reasonController.text.trim();
              if (reason.isEmpty) {
                setState(() => _validationError = 'Укажите причину');
                return;
              }
              Navigator.of(context).pop(_ShiftReviewDecision.reject(reason));
            },
            child: const Text('Отклонить'),
          ),
        if (widget.canApprove)
          FilledButton(
            onPressed:
                () => Navigator.of(
                  context,
                ).pop(const _ShiftReviewDecision.approve()),
            child: const Text('Подтвердить'),
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('$value', style: Theme.of(context).textTheme.headlineSmall),
      Text(label, textAlign: TextAlign.center),
    ],
  );
}
