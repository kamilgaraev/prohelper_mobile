import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/entity_snapshot_provider.dart';
import '../../../core/storage/snapshot_read.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../auth/domain/auth_provider.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/construction_journal_models.dart';
import '../data/construction_journal_repository.dart';
import '../data/construction_journal_snapshot_adapter.dart';

const _sentinel = Object();

class ConstructionJournalState {
  const ConstructionJournalState({
    this.isLoading = false,
    this.items = const [],
    this.summary = const ConstructionJournalSummary(),
    this.availableActions = const [],
    this.project,
    this.permissionDenied = false,
    this.fromCache = false,
    this.hasDirtyLocal = false,
    this.error,
  });

  final bool isLoading;
  final List<ConstructionJournalModel> items;
  final ConstructionJournalSummary summary;
  final List<ConstructionJournalActionModel> availableActions;
  final ConstructionJournalProjectRef? project;
  final bool permissionDenied;
  final bool fromCache;
  final bool hasDirtyLocal;
  final String? error;

  ConstructionJournalState copyWith({
    bool? isLoading,
    List<ConstructionJournalModel>? items,
    ConstructionJournalSummary? summary,
    List<ConstructionJournalActionModel>? availableActions,
    Object? project = _sentinel,
    bool? permissionDenied,
    bool? fromCache,
    bool? hasDirtyLocal,
    Object? error = _sentinel,
  }) {
    return ConstructionJournalState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      summary: summary ?? this.summary,
      availableActions: availableActions ?? this.availableActions,
      project:
          identical(project, _sentinel)
              ? this.project
              : project as ConstructionJournalProjectRef?,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      fromCache: fromCache ?? this.fromCache,
      hasDirtyLocal: hasDirtyLocal ?? this.hasDirtyLocal,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

class ConstructionJournalNotifier
    extends StateNotifier<ConstructionJournalState> {
  ConstructionJournalNotifier(
    this._repository, {
    ConstructionJournalSnapshotAdapter? snapshotAdapter,
    bool Function()? isOnline,
  }) : _snapshotAdapter = snapshotAdapter,
       _isOnline = isOnline,
       super(const ConstructionJournalState());

  final ConstructionJournalRepository _repository;
  final ConstructionJournalSnapshotAdapter? _snapshotAdapter;
  final bool Function()? _isOnline;

  bool get isLoading => state.isLoading;

  Future<void> load({required int? projectId}) async {
    if (projectId == null) {
      state = state.copyWith(
        isLoading: false,
        items: const [],
        permissionDenied: false,
        fromCache: false,
        hasDirtyLocal: false,
        error: 'Сначала выберите объект.',
        project: null,
      );
      return;
    }

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
          projectId: projectId,
        );
        final payload = read.data;
        final denied = read.presence == SnapshotPresence.permissionDenied;
        state = state.copyWith(
          isLoading: false,
          items: denied ? const [] : (payload?.items ?? const []),
          summary:
              denied
                  ? const ConstructionJournalSummary()
                  : (payload?.summary ?? const ConstructionJournalSummary()),
          availableActions:
              denied ? const [] : (payload?.availableActions ?? const []),
          project: denied ? null : payload?.project,
          permissionDenied: denied,
          fromCache: !denied && read.fromCache,
          hasDirtyLocal: !denied && read.hasDirtyLocal,
          error: read.error,
        );
        return;
      }
      final payload = await _repository.fetchJournals(projectId: projectId);
      state = state.copyWith(
        isLoading: false,
        fromCache: false,
        hasDirtyLocal: false,
        items: payload.items,
        summary: payload.summary,
        availableActions: payload.availableActions,
        project: payload.project,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        permissionDenied: _isPermissionDenied(error),
        fromCache: false,
        error: _errorMessage(error),
      );
    }
  }
}

final constructionJournalProvider = StateNotifierProvider<
  ConstructionJournalNotifier,
  ConstructionJournalState
>((ref) {
  final notifier = ConstructionJournalNotifier(
    ref.read(constructionJournalRepositoryProvider),
    snapshotAdapter: ConstructionJournalSnapshotAdapter(
      repository: ref.read(constructionJournalRepositoryProvider),
      snapshots: ref.read(entitySnapshotServiceProvider.future),
      flushQueue: () async {
        await ref.read(syncQueueProvider.notifier).retryPending();
      },
    ),
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
      final projectId = ref.read(projectsProvider).selectedProject?.serverId;
      if (projectId != null) unawaited(notifier.load(projectId: projectId));
    }
  });
  ref.listen(syncQueueProvider, (previous, next) {
    if (next == null || notifier.isLoading) return;
    final projectId = ref.read(projectsProvider).selectedProject?.serverId;
    if (projectId != null) unawaited(notifier.load(projectId: projectId));
  });
  return notifier;
});

final constructionJournalSnapshotAdapterProvider =
    Provider<ConstructionJournalSnapshotAdapter>((ref) {
      return ConstructionJournalSnapshotAdapter(
        repository: ref.read(constructionJournalRepositoryProvider),
        snapshots: ref.read(entitySnapshotServiceProvider.future),
        flushQueue: () async {
          await ref.read(syncQueueProvider.notifier).retryPending();
        },
      );
    });

class ConstructionJournalDetailState {
  const ConstructionJournalDetailState({
    this.isLoading = false,
    this.journal,
    this.entries = const [],
    this.entriesSummary = const ConstructionJournalSummary(),
    this.entriesMeta,
    this.availableActions = const [],
    this.permissionDenied = false,
    this.fromCache = false,
    this.hasDirtyLocal = false,
    this.error,
  });

  final bool isLoading;
  final ConstructionJournalModel? journal;
  final List<ConstructionJournalEntryModel> entries;
  final ConstructionJournalSummary entriesSummary;
  final JournalPaginationMeta? entriesMeta;
  final List<ConstructionJournalActionModel> availableActions;
  final bool permissionDenied;
  final bool fromCache;
  final bool hasDirtyLocal;
  final String? error;

  ConstructionJournalDetailState copyWith({
    bool? isLoading,
    Object? journal = _sentinel,
    List<ConstructionJournalEntryModel>? entries,
    ConstructionJournalSummary? entriesSummary,
    Object? entriesMeta = _sentinel,
    List<ConstructionJournalActionModel>? availableActions,
    bool? permissionDenied,
    bool? fromCache,
    bool? hasDirtyLocal,
    Object? error = _sentinel,
  }) {
    return ConstructionJournalDetailState(
      isLoading: isLoading ?? this.isLoading,
      journal:
          identical(journal, _sentinel)
              ? this.journal
              : journal as ConstructionJournalModel?,
      entries: entries ?? this.entries,
      entriesSummary: entriesSummary ?? this.entriesSummary,
      entriesMeta:
          identical(entriesMeta, _sentinel)
              ? this.entriesMeta
              : entriesMeta as JournalPaginationMeta?,
      availableActions: availableActions ?? this.availableActions,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      fromCache: fromCache ?? this.fromCache,
      hasDirtyLocal: hasDirtyLocal ?? this.hasDirtyLocal,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

final constructionJournalDetailProvider = StateNotifierProvider.family<
  ConstructionJournalDetailNotifier,
  ConstructionJournalDetailState,
  ({int journalId, int? projectId})
>((ref, scope) {
  final notifier = ConstructionJournalDetailNotifier(
    ref.read(constructionJournalRepositoryProvider),
    scope.journalId,
    projectId: scope.projectId,
    snapshotAdapter: ref.read(constructionJournalSnapshotAdapterProvider),
    isOnline: () {
      final auth = ref.read(authProvider);
      return auth is AuthAuthenticated && auth.isOnlineVerified;
    },
  );
  ref.listen<AuthState>(authProvider, (previous, next) {
    final wasOnline =
        previous is AuthAuthenticated && previous.isOnlineVerified;
    final isOnline = next is AuthAuthenticated && next.isOnlineVerified;
    if (!wasOnline && isOnline && !notifier.isLoading) {
      unawaited(notifier.load());
    }
  });
  ref.listen(syncQueueProvider, (previous, next) {
    if (next != null && !notifier.isLoading) unawaited(notifier.load());
  });
  unawaited(notifier.load());
  return notifier;
});

class ConstructionJournalDetailNotifier
    extends StateNotifier<ConstructionJournalDetailState> {
  ConstructionJournalDetailNotifier(
    this._repository,
    this._journalId, {
    required int? projectId,
    ConstructionJournalSnapshotAdapter? snapshotAdapter,
    bool Function()? isOnline,
  }) : _projectId = projectId,
       _snapshotAdapter = snapshotAdapter,
       _isOnline = isOnline,
       super(const ConstructionJournalDetailState());

  final ConstructionJournalRepository _repository;
  final int _journalId;
  final int? _projectId;
  final ConstructionJournalSnapshotAdapter? _snapshotAdapter;
  final bool Function()? _isOnline;

  bool get isLoading => state.isLoading;

  Future<void> load() async {
    state = state.copyWith(
      isLoading: true,
      permissionDenied: false,
      error: null,
    );

    try {
      final snapshotAdapter = _snapshotAdapter;
      if (snapshotAdapter != null) {
        final read = await snapshotAdapter.loadDetail(
          online: _isOnline?.call() ?? false,
          journalId: _journalId,
          projectId: _projectId,
        );
        final denied = read.presence == SnapshotPresence.permissionDenied;
        final payload = denied ? null : read.data;
        state = state.copyWith(
          isLoading: false,
          journal: payload?.journal,
          entries: payload?.entries ?? const [],
          entriesSummary: payload?.entriesSummary,
          entriesMeta: payload?.entriesMeta,
          availableActions: payload?.availableActions ?? const [],
          permissionDenied: denied,
          fromCache: !denied && read.fromCache,
          hasDirtyLocal: !denied && read.hasDirtyLocal,
          error: read.error,
        );
        return;
      }
      final payload = await _repository.fetchJournalDetail(_journalId);
      state = state.copyWith(
        isLoading: false,
        fromCache: false,
        hasDirtyLocal: false,
        journal: payload.journal,
        entries: payload.entries,
        entriesSummary: payload.entriesSummary,
        entriesMeta: payload.entriesMeta,
        availableActions: payload.availableActions,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        permissionDenied: _isPermissionDenied(error),
        fromCache: false,
        error: _errorMessage(error),
      );
    }
  }
}

class ConstructionJournalEntryDetailState {
  const ConstructionJournalEntryDetailState({
    this.isLoading = false,
    this.entry,
    this.permissionDenied = false,
    this.fromCache = false,
    this.hasDirtyLocal = false,
    this.error,
  });

  final bool isLoading;
  final ConstructionJournalEntryModel? entry;
  final bool permissionDenied;
  final bool fromCache;
  final bool hasDirtyLocal;
  final String? error;

  ConstructionJournalEntryDetailState copyWith({
    bool? isLoading,
    Object? entry = _sentinel,
    bool? permissionDenied,
    bool? fromCache,
    bool? hasDirtyLocal,
    Object? error = _sentinel,
  }) {
    return ConstructionJournalEntryDetailState(
      isLoading: isLoading ?? this.isLoading,
      entry:
          identical(entry, _sentinel)
              ? this.entry
              : entry as ConstructionJournalEntryModel?,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      fromCache: fromCache ?? this.fromCache,
      hasDirtyLocal: hasDirtyLocal ?? this.hasDirtyLocal,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

final constructionJournalEntryDetailProvider = StateNotifierProvider.family<
  ConstructionJournalEntryDetailNotifier,
  ConstructionJournalEntryDetailState,
  ({int entryId, int? projectId})
>((ref, scope) {
  final notifier = ConstructionJournalEntryDetailNotifier(
    ref.read(constructionJournalRepositoryProvider),
    scope.entryId,
    projectId: scope.projectId,
    snapshotAdapter: ref.read(constructionJournalSnapshotAdapterProvider),
    isOnline: () {
      final auth = ref.read(authProvider);
      return auth is AuthAuthenticated && auth.isOnlineVerified;
    },
  );
  ref.listen<AuthState>(authProvider, (previous, next) {
    final wasOnline =
        previous is AuthAuthenticated && previous.isOnlineVerified;
    final isOnline = next is AuthAuthenticated && next.isOnlineVerified;
    if (!wasOnline && isOnline && !notifier.isLoading) {
      unawaited(notifier.load());
    }
  });
  ref.listen(syncQueueProvider, (previous, next) {
    if (next != null && !notifier.isLoading) unawaited(notifier.load());
  });
  unawaited(notifier.load());
  return notifier;
});

class ConstructionJournalEntryDetailNotifier
    extends StateNotifier<ConstructionJournalEntryDetailState> {
  ConstructionJournalEntryDetailNotifier(
    this._repository,
    this._entryId, {
    required int? projectId,
    ConstructionJournalSnapshotAdapter? snapshotAdapter,
    bool Function()? isOnline,
  }) : _projectId = projectId,
       _snapshotAdapter = snapshotAdapter,
       _isOnline = isOnline,
       super(const ConstructionJournalEntryDetailState());

  final ConstructionJournalRepository _repository;
  final int _entryId;
  final int? _projectId;
  final ConstructionJournalSnapshotAdapter? _snapshotAdapter;
  final bool Function()? _isOnline;

  bool get isLoading => state.isLoading;

  Future<void> load() async {
    state = state.copyWith(
      isLoading: true,
      permissionDenied: false,
      error: null,
    );

    try {
      final snapshotAdapter = _snapshotAdapter;
      if (snapshotAdapter != null) {
        final read = await snapshotAdapter.loadEntry(
          online: _isOnline?.call() ?? false,
          entryId: _entryId,
          projectId: _projectId,
        );
        final denied = read.presence == SnapshotPresence.permissionDenied;
        state = state.copyWith(
          isLoading: false,
          entry: denied ? null : read.data,
          permissionDenied: denied,
          fromCache: !denied && read.fromCache,
          hasDirtyLocal: !denied && read.hasDirtyLocal,
          error: read.error,
        );
        return;
      }
      final entry = await _repository.fetchEntryDetail(_entryId);
      state = state.copyWith(
        isLoading: false,
        entry: entry,
        fromCache: false,
        hasDirtyLocal: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        permissionDenied: _isPermissionDenied(error),
        fromCache: false,
        error: _errorMessage(error),
      );
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
    return 'Данные журнала работ пришли неполными. Обновите экран и повторите попытку.';
  }

  return 'Не удалось обработать данные журнала работ.';
}
