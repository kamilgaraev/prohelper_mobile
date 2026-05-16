import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/workforce_attendance_model.dart';
import '../data/workforce_repository.dart';

const _errorSentinel = Object();

class WorkforceAttendanceState {
  const WorkforceAttendanceState({
    this.isLoading = false,
    this.qr,
    this.scanResult,
    this.error,
  });

  final bool isLoading;
  final AttendanceQrModel? qr;
  final AttendanceScanResultModel? scanResult;
  final String? error;

  WorkforceAttendanceState copyWith({
    bool? isLoading,
    AttendanceQrModel? qr,
    AttendanceScanResultModel? scanResult,
    Object? error = _errorSentinel,
  }) {
    return WorkforceAttendanceState(
      isLoading: isLoading ?? this.isLoading,
      qr: qr ?? this.qr,
      scanResult: scanResult ?? this.scanResult,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
    );
  }
}

class WorkforceAttendanceNotifier
    extends StateNotifier<WorkforceAttendanceState> {
  WorkforceAttendanceNotifier(this._repository)
    : super(const WorkforceAttendanceState());

  final WorkforceRepository _repository;

  Future<void> issueQr({int? projectId, DateTime? workDate}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final qr = await _repository.issueAttendanceQr(
        projectId: projectId,
        workDate: workDate,
      );
      state = state.copyWith(isLoading: false, qr: qr);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> scanQr(String qrToken) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _repository.scanAttendanceQr(qrToken: qrToken);
      state = state.copyWith(isLoading: false, scanResult: result);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  void clearScanResult() {
    state = const WorkforceAttendanceState();
  }
}

final workforceAttendanceProvider = StateNotifierProvider<
  WorkforceAttendanceNotifier,
  WorkforceAttendanceState
>((ref) {
  return WorkforceAttendanceNotifier(ref.read(workforceRepositoryProvider));
});
