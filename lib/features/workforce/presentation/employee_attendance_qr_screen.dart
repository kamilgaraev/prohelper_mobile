import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_action_buttons.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../../core/widgets/pro_card.dart';
import '../domain/workforce_attendance_provider.dart';

class EmployeeAttendanceQrScreen extends ConsumerStatefulWidget {
  const EmployeeAttendanceQrScreen({super.key, this.projectId, this.workDate});

  final int? projectId;
  final DateTime? workDate;

  @override
  ConsumerState<EmployeeAttendanceQrScreen> createState() =>
      _EmployeeAttendanceQrScreenState();
}

class _EmployeeAttendanceQrScreenState
    extends ConsumerState<EmployeeAttendanceQrScreen> {
  DateTime? _workDate;

  @override
  void initState() {
    super.initState();
    _workDate = widget.workDate;

    if (_workDate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refresh();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workforceAttendanceProvider);
    final qr = state.qr;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Подтверждение явки'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed: state.isLoading || _workDate == null ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body:
            state.isLoading && qr == null
                ? const AppLoadingState(message: 'Готовим QR-код')
                : state.error != null && qr == null
                ? AppErrorState(
                  title:
                      state.permissionDenied
                          ? 'Нет доступа к QR для явки'
                          : 'QR-код недоступен',
                  description: state.error!,
                  onRetry: _workDate == null ? null : _refresh,
                )
                : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    ProCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Показать QR для подтверждения явки',
                            style: AppTypography.h2(context),
                          ),
                          const SizedBox(height: 12),
                          _DateSelector(
                            selectedDate: _workDate,
                            onSelect: _selectDate,
                          ),
                          const SizedBox(height: 16),
                          AppPrimaryActionButton(
                            label: 'Получить QR',
                            onPressed:
                                state.isLoading || _workDate == null
                                    ? null
                                    : _refresh,
                            leading: const Icon(Icons.qr_code_2_rounded),
                            isBusy: state.isLoading,
                          ),
                          if (qr != null) ...[
                            const SizedBox(height: 20),
                            Text(qr.employeeLabel),
                            if ((qr.projectLabel ?? '').isNotEmpty)
                              Text(qr.projectLabel!),
                            const SizedBox(height: 16),
                            Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: QrImageView(
                                    data: qr.qrToken,
                                    version: QrVersions.auto,
                                    size: 240,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              qr.statusLabel,
                              style: AppTypography.bodyMedium(context),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Действует до ${_formatTime(qr.expiresAt)}',
                              style: AppTypography.caption(context),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (state.error != null && qr != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.error!,
                        style: AppTypography.bodyMedium(context),
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

  void _refresh() {
    final workDate = _workDate;

    if (workDate == null) {
      return;
    }

    ref
        .read(workforceAttendanceProvider.notifier)
        .issueQr(projectId: widget.projectId, workDate: workDate);
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({required this.selectedDate, required this.onSelect});

  final DateTime? selectedDate;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onSelect,
      icon: const Icon(Icons.calendar_today_rounded),
      label: Text(
        selectedDate == null
            ? 'Выберите дату явки'
            : 'Дата явки: ${_formatDate(selectedDate!)}',
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
