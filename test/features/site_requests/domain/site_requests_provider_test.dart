import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_scope.dart';

class _FakeSiteRequestsRepository extends SiteRequestsRepository {
  _FakeSiteRequestsRepository({
    this.permissionDenied = false,
    this.invalidContract = false,
  }) : super(Dio());

  final bool permissionDenied;
  final bool invalidContract;
  final loadedPages = <int>[];
  String? loadedStatus;
  int? loadedProjectId;
  SiteRequestsScope? loadedScope;

  @override
  Future<List<SiteRequestModel>> fetchSiteRequests({
    int page = 1,
    int perPage = 20,
    String? status,
    int? projectId,
    String? search,
    SiteRequestsScope scope = SiteRequestsScope.own,
  }) async {
    if (permissionDenied) {
      throw const ApiException(
        'Недостаточно прав для просмотра заявок.',
        statusCode: 403,
      );
    }

    if (invalidContract) {
      throw const FormatException('missing status');
    }

    loadedPages.add(page);
    loadedStatus = status;
    loadedProjectId = projectId;
    loadedScope = scope;

    return page == 1 ? [_request] : const [];
  }

  @override
  Future<SiteRequestModel> changeSiteRequestStatus(
    int id,
    String status, {
    String? notes,
  }) async {
    return _request..status = status;
  }
}

final _request =
    SiteRequestModel()
      ..serverId = 1
      ..title = 'Бетон'
      ..status = 'pending'
      ..statusLabel = 'На согласовании'
      ..priority = 'medium'
      ..priorityLabel = 'Средний'
      ..requestType = 'material_request'
      ..requestTypeLabel = 'Материалы'
      ..projectId = 15;

void main() {
  test(
    'загружает страницы и останавливает пагинацию на пустом ответе',
    () async {
      final repository = _FakeSiteRequestsRepository();
      final notifier = SiteRequestsNotifier(repository, initialProjectId: 15);

      await notifier.loadRequests();
      await notifier.loadRequests();

      expect(repository.loadedPages, [1, 2]);
      expect(notifier.state.requests, hasLength(1));
      expect(notifier.state.currentPage, 3);
      expect(notifier.state.hasMore, isFalse);
    },
  );

  test('передает scope, проект и фильтр статуса в репозиторий', () async {
    final repository = _FakeSiteRequestsRepository();
    final notifier = SiteRequestsNotifier(
      repository,
      initialProjectId: 15,
      initialScope: SiteRequestsScope.approvals,
    );

    notifier.setStatusFilter('pending');
    await Future<void>.delayed(Duration.zero);

    expect(repository.loadedStatus, 'pending');
    expect(repository.loadedProjectId, 15);
    expect(repository.loadedScope, SiteRequestsScope.approvals);
    expect(notifier.state.statusFilter, 'pending');
  });

  test('фиксирует состояние недостаточных прав при загрузке', () async {
    final repository = _FakeSiteRequestsRepository(permissionDenied: true);
    final notifier = SiteRequestsNotifier(repository, initialProjectId: 15);

    await notifier.loadRequests();

    expect(notifier.state.permissionDenied, isTrue);
    expect(notifier.state.error, 'Недостаточно прав для просмотра заявок.');
    expect(notifier.state.requests, isEmpty);
  });

  test('показывает бизнес-сообщение при неполных данных заявки', () async {
    final repository = _FakeSiteRequestsRepository(invalidContract: true);
    final notifier = SiteRequestsNotifier(repository, initialProjectId: 15);

    await notifier.loadRequests();

    expect(notifier.state.permissionDenied, isFalse);
    expect(
      notifier.state.error,
      'Данные заявки пришли неполными. Обновите экран и повторите попытку.',
    );
  });
}
