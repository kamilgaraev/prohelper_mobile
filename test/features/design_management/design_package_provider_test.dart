import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/design_management/data/design_package_model.dart';
import 'package:prohelpers_mobile/features/design_management/data/design_package_repository.dart';
import 'package:prohelpers_mobile/features/design_management/domain/design_package_provider.dart';

void main() {
  test('loads and appends pages only for the selected project', () async {
    final repository = _FakeDesignPackageRepository();
    final notifier = DesignPackageNotifier(repository);

    await notifier.load();
    expect(repository.requests, isEmpty);

    notifier.syncProject(9);
    await notifier.load();
    await notifier.loadMore();

    expect(repository.requests, [(9, 1), (9, 2)]);
    expect(notifier.state.page?.items.map((item) => item.id), [1, 2]);
    expect(notifier.state.page?.currentPage, 2);
    expect(notifier.state.page?.lastPage, 2);
  });
}

class _FakeDesignPackageRepository extends DesignPackageRepository {
  _FakeDesignPackageRepository() : super(Dio());

  final requests = <(int, int)>[];

  @override
  Future<DesignPackagePage> fetchList({
    required int projectId,
    int page = 1,
    int perPage = 20,
    String? status,
    String? query,
  }) async {
    requests.add((projectId, page));
    final id = page;
    return DesignPackagePage(
      items: [
        DesignPackageModel(id: id, title: 'Пакет $id', projectId: projectId),
      ],
      currentPage: page,
      lastPage: 2,
      total: 2,
    );
  }
}
