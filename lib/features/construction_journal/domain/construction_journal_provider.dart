import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/construction_journal_models.dart';
import '../data/construction_journal_repository.dart';

const _sentinel = Object();

class ConstructionJournalState {
  const ConstructionJournalState({
    this.isLoading = false,
    this.items = const [],
    this.summary = const ConstructionJournalSummary(),
    this.availableActions = const [],
    this.project,
    this.error,
  });

  final bool isLoading;
  final List<ConstructionJournalModel> items;
  final ConstructionJournalSummary summary;
  final List<String> availableActions;
  final ConstructionJournalProjectRef? project;
  final String? error;

  ConstructionJournalState copyWith({
    bool? isLoading,
    List<ConstructionJournalModel>? items,
    ConstructionJournalSummary? summary,
    List<String>? availableActions,
    Object? project = _sentinel,
    Object? error = _sentinel,
  }) {
    return ConstructionJournalState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      summary: summary ?? this.summary,
      availableActions: availableActions ?? this.availableActions,
      project: identical(project, _sentinel) ? this.project : project as ConstructionJournalProjectRef?,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

class ConstructionJournalNotifier extends StateNotifier<ConstructionJournalState> {
  ConstructionJournalNotifier(this._repository) : super(const ConstructionJournalState());

  final ConstructionJournalRepository _repository;

  Future<void> load({required int? projectId}) async {
    if (projectId == null) {
      state = state.copyWith(
        isLoading: false,
        items: const [],
        error: 'Сначала выберите объект.',
        project: null,
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final payload = await _repository.fetchJournals(projectId: projectId);
      state = state.copyWith(
        isLoading: false,
        items: payload.items,
        summary: payload.summary,
        availableActions: payload.availableActions,
        project: payload.project,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }
}

final constructionJournalProvider =
    StateNotifierProvider<ConstructionJournalNotifier, ConstructionJournalState>((ref) {
  return ConstructionJournalNotifier(ref.read(constructionJournalRepositoryProvider));
});

class ConstructionJournalDetailState {
  const ConstructionJournalDetailState({
    this.isLoading = false,
    this.journal,
    this.entries = const [],
    this.entriesSummary = const ConstructionJournalSummary(),
    this.entriesMeta,
    this.availableActions = const [],
    this.error,
  });

  final bool isLoading;
  final ConstructionJournalModel? journal;
  final List<ConstructionJournalEntryModel> entries;
  final ConstructionJournalSummary entriesSummary;
  final JournalPaginationMeta? entriesMeta;
  final List<String> availableActions;
  final String? error;

  ConstructionJournalDetailState copyWith({
    bool? isLoading,
    Object? journal = _sentinel,
    List<ConstructionJournalEntryModel>? entries,
    ConstructionJournalSummary? entriesSummary,
    Object? entriesMeta = _sentinel,
    List<String>? availableActions,
    Object? error = _sentinel,
  }) {
    return ConstructionJournalDetailState(
      isLoading: isLoading ?? this.isLoading,
      journal: identical(journal, _sentinel) ? this.journal : journal as ConstructionJournalModel?,
      entries: entries ?? this.entries,
      entriesSummary: entriesSummary ?? this.entriesSummary,
      entriesMeta: identical(entriesMeta, _sentinel) ? this.entriesMeta : entriesMeta as JournalPaginationMeta?,
      availableActions: availableActions ?? this.availableActions,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

final constructionJournalDetailProvider = StateNotifierProvider.family<
    ConstructionJournalDetailNotifier, ConstructionJournalDetailState, int>((ref, journalId) {
  return ConstructionJournalDetailNotifier(
    ref.read(constructionJournalRepositoryProvider),
    journalId,
  )..load();
});

class ConstructionJournalDetailNotifier extends StateNotifier<ConstructionJournalDetailState> {
  ConstructionJournalDetailNotifier(this._repository, this._journalId)
      : super(const ConstructionJournalDetailState());

  final ConstructionJournalRepository _repository;
  final int _journalId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final payload = await _repository.fetchJournalDetail(_journalId);
      state = state.copyWith(
        isLoading: false,
        journal: payload.journal,
        entries: payload.entries,
        entriesSummary: payload.entriesSummary,
        entriesMeta: payload.entriesMeta,
        availableActions: payload.availableActions,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }
}

class ConstructionJournalEntryDetailState {
  const ConstructionJournalEntryDetailState({
    this.isLoading = false,
    this.entry,
    this.error,
  });

  final bool isLoading;
  final ConstructionJournalEntryModel? entry;
  final String? error;

  ConstructionJournalEntryDetailState copyWith({
    bool? isLoading,
    Object? entry = _sentinel,
    Object? error = _sentinel,
  }) {
    return ConstructionJournalEntryDetailState(
      isLoading: isLoading ?? this.isLoading,
      entry: identical(entry, _sentinel) ? this.entry : entry as ConstructionJournalEntryModel?,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

final constructionJournalEntryDetailProvider = StateNotifierProvider.family<
    ConstructionJournalEntryDetailNotifier, ConstructionJournalEntryDetailState, int>((ref, entryId) {
  return ConstructionJournalEntryDetailNotifier(
    ref.read(constructionJournalRepositoryProvider),
    entryId,
  )..load();
});

class ConstructionJournalEntryDetailNotifier extends StateNotifier<ConstructionJournalEntryDetailState> {
  ConstructionJournalEntryDetailNotifier(this._repository, this._entryId)
      : super(const ConstructionJournalEntryDetailState());

  final ConstructionJournalRepository _repository;
  final int _entryId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final entry = await _repository.fetchEntryDetail(_entryId);
      state = state.copyWith(isLoading: false, entry: entry);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }
}
