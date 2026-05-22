import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/workforce_attendance_model.dart';
import '../data/workforce_repository.dart';

const _qrSentinel = Object();
const _scanResultSentinel = Object();
const _selfResultSentinel = Object();
const _errorSentinel = Object();

class WorkforceAttendanceState {
  const WorkforceAttendanceState({
    this.isLoading = false,
    this.qr,
    this.scanResult,
    this.selfAttendanceResult,
    this.history = const [],
    this.error,
    this.permissionDenied = false,
    this.duplicateScan = false,
    this.duplicateAttendance = false,
    this.malformedContract = false,
  });

  final bool isLoading;
  final AttendanceQrModel? qr;
  final AttendanceScanResultModel? scanResult;
  final AttendanceScanResultModel? selfAttendanceResult;
  final List<AttendanceHistoryItemModel> history;
  final String? error;
  final bool permissionDenied;
  final bool duplicateScan;
  final bool duplicateAttendance;
  final bool malformedContract;

  WorkforceAttendanceState copyWith({
    bool? isLoading,
    Object? qr = _qrSentinel,
    Object? scanResult = _scanResultSentinel,
    Object? selfAttendanceResult = _selfResultSentinel,
    List<AttendanceHistoryItemModel>? history,
    Object? error = _errorSentinel,
    bool? permissionDenied,
    bool? duplicateScan,
    bool? duplicateAttendance,
    bool? malformedContract,
  }) {
    return WorkforceAttendanceState(
      isLoading: isLoading ?? this.isLoading,
      qr: identical(qr, _qrSentinel) ? this.qr : qr as AttendanceQrModel?,
      scanResult:
          identical(scanResult, _scanResultSentinel)
              ? this.scanResult
              : scanResult as AttendanceScanResultModel?,
      selfAttendanceResult:
          identical(selfAttendanceResult, _selfResultSentinel)
              ? this.selfAttendanceResult
              : selfAttendanceResult as AttendanceScanResultModel?,
      history: history ?? this.history,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      duplicateScan: duplicateScan ?? this.duplicateScan,
      duplicateAttendance: duplicateAttendance ?? this.duplicateAttendance,
      malformedContract: malformedContract ?? this.malformedContract,
    );
  }
}

class WorkforceAttendanceNotifier
    extends StateNotifier<WorkforceAttendanceState> {
  WorkforceAttendanceNotifier(this._repository)
    : super(const WorkforceAttendanceState());

  final WorkforceRepository _repository;

  Future<void> issueQr({int? projectId, required DateTime workDate}) async {
    _startRequest();

    try {
      final qr = await _repository.issueAttendanceQr(
        projectId: projectId,
        workDate: workDate,
      );
      state = state.copyWith(isLoading: false, qr: qr);
    } catch (error) {
      _finishWithError(error);
    }
  }

  Future<void> scanQr(String qrToken) async {
    _startRequest(scanResult: null);

    try {
      final result = await _repository.scanAttendanceQr(qrToken: qrToken);
      state = state.copyWith(isLoading: false, scanResult: result);
    } catch (error) {
      _finishWithError(error);
    }
  }

  Future<void> recordSelfAttendance({
    int? projectId,
    required DateTime workDate,
  }) async {
    _startRequest(selfAttendanceResult: null);

    try {
      final result = await _repository.recordSelfAttendance(
        projectId: projectId,
        workDate: workDate,
      );
      state = state.copyWith(isLoading: false, selfAttendanceResult: result);
    } catch (error) {
      _finishWithError(error);
    }
  }

  Future<void> loadHistory({
    required DateTime dateFrom,
    required DateTime dateTo,
    int? projectId,
  }) async {
    _startRequest();

    try {
      final history = await _repository.fetchAttendanceHistory(
        dateFrom: dateFrom,
        dateTo: dateTo,
        projectId: projectId,
      );
      state = state.copyWith(isLoading: false, history: history.items);
    } catch (error) {
      _finishWithError(error, clearHistoryOnMalformedContract: true);
    }
  }

  void clearScanResult() {
    state = state.copyWith(
      scanResult: null,
      error: null,
      duplicateScan: false,
      malformedContract: false,
    );
  }

  void clearSelfAttendanceResult() {
    state = state.copyWith(
      selfAttendanceResult: null,
      error: null,
      duplicateAttendance: false,
      malformedContract: false,
    );
  }

  void _startRequest({
    Object? scanResult = _scanResultSentinel,
    Object? selfAttendanceResult = _selfResultSentinel,
  }) {
    state = state.copyWith(
      isLoading: true,
      scanResult: scanResult,
      selfAttendanceResult: selfAttendanceResult,
      error: null,
      permissionDenied: false,
      duplicateScan: false,
      duplicateAttendance: false,
      malformedContract: false,
    );
  }

  void _finishWithError(
    Object error, {
    bool clearHistoryOnMalformedContract = false,
  }) {
    final malformedContract = error is FormatException;

    state = state.copyWith(
      isLoading: false,
      history:
          malformedContract && clearHistoryOnMalformedContract
              ? const []
              : null,
      error: _messageFor(error),
      permissionDenied: error is ApiException && error.statusCode == 403,
      duplicateScan: error is WorkforceDuplicateScanException,
      duplicateAttendance: error is WorkforceDuplicateAttendanceException,
      malformedContract: malformedContract,
    );
  }

  String _messageFor(Object error) {
    if (error is FormatException) {
      return 'Данные по явке отличаются от ожидаемого формата. Обратитесь к администратору.';
    }

    if (error is ApiException) {
      return error.message;
    }

    return 'Не удалось выполнить действие с явкой. Попробуйте позже.';
  }
}

final workforceAttendanceProvider = StateNotifierProvider<
  WorkforceAttendanceNotifier,
  WorkforceAttendanceState
>((ref) {
  return WorkforceAttendanceNotifier(ref.read(workforceRepositoryProvider));
});
