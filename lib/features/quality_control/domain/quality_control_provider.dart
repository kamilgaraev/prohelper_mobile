import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/quality_control_repository.dart';
import '../data/quality_defect_model.dart';

class QualityControlState {
  const QualityControlState({
    this.isLoading = false,
    this.defects = const [],
    this.projectFilter,
    this.statusFilter,
    this.severityFilter,
    this.overdueOnly = false,
    this.error,
  });

  final bool isLoading;
  final List<QualityDefectModel> defects;
  final int? projectFilter;
  final String? statusFilter;
  final String? severityFilter;
  final bool overdueOnly;
  final String? error;

  QualityControlState copyWith({
    bool? isLoading,
    List<QualityDefectModel>? defects,
    Object? projectFilter = _projectFilterSentinel,
    Object? statusFilter = _statusFilterSentinel,
    Object? severityFilter = _severityFilterSentinel,
    bool? overdueOnly,
    Object? error = _errorSentinel,
  }) {
    return QualityControlState(
      isLoading: isLoading ?? this.isLoading,
      defects: defects ?? this.defects,
      projectFilter:
          identical(projectFilter, _projectFilterSentinel)
              ? this.projectFilter
              : projectFilter as int?,
      statusFilter:
          identical(statusFilter, _statusFilterSentinel)
              ? this.statusFilter
              : statusFilter as String?,
      severityFilter:
          identical(severityFilter, _severityFilterSentinel)
              ? this.severityFilter
              : severityFilter as String?,
      overdueOnly: overdueOnly ?? this.overdueOnly,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
    );
  }
}

const _errorSentinel = Object();
const _projectFilterSentinel = Object();
const _statusFilterSentinel = Object();
const _severityFilterSentinel = Object();

class QualityControlNotifier extends StateNotifier<QualityControlState> {
  QualityControlNotifier(this._repository) : super(const QualityControlState());

  final QualityControlRepository _repository;

  void syncProject(int? projectId) {
    if (state.projectFilter == projectId) {
      return;
    }

    state = state.copyWith(projectFilter: projectId);
  }

  void setStatusFilter(String? status) {
    if (state.statusFilter == status) {
      return;
    }

    state = state.copyWith(statusFilter: status, defects: const []);
  }

  void setSeverityFilter(String? severity) {
    if (state.severityFilter == severity) {
      return;
    }

    state = state.copyWith(severityFilter: severity, defects: const []);
  }

  void setOverdueOnly(bool value) {
    if (state.overdueOnly == value) {
      return;
    }

    state = state.copyWith(overdueOnly: value, defects: const []);
  }

  Future<void> loadDefects() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final defects = await _repository.fetchDefects(
        projectId: state.projectFilter,
        status: state.statusFilter,
        severity: state.severityFilter,
        overdueOnly: state.overdueOnly,
      );
      state = state.copyWith(isLoading: false, defects: defects);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> createDefect(Map<String, dynamic> data) async {
    await _repository.createDefect(data);
    await loadDefects();
  }

  Future<void> startDefect(int id, {String? comment}) async {
    await _repository.startDefect(id, comment: comment);
    await loadDefects();
  }

  Future<void> resolveDefect(
    int id, {
    String? comment,
    String? photoUrl,
  }) async {
    await _repository.resolveDefect(id, comment: comment, photoUrl: photoUrl);
    await loadDefects();
  }
}

final qualityControlProvider =
    StateNotifierProvider<QualityControlNotifier, QualityControlState>((ref) {
      return QualityControlNotifier(ref.read(qualityControlRepositoryProvider));
    });
