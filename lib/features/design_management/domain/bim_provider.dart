import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/error/user_message.dart';
import '../../../core/network/api_exception.dart';
import '../data/bim_models.dart';
import '../data/bim_repository.dart';

final bimOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield (await connectivity.checkConnectivity()).any(
    (result) => result != ConnectivityResult.none,
  );
  yield* connectivity.onConnectivityChanged.map(
    (results) => results.any((result) => result != ConnectivityResult.none),
  );
});

class BimCatalogState {
  const BimCatalogState({
    this.versions,
    this.sets,
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.permissionDenied = false,
    this.query = '',
    this.status,
  });
  final BimPage<BimModelVersion>? versions;
  final BimPage<BimModelSet>? sets;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final bool permissionDenied;
  final String query;
  final String? status;
}

class BimCatalogNotifier extends StateNotifier<BimCatalogState> {
  BimCatalogNotifier(this.repository, this.projectId)
    : super(const BimCatalogState());
  final BimRepository repository;
  final int projectId;
  int _request = 0;
  Future<void> load({
    String? query,
    String? status,
    bool clearStatus = false,
  }) async {
    final request = ++_request;
    final search = query ?? state.query;
    final filter = clearStatus ? null : status ?? state.status;
    state = BimCatalogState(
      versions: state.versions,
      sets: state.sets,
      loading: true,
      query: search,
      status: filter,
    );
    try {
      final results = await Future.wait<dynamic>([
        repository.versions(projectId, query: search, status: filter),
        repository.sets(projectId),
      ]);
      if (!mounted || request != _request) return;
      state = BimCatalogState(
        versions: results[0] as BimPage<BimModelVersion>,
        sets: results[1] as BimPage<BimModelSet>,
        query: search,
        status: filter,
      );
    } catch (error) {
      if (!mounted || request != _request) return;
      state = BimCatalogState(
        versions: state.versions,
        sets: state.sets,
        error: UserMessage.fromError(error),
        permissionDenied: error is ApiException && error.statusCode == 403,
        query: search,
        status: filter,
      );
    }
  }

  Future<void> loadMoreVersions() async {
    final current = state;
    final page = current.versions;
    if (current.loading ||
        current.loadingMore ||
        page == null ||
        page.page >= page.lastPage) {
      return;
    }
    final request = _request;
    state = BimCatalogState(
      versions: page,
      sets: current.sets,
      loadingMore: true,
      query: current.query,
      status: current.status,
    );
    try {
      final next = await repository.versions(
        projectId,
        page: page.page + 1,
        query: current.query,
        status: current.status,
      );
      if (!mounted || request != _request) return;
      state = BimCatalogState(
        versions: page.append(next),
        sets: current.sets,
        query: current.query,
        status: current.status,
      );
    } catch (error) {
      if (!mounted || request != _request) return;
      state = BimCatalogState(
        versions: page,
        sets: current.sets,
        error: UserMessage.fromError(error),
        query: current.query,
        status: current.status,
      );
    }
  }

  Future<void> loadMoreSets() async {
    final current = state;
    final page = current.sets;
    if (current.loading ||
        current.loadingMore ||
        page == null ||
        page.page >= page.lastPage) {
      return;
    }
    final request = _request;
    state = BimCatalogState(
      versions: current.versions,
      sets: page,
      loadingMore: true,
      query: current.query,
      status: current.status,
    );
    try {
      final next = await repository.sets(projectId, page: page.page + 1);
      if (!mounted || request != _request) return;
      state = BimCatalogState(
        versions: current.versions,
        sets: page.append(next),
        query: current.query,
        status: current.status,
      );
    } catch (error) {
      if (!mounted || request != _request) return;
      state = BimCatalogState(
        versions: current.versions,
        sets: page,
        error: UserMessage.fromError(error),
        query: current.query,
        status: current.status,
      );
    }
  }
}

final bimCatalogProvider = StateNotifierProvider.autoDispose
    .family<BimCatalogNotifier, BimCatalogState, int>(
      (ref, projectId) =>
          BimCatalogNotifier(ref.read(bimRepositoryProvider), projectId),
    );
final bimViewerProvider = FutureProvider.autoDispose
    .family<BimPreparedViewer, int>(
      (ref, id) => ref.read(bimRepositoryProvider).viewer(id),
    );
final bimIssueProvider = FutureProvider.autoDispose.family<BimIssue, int>(
  (ref, id) => ref.read(bimRepositoryProvider).issue(id),
);
