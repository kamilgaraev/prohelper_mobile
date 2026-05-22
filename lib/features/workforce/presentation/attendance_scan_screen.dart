import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_action_buttons.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../../core/widgets/pro_card.dart';
import '../../warehouse/presentation/warehouse_camera_scanner_screen.dart';
import '../data/workforce_attendance_model.dart';
import '../domain/workforce_attendance_provider.dart';

class AttendanceScanScreen extends ConsumerStatefulWidget {
  const AttendanceScanScreen({super.key, this.initialQrToken});

  final String? initialQrToken;

  @override
  ConsumerState<AttendanceScanScreen> createState() =>
      _AttendanceScanScreenState();
}

class _AttendanceScanScreenState extends ConsumerState<AttendanceScanScreen> {
  late final TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.initialQrToken ?? '');
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workforceAttendanceProvider);
    final result = state.scanResult;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Подтверждение явки'),
        ),
        body:
            result != null
                ? _ScanResult(result: result, onScanNext: _reset)
                : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    ProCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Сканировать QR сотрудника',
                            style: AppTypography.h2(context),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Наведите камеру на QR-код сотрудника и подтвердите явку на объекте.',
                            style: AppTypography.bodyMedium(context),
                          ),
                          const SizedBox(height: 16),
                          AppPrimaryActionButton(
                            label: 'Сканировать QR',
                            onPressed:
                                state.isLoading ? null : _openCameraScanner,
                            leading: const Icon(Icons.qr_code_scanner_rounded),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _tokenController,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _scanEnteredToken(),
                            decoration: InputDecoration(
                              labelText: 'Код для ручного подтверждения',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                onPressed:
                                    state.isLoading ? null : _scanEnteredToken,
                                icon: const Icon(Icons.check_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppSecondaryActionButton(
                            label: 'Подтвердить явку',
                            onPressed:
                                state.isLoading ? null : _scanEnteredToken,
                            leading: const Icon(Icons.verified_user_rounded),
                            isBusy: state.isLoading,
                          ),
                        ],
                      ),
                    ),
                    if (state.error != null) ...[
                      const SizedBox(height: 12),
                      AppErrorState(
                        title:
                            state.duplicateScan
                                ? 'QR уже использован'
                                : state.permissionDenied
                                ? 'Нет доступа к подтверждению'
                                : 'Явка не подтверждена',
                        description: state.error!,
                        minHeight: 180,
                      ),
                    ],
                  ],
                ),
      ),
    );
  }

  Future<void> _openCameraScanner() async {
    final scannedToken = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const WarehouseCameraScannerScreen()),
    );

    if (!mounted || scannedToken == null || scannedToken.trim().isEmpty) {
      return;
    }

    _tokenController.text = scannedToken.trim();
    await _scan(scannedToken.trim());
  }

  Future<void> _scanEnteredToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала отсканируйте QR-код сотрудника.'),
        ),
      );
      return;
    }

    await _scan(token);
  }

  Future<void> _scan(String token) async {
    await ref.read(workforceAttendanceProvider.notifier).scanQr(token);
  }

  void _reset() {
    _tokenController.clear();
    ref.read(workforceAttendanceProvider.notifier).clearScanResult();
  }
}

class _ScanResult extends StatelessWidget {
  const _ScanResult({required this.result, required this.onScanNext});

  final AttendanceScanResultModel result;
  final VoidCallback onScanNext;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        ProCard(
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
              const SizedBox(height: 16),
              _ResultLine(label: 'Сотрудник', value: result.employeeLabel),
              if ((result.projectLabel ?? '').isNotEmpty)
                _ResultLine(label: 'Объект', value: result.projectLabel!),
              _ResultLine(label: 'Дата', value: _formatDate(result.workDate)),
              _ResultLine(
                label: 'Время',
                value: _formatTime(result.confirmedAt),
              ),
              _ResultLine(label: 'Источник', value: result.sourceLabel),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onScanNext,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Сканировать следующий QR'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
