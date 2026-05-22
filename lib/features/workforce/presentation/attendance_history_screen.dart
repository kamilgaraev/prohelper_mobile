import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_action_buttons.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../../core/widgets/pro_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/workforce_attendance_model.dart';
import '../domain/workforce_attendance_provider.dart';

class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState
    extends ConsumerState<AttendanceHistoryScreen> {
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _requested = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workforceAttendanceProvider);
    final project = ref.watch(projectsProvider).selectedProject;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('История явки'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            ProCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Период истории', style: AppTypography.h2(context)),
                  const SizedBox(height: 10),
                  Text(
                    project == null
                        ? 'Объект не выбран. Будут загружены записи без фильтра по объекту.'
                        : 'Объект: ${project.name}',
                    style: AppTypography.bodyMedium(context),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _selectDate(isStart: true),
                        icon: const Icon(Icons.calendar_today_rounded),
                        label: Text(
                          _dateFrom == null
                              ? 'Начало периода'
                              : 'С ${_formatDate(_dateFrom!)}',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _selectDate(isStart: false),
                        icon: const Icon(Icons.event_available_rounded),
                        label: Text(
                          _dateTo == null
                              ? 'Конец периода'
                              : 'По ${_formatDate(_dateTo!)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppPrimaryActionButton(
                    label: 'Загрузить историю',
                    onPressed:
                        state.isLoading || _dateFrom == null || _dateTo == null
                            ? null
                            : () => _load(project?.serverId),
                    leading: const Icon(Icons.history_rounded),
                    isBusy: state.isLoading,
                  ),
                ],
              ),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 12),
              AppErrorState(
                title:
                    state.permissionDenied
                        ? 'Нет доступа к истории'
                        : 'История не загружена',
                description: state.error!,
                minHeight: 180,
              ),
            ] else if (state.isLoading && state.history.isEmpty) ...[
              const SizedBox(height: 12),
              const AppLoadingState(message: 'Загружаем историю явки'),
            ] else if (_requested && state.history.isEmpty) ...[
              const SizedBox(height: 12),
              const _EmptyHistoryCard(),
            ] else ...[
              const SizedBox(height: 12),
              ...state.history.map(_HistoryCard.new),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate({required bool isStart}) async {
    final now = DateTime.now();
    final current = isStart ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      final date = DateTime(picked.year, picked.month, picked.day);
      if (isStart) {
        _dateFrom = date;
      } else {
        _dateTo = date;
      }
    });
  }

  Future<void> _load(int? projectId) async {
    final dateFrom = _dateFrom;
    final dateTo = _dateTo;

    if (dateFrom == null || dateTo == null) {
      return;
    }

    setState(() {
      _requested = true;
    });

    await ref
        .read(workforceAttendanceProvider.notifier)
        .loadHistory(dateFrom: dateFrom, dateTo: dateTo, projectId: projectId);
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard(this.item);

  final AttendanceHistoryItemModel item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ProCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.statusLabel, style: AppTypography.bodyLarge(context)),
            const SizedBox(height: 8),
            Text(item.employeeLabel, style: AppTypography.bodyMedium(context)),
            if ((item.projectLabel ?? '').isNotEmpty)
              Text(
                item.projectLabel!,
                style: AppTypography.bodyMedium(context),
              ),
            const SizedBox(height: 8),
            Text(
              '${_formatDate(item.workDate)} ${_formatTime(item.confirmedAt)} · ${item.sourceLabel}',
              style: AppTypography.caption(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Text(
        'За выбранный период записей явки нет.',
        style: AppTypography.bodyMedium(context),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');

  return '$day.$month.${value.year}';
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');

  return '$hour:$minute';
}
