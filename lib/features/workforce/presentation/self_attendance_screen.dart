import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_action_buttons.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../../core/widgets/pro_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/workforce_attendance_model.dart';
import '../domain/workforce_attendance_provider.dart';

class SelfAttendanceScreen extends ConsumerStatefulWidget {
  const SelfAttendanceScreen({super.key});

  @override
  ConsumerState<SelfAttendanceScreen> createState() =>
      _SelfAttendanceScreenState();
}

class _SelfAttendanceScreenState extends ConsumerState<SelfAttendanceScreen> {
  DateTime? _workDate;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workforceAttendanceProvider);
    final project = ref.watch(projectsProvider).selectedProject;
    final result = state.selfAttendanceResult;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Самоотметка явки'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            ProCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Отметить явку', style: AppTypography.h2(context)),
                  const SizedBox(height: 10),
                  Text(
                    project == null
                        ? 'Объект не выбран. Явка будет сохранена без привязки к объекту.'
                        : 'Объект: ${project.name}',
                    style: AppTypography.bodyMedium(context),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_today_rounded),
                    label: Text(
                      _workDate == null
                          ? 'Выберите дату явки'
                          : 'Дата явки: ${_formatDate(_workDate!)}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppPrimaryActionButton(
                    label: 'Отметить явку',
                    onPressed:
                        state.isLoading || _workDate == null
                            ? null
                            : () => _submit(project?.serverId),
                    leading: const Icon(Icons.how_to_reg_rounded),
                    isBusy: state.isLoading,
                  ),
                ],
              ),
            ),
            if (result != null) ...[
              const SizedBox(height: 12),
              _AttendanceResultCard(result: result),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 12),
              AppErrorState(
                title:
                    state.duplicateAttendance
                        ? 'Явка уже отмечена'
                        : state.permissionDenied
                        ? 'Нет доступа к самоотметке'
                        : 'Явка не сохранена',
                description: state.error!,
                minHeight: 180,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _workDate ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _workDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _submit(int? projectId) async {
    final workDate = _workDate;

    if (workDate == null) {
      return;
    }

    await ref
        .read(workforceAttendanceProvider.notifier)
        .recordSelfAttendance(projectId: projectId, workDate: workDate);
  }
}

class _AttendanceResultCard extends StatelessWidget {
  const _AttendanceResultCard({required this.result});

  final AttendanceScanResultModel result;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.statusLabel,
                  style: AppTypography.h2(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Line(label: 'Сотрудник', value: result.employeeLabel),
          if ((result.projectLabel ?? '').isNotEmpty)
            _Line(label: 'Объект', value: result.projectLabel!),
          _Line(label: 'Дата', value: _formatDate(result.workDate)),
          _Line(label: 'Время', value: _formatTime(result.confirmedAt)),
          _Line(label: 'Источник', value: result.sourceLabel),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: AppTypography.bodyMedium(
                context,
              ).copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: AppTypography.bodyLarge(context))),
        ],
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
