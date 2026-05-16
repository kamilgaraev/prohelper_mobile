import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
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
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
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
              onPressed: state.isLoading ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body:
            state.isLoading && qr == null
                ? const Center(child: CircularProgressIndicator())
                : state.error != null && qr == null
                ? AppStateView(
                  icon: Icons.qr_code_2_rounded,
                  title: 'QR-код недоступен',
                  description: state.error,
                  action: OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Повторить'),
                  ),
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
                          const SizedBox(height: 8),
                          if (qr != null) ...[
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
                    if (state.error != null) ...[
                      const SizedBox(height: 12),
                      Text(state.error!, style: AppTypography.bodyMedium(context)),
                    ],
                  ],
                ),
      ),
    );
  }

  void _refresh() {
    ref
        .read(workforceAttendanceProvider.notifier)
        .issueQr(projectId: widget.projectId, workDate: widget.workDate);
  }
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');

  return '$hour:$minute';
}
