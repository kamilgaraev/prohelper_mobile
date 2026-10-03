import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/design_management/data/bim_models.dart';
import 'package:prohelpers_mobile/features/design_management/data/bim_repository.dart';
import 'package:prohelpers_mobile/features/design_management/domain/bim_provider.dart';

void main() {
  test('ignores previous catalog request after changing search', () async {
    final first = Completer<BimPage<BimModelVersion>>();
    final second = Completer<BimPage<BimModelVersion>>();
    final repository =
        _FakeRepository()
          ..loader =
              (page, query) => query == 'новая' ? second.future : first.future;
    final notifier = BimCatalogNotifier(repository, 9);
    final older = notifier.load();
    final newer = notifier.load(query: 'новая');
    second.complete(
      const BimPage(
        items: [BimModelVersion(id: 2, title: 'Новая модель', status: 'ready')],
      ),
    );
    await newer;
    first.complete(
      const BimPage(
        items: [
          BimModelVersion(id: 1, title: 'Старая модель', status: 'ready'),
        ],
      ),
    );
    await older;
    expect(notifier.state.versions!.items.single.id, 2);
    expect(notifier.state.query, 'новая');
    notifier.dispose();
  });
  test('loads next versions page without duplicate requests', () async {
    final next = Completer<BimPage<BimModelVersion>>();
    var requests = 0;
    final repository =
        _FakeRepository()
          ..loader = (page, query) async {
            requests++;
            return page == 1
                ? const BimPage(
                  items: [BimModelVersion(id: 1, title: 'АР', status: 'ready')],
                  lastPage: 2,
                  total: 2,
                )
                : next.future;
          };
    final notifier = BimCatalogNotifier(repository, 9);
    await notifier.load();
    final loading = notifier.loadMoreVersions();
    await notifier.loadMoreVersions();
    next.complete(
      const BimPage(
        items: [BimModelVersion(id: 2, title: 'ОВ', status: 'ready')],
        page: 2,
        lastPage: 2,
        total: 2,
      ),
    );
    await loading;
    expect(requests, 2);
    expect(notifier.state.versions!.items.map((item) => item.id), [1, 2]);
    notifier.dispose();
  });
  test(
    'explicitly reports forbidden and avoids updates after disposal',
    () async {
      final repository =
          _FakeRepository()
            ..loader =
                (_, _) async =>
                    throw const ApiException('Нет прав.', statusCode: 403);
      final notifier = BimCatalogNotifier(repository, 9);
      await notifier.load();
      expect(notifier.state.permissionDenied, isTrue);
      expect(notifier.state.loading, isFalse);
      final deferred = Completer<BimPage<BimModelVersion>>();
      repository.loader = (_, _) => deferred.future;
      final loading = notifier.load();
      notifier.dispose();
      deferred.complete(const BimPage(items: []));
      await loading;
    },
  );
}

class _FakeRepository extends BimRepository {
  _FakeRepository() : super(Dio());
  late Future<BimPage<BimModelVersion>> Function(int, String) loader;
  @override
  Future<BimPage<BimModelVersion>> versions(
    int projectId, {
    int page = 1,
    String query = '',
    String? status,
  }) => loader(page, query);
  @override
  Future<BimPage<BimModelSet>> sets(int projectId, {int page = 1}) async =>
      const BimPage(items: []);
}
