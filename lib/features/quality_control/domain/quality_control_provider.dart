import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/entity_snapshot_provider.dart';
import '../../../core/storage/snapshot_read.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../auth/domain/auth_provider.dart';
import '../data/quality_control_repository.dart';
import '../data/quality_control_snapshot_adapter.dart';
import '../data/quality_defect_model.dart';

class QualityControlState {
  const QualityControlState({
    this.isLoading = false,
    this.defects = const [],
    this.projectFilter,
    this.statusFilter,
    this.severityFilter,
    this.overdueOnly = false,
    this.permissionDenied = false,
    this.fromCache = false,
    this.hasDirtyLocal = false,
    this.error,
  });

  final bool isLoading;
  final List<QualityDefectModel> defects;
  final int? projectFilter;
  final String? statusFilter;
  final String? severityFilter;
  final bool overdueOnly;
  final bool permissionDenied;
  final bool fromCache;
  final bool hasDirtyLocal;
  final String? error;

  QualityControlState copyWith({
    bool? isLoading,
    List<QualityDefectModel>? defects,
    Object? projectFilter = _projectFilterSentinel,
    Object? statusFilter = _statusFilterSentinel,
    Object? severityFilter = _severityFilterSentinel,
    bool? overdueOnly,
    bool? permissionDenied,
    bool? fromCache,
    bool? hasDirtyLocal,
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
      permissionDenied: permissionDenied ?? this.permissionDenied,
      fromCache: fromCache ?? this.fromCache,
      hasDirtyLocal: hasDirtyLocal ?? this.hasDirtyLocal,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
    );
  }
}

const _errorSentinel = Object();
const _projectFilterSentinel = Object();
const _statusFilterSentinel = Object();
const _severityFilterSentinel = Object();

class QualityControlNotifier extends StateNotifier<QualityControlState> {
  QualityControlNotifier(
    this._repository, {
    QualityControlSnapshotAdapter? snapshotAdapter,
    bool Function()? isOnline,
  }) : _snapshotAdapter = snapshotAdapter,
       _isOnline = isOnline,
       super(const QualityControlState());

  final QualityControlRepository _repository;
  final QualityControlSnapshotAdapter? _snapshotAdapter;
  final bool Function()? _isOnline;

  bool get isLoading => state.isLoading;

  void syncProject(int? projectId) {
    if (state.projectFilter == projectId) {
      return;
    }

    state = state.copyWith(
      projectFilter: projectId,
      defects: const [],
      fromCache: false,
      hasDirtyLocal: false,
    );
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
    state = state.copyWith(
      isLoading: true,
      permissionDenied: false,
      error: null,
    );

    try {
      final snapshotAdapter = _snapshotAdapter;
      if (snapshotAdapter != null) {
        final read = await snapshotAdapter.load(
          online: _isOnline?.call() ?? false,
          projectId: state.projectFilter,
          status: state.statusFilter,
          severity: state.severityFilter,
          overdueOnly: state.overdueOnly,
        );
        final denied = read.presence == SnapshotPresence.permissionDenied;
        state = state.copyWith(
          isLoading: false,
          defects: denied ? const [] : (read.data ?? const []),
          permissionDenied: denied,
          fromCache: !denied && read.fromCache,
          hasDirtyLocal: !denied && read.hasDirtyLocal,
          error: read.error,
        );
        return;
      }
      final defects = await _repository.fetchDefects(
        projectId: state.projectFilter,
        status: state.statusFilter,
        severity: state.severityFilter,
        overdueOnly: state.overdueOnly,
      );
      state = state.copyWith(
        isLoading: false,
        defects: defects,
        fromCache: false,
        hasDirtyLocal: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        permissionDenied: _isPermissionDenied(error),
        fromCache: false,
        error: UserMessage.fromError(error),
      );
    }
  }

  Future<void> createDefect(
    Map<String, dynamic> data, {
    List<String> photoPaths = const [],
  }) async {
    await _repository.createDefect(data, photoPaths: photoPaths);
    await loadDefects();
  }

  Future<QualityDefectModel> fetchDefect(int id) {
    return _repository.fetchDefect(id);
  }

  Future<SnapshotRead<QualityDefectModel>> loadDefectSnapshot(int id) async {
    final adapter = _snapshotAdapter;
    if (adapter != null) {
      return adapter.loadDetail(
        online: _isOnline?.call() ?? false,
        defectId: id,
        projectId: state.projectFilter,
      );
    }
    try {
      return SnapshotRead(
        presence: SnapshotPresence.ready,
        data: await _repository.fetchDefect(id),
      );
    } catch (error) {
      return SnapshotRead(
        presence:
            error is ApiException && error.statusCode == 403
                ? SnapshotPresence.permissionDenied
                : SnapshotPresence.error,
        error: UserMessage.fromError(error),
      );
    }
  }

  Future<List<QualityAssigneeModel>> fetchAssignees(int defectId) =>
      _repository.fetchAssignees(defectId);

  Future<void> assignDefect(
    int id, {
    required int userId,
    String? comment,
  }) async {
    await _repository.assignDefect(id, userId: userId, comment: comment);
    await loadDefects();
  }

  Future<void> startDefect(int id, {String? comment}) async {
    await _repository.startDefect(id, comment: comment);
    await loadDefects();
  }

  Future<void> resolveDefect(
    int id, {
    String? comment,
    List<String> photoPaths = const [],
  }) async {
    await _repository.resolveDefect(
      id,
      comment: comment,
      photoPaths: photoPaths,
    );
    await loadDefects();
  }

  Future<void> verifyDefect(int id, {String? comment}) async {
    await _repository.verifyDefect(id, comment: comment);
    await loadDefects();
  }

  Future<void> rejectDefect(int id, {required String comment}) async {
    await _repository.rejectDefect(id, comment: comment);
    await loadDefects();
  }
}

bool _isPermissionDenied(Object error) {
  return error is ApiException && error.statusCode == 403;
}

final qualityControlSnapshotAdapterProvider =
    Provider<QualityControlSnapshotAdapter>((ref) {
      return QualityControlSnapshotAdapter(
        repository: ref.read(qualityControlRepositoryProvider),
        snapshots: ref.read(entitySnapshotServiceProvider.future),
        flushQueue: () async {
          await ref.read(syncQueueProvider.notifier).retryPending();
        },
      );
    });

final qualityControlProvider =
    StateNotifierProvider<QualityControlNotifier, QualityControlState>((ref) {
      final notifier = QualityControlNotifier(
        ref.read(qualityControlRepositoryProvider),
        snapshotAdapter: ref.read(qualityControlSnapshotAdapterProvider),
        isOnline: () {
          final auth = ref.read(authProvider);
          return auth is AuthAuthenticated && auth.isOnlineVerified;
        },
      );
      ref.listen<AuthState>(authProvider, (previous, next) {
        final wasOnline =
            previous is AuthAuthenticated && previous.isOnlineVerified;
        final isOnline = next is AuthAuthenticated && next.isOnlineVerified;
        if (!wasOnline && isOnline) {
          unawaited(notifier.loadDefects());
        }
      });
      ref.listen(syncQueueProvider, (previous, next) {
        if (next != null && !notifier.isLoading) {
          unawaited(notifier.loadDefects());
        }
      });
      return notifier;
    });
