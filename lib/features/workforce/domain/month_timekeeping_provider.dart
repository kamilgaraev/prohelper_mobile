import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dio/dio.dart';

import '../data/month_timekeeping_model.dart';
import '../data/month_timekeeping_repository.dart';

final monthTimekeepingProvider = StateNotifierProvider.autoDispose<
  MonthTimekeepingNotifier,
  AsyncValue<TimekeepingPage>
>(
  (ref) =>
      MonthTimekeepingNotifier(ref.read(monthTimekeepingRepositoryProvider)),
);

class MonthTimekeepingNotifier
    extends StateNotifier<AsyncValue<TimekeepingPage>> {
  MonthTimekeepingNotifier(this.repository) : super(const AsyncLoading()) {
    load();
  }
  final MonthTimekeepingRepository repository;
  int _generation = 0;
  bool _busy = false;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  int? projectId;
  int page = 1;
  String get monthKey =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  Future<void> load({
    DateTime? selectedMonth,
    int? selectedProjectId,
    bool changeScope = false,
    int? selectedPage,
  }) async {
    if (_busy) return;
    if (selectedMonth != null) {
      month = DateTime(selectedMonth.year, selectedMonth.month);
      page = 1;
    }
    if (changeScope) {
      projectId = selectedProjectId;
      page = 1;
    }
    if (selectedPage != null) page = selectedPage;
    final generation = ++_generation;
    state = const AsyncLoading();
    try {
      final result = await repository.periods(
        monthKey,
        projectId: projectId,
        page: page,
      );
      if (mounted && generation == _generation) state = AsyncData(result);
    } catch (error, stack) {
      if (mounted && generation == _generation) {
        state = AsyncError(error, stack);
      }
    }
  }

  Future<TimekeepingPeriod> mutate(
    Future<TimekeepingPeriod> Function() call,
  ) async {
    if (_busy) throw StateError('Дождитесь сохранения табеля.');
    _busy = true;
    try {
      return await call();
    } finally {
      _busy = false;
    }
  }

  Future<TimekeepingPeriod> create() =>
      mutate(() => repository.create(monthKey, projectId));
}

final timekeepingDetailProvider = StateNotifierProvider.autoDispose
    .family<TimekeepingDetailNotifier, AsyncValue<TimekeepingPeriod>, int>(
      (ref, id) => TimekeepingDetailNotifier(
        ref.read(monthTimekeepingRepositoryProvider),
        id,
      ),
    );

class TimekeepingDetailNotifier
    extends StateNotifier<AsyncValue<TimekeepingPeriod>> {
  TimekeepingDetailNotifier(this._repository, this.id)
    : super(const AsyncLoading()) {
    load();
  }
  final MonthTimekeepingRepository _repository;
  final int id;
  bool _busy = false;
  int _loadGeneration = 0;
  Future<void> load() async {
    if (_busy) return;
    final generation = ++_loadGeneration;
    state = const AsyncLoading();
    try {
      final result = await _repository.period(id);
      if (mounted && generation == _loadGeneration) state = AsyncData(result);
    } catch (error, stack) {
      if (mounted && generation == _loadGeneration) {
        state = AsyncError(error, stack);
      }
    }
  }

  Future<T> _run<T>(Future<T> Function(TimekeepingPeriod) call) async {
    if (_busy) throw StateError('Дождитесь сохранения табеля.');
    final previous = state.requireValue;
    ++_loadGeneration;
    _busy = true;
    state = const AsyncLoading<TimekeepingPeriod>().copyWithPrevious(state);
    try {
      return await call(previous);
    } finally {
      _busy = false;
      if (mounted && state.isLoading) state = AsyncData(previous);
    }
  }

  Future<void> _update(
    Future<TimekeepingPeriod> Function(TimekeepingPeriod) call,
  ) => _run((period) async {
    final result = await call(period);
    if (mounted) state = AsyncData(result);
  });

  Future<void> saveCell(Map<String, dynamic> data) =>
      _update((period) => _repository.saveCell(period, data));
  Future<void> refresh() => _update(_repository.refresh);
  Future<int> action(String code, Map<String, dynamic> data) async {
    await _update((period) => _repository.action(period, code, data));
    return state.requireValue.id;
  }

  Future<Uri> export(String format) => _run((period) async {
    final document = await _repository.export(period.id, format);
    final updated = await _repository.period(period.id);
    if (mounted) state = AsyncData(updated);
    return _repository.download(document.id);
  });
  Future<Uri> download(int documentId) =>
      _run((_) => _repository.download(documentId));
  Future<int> upload(int documentId, MultipartFile file) =>
      _run((period) => _repository.uploadSignedFile(period, documentId, file));
}
