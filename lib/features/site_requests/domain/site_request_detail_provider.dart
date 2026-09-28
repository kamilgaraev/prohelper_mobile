import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/entity_snapshot_store.dart';
import '../../../core/storage/snapshot_read.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/site_request_model.dart';
import '../data/site_requests_repository.dart';
import '../data/site_requests_snapshot_adapter.dart';
import 'site_requests_provider.dart';

const _siteRequestDetailSentinel = Object();

class SiteRequestDetailState {
  final bool isLoading;
  final bool isActionLoading;
  final SiteRequestModel? request;
  final bool permissionDenied;
  final bool fromCache;
  final bool hasDirtyLocal;
  final String? error;

  SiteRequestDetailState({
    this.isLoading = false,
    this.isActionLoading = false,
    this.request,
    this.permissionDenied = false,
    this.fromCache = false,
    this.hasDirtyLocal = false,
    this.error,
  });

  SiteRequestDetailState copyWith({
    bool? isLoading,
    bool? isActionLoading,
    Object? request = _siteRequestDetailSentinel,
    bool? permissionDenied,
    bool? fromCache,
    bool? hasDirtyLocal,
    Object? error = _siteRequestDetailSentinel,
  }) {
    return SiteRequestDetailState(
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      request:
          identical(request, _siteRequestDetailSentinel)
              ? this.request
              : request as SiteRequestModel?,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      fromCache: fromCache ?? this.fromCache,
      hasDirtyLocal: hasDirtyLocal ?? this.hasDirtyLocal,
      error:
          identical(error, _siteRequestDetailSentinel)
              ? this.error
              : error as String?,
    );
  }
}

final siteRequestDetailProvider = StateNotifierProvider.family<
  SiteRequestDetailNotifier,
  SiteRequestDetailState,
  int
>((ref, id) {
  return SiteRequestDetailNotifier(
    ref.read(siteRequestsRepositoryProvider),
    ref,
    id,
    snapshotAdapter: ref.read(siteRequestsSnapshotAdapterProvider),
    projectId: ref.read(projectsProvider).selectedProject?.serverId,
  );
});

class SiteRequestDetailNotifier extends StateNotifier<SiteRequestDetailState> {
  SiteRequestDetailNotifier(
    this._repository,
    this._ref,
    this._id, {
    SiteRequestsSnapshotAdapter? snapshotAdapter,
    int? projectId,
  }) : _snapshotAdapter = snapshotAdapter,
       _projectId = projectId,
       super(SiteRequestDetailState()) {
    loadDetails();
  }

  final SiteRequestsRepository _repository;
  final Ref _ref;
  final int _id;
  final SiteRequestsSnapshotAdapter? _snapshotAdapter;
  final int? _projectId;

  Future<void> loadDetails() async {
    state = state.copyWith(
      isLoading: true,
      permissionDenied: false,
      error: null,
    );
    try {
      final adapter = _snapshotAdapter;
      if (adapter == null) {
        final request = await _repository.fetchSiteRequestDetails(_id);
        state = state.copyWith(
          isLoading: false,
          request: request,
          fromCache: false,
          hasDirtyLocal: false,
        );
        return;
      }
      final read = await adapter.loadDetail(
        online: true,
        requestId: _id,
        projectId: _projectId,
      );
      final denied = read.presence == SnapshotPresence.permissionDenied;
      state = state.copyWith(
        isLoading: false,
        request: denied ? null : read.data,
        permissionDenied: denied,
        fromCache: read.fromCache,
        hasDirtyLocal: read.hasDirtyLocal,
        error: read.error,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        permissionDenied: _isPermissionDenied(error),
        error: _errorMessage(error),
      );
    }
  }

  Future<void> submit() async {
    await _performAction(() => _repository.submitSiteRequestPayload(_id));
  }

  Future<void> cancel({String? notes}) async {
    await _performAction(
      () => _repository.cancelSiteRequestPayload(_id, notes: notes),
    );
  }

  Future<void> complete({String? notes}) async {
    await _performAction(
      () => _repository.completeSiteRequestPayload(_id, notes: notes),
    );
  }

  Future<void> changeStatus(String status, {String? notes}) async {
    await _performAction(
      () =>
          _repository.changeSiteRequestStatusPayload(_id, status, notes: notes),
    );
  }

  Future<void> _performAction(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    if (!mounted) return;
    final adapter = _snapshotAdapter;
    final requestsNotifier = _ref.read(siteRequestsProvider.notifier);
    EntitySnapshotOwner? expectedOwner;
    if (adapter != null) {
      try {
        expectedOwner = await adapter.currentOwner();
      } catch (_) {}
    }
    if (!mounted) return;
    state = state.copyWith(
      isActionLoading: true,
      permissionDenied: false,
      error: null,
    );
    try {
      final payload = await action();
      final updatedRequest = SiteRequestModel.fromJson(payload);
      var snapshotSaveFailed = false;

      if (adapter != null) {
        try {
          await adapter.saveAcknowledgedDetail(
            payload: payload,
            requestId: _id,
            projectId: _projectId,
            expectedOwner: expectedOwner,
          );
        } catch (_) {
          if (await adapter.isCurrentOwner(expectedOwner) &&
              expectedOwner != null) {
            snapshotSaveFailed = true;
            try {
              await adapter.invalidateCleanDetail(
                requestId: _id,
                projectId: _projectId,
                payload: payload,
                expectedOwner: expectedOwner,
              );
            } catch (_) {}
          }
        }
        try {
          await adapter.updateExistingListAliasesFromAcknowledgedDetail(
            payload: payload,
            requestId: _id,
            projectId: _projectId,
            expectedOwner: expectedOwner,
          );
        } catch (_) {
          snapshotSaveFailed = true;
        }
      }

      if (!mounted) return;
      if (adapter != null) {
        if (!await adapter.isCurrentOwner(expectedOwner)) {
          if (mounted) {
            state = state.copyWith(
              isActionLoading: false,
              request: null,
              permissionDenied: true,
              fromCache: false,
              hasDirtyLocal: false,
              error: null,
            );
          }
          return;
        }
      }

      state = state.copyWith(
        isActionLoading: false,
        request: updatedRequest,
        fromCache: false,
        hasDirtyLocal: false,
        error:
            snapshotSaveFailed
                ? 'Статус изменён на сервере, но локальная копия не обновлена.'
                : null,
      );
      if (!mounted) return;
      if (!requestsNotifier.mounted) return;
      if (adapter != null && !await adapter.isCurrentOwner(expectedOwner)) {
        return;
      }
      await requestsNotifier.loadRequests(refresh: true);
    } catch (error) {
      if (!mounted) return;
      if (adapter != null && !await adapter.isCurrentOwner(expectedOwner)) {
        state = state.copyWith(
          isActionLoading: false,
          request: null,
          permissionDenied: true,
          fromCache: false,
          hasDirtyLocal: false,
          error: null,
        );
        return;
      }
      state = state.copyWith(
        isActionLoading: false,
        permissionDenied: _isPermissionDenied(error),
        error: _errorMessage(error),
      );
      rethrow;
    }
  }
}

bool _isPermissionDenied(Object error) {
  return error is ApiException && error.statusCode == 403;
}

String _errorMessage(Object error) {
  if (error is ApiException) {
    return error.message;
  }

  if (error is FormatException) {
    return 'Данные заявки пришли неполными. Обновите экран и повторите попытку.';
  }

  return 'Не удалось обработать данные заявки.';
}
