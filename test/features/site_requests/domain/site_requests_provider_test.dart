import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_service.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';
import 'package:prohelpers_mobile/core/storage/snapshot_read.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_snapshot_adapter.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_scope.dart';

import '../../../helpers/memory_entity_snapshot_store.dart';

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
  Completer<List<SiteRequestModel>>? delayedResult;

  @override
  Future<List<SiteRequestModel>> fetchSiteRequests({
    int page = 1,
    int perPage = 20,
    String? status,
    int? projectId,
    String? search,
    bool urgentOnly = false,
    int? assignedUserId,
    String? requestType,
    DateTime? requiredFrom,
    DateTime? requiredTo,
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

    return delayedResult?.future ?? (page == 1 ? [_request] : const []);
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

class _OfflineSearchRepository extends SiteRequestsRepository {
  _OfflineSearchRepository(this.request) : super(Dio());

  final SiteRequestModel request;

  @override
  Future<List<SiteRequestModel>> fetchSiteRequests({
    int page = 1,
    int perPage = 20,
    String? status,
    int? projectId,
    String? search,
    bool urgentOnly = false,
    int? assignedUserId,
    String? requestType,
    DateTime? requiredFrom,
    DateTime? requiredTo,
    SiteRequestsScope scope = SiteRequestsScope.own,
  }) async {
    if (search != null) {
      throw const ApiException('Нет связи.', statusCode: null);
    }
    return [request];
  }

  @override
  Future<Map<String, dynamic>> changeSiteRequestStatusPayload(
    int id,
    String status, {
    String? notes,
  }) async {
    request.status = status;
    request.statusLabel = 'Отменена';
    return {
      'id': request.serverId,
      'project_id': request.projectId,
      'title': request.title,
      'status': request.status,
      'status_label': request.statusLabel,
      'priority': request.priority,
      'priority_label': request.priorityLabel,
      'request_type': request.requestType,
      'request_type_label': request.requestTypeLabel,
    };
  }
}

class _SnapshotSiteRequestsRepository extends SiteRequestsRepository {
  _SnapshotSiteRequestsRepository() : super(Dio());

  final payload = <String, dynamic>{
    'id': 576,
    'project_id': 15,
    'title': 'QA_FINAL_ACK_20260928_0513',
    'status': 'draft',
    'status_label': 'Черновик',
    'priority': 'medium',
    'priority_label': 'Средний',
    'request_type': 'material_request',
    'request_type_label': 'Материалы',
  };
  bool offline = false;
  Completer<Map<String, dynamic>>? pendingStatus;
  Completer<void>? statusStarted;

  @override
  Future<List<Map<String, dynamic>>> fetchSiteRequestPayloads({
    int page = 1,
    int perPage = 20,
    String? status,
    int? projectId,
    String? search,
    bool urgentOnly = false,
    int? assignedUserId,
    String? requestType,
    DateTime? requiredFrom,
    DateTime? requiredTo,
    SiteRequestsScope scope = SiteRequestsScope.own,
  }) async {
    if (offline) throw const ApiException('Нет связи.');
    return [Map<String, dynamic>.from(payload)];
  }

  @override
  Future<Map<String, dynamic>> changeSiteRequestStatusPayload(
    int id,
    String status, {
    String? notes,
  }) {
    if (pendingStatus != null) {
      statusStarted?.complete();
      return pendingStatus!.future;
    }
    payload['status'] = status;
    payload['status_label'] = 'Отменена';
    return Future.value(Map<String, dynamic>.from(payload));
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
  test('завершает загрузку без ошибки после закрытия экрана', () async {
    final repository =
        _FakeSiteRequestsRepository()
          ..delayedResult = Completer<List<SiteRequestModel>>();
    final notifier = SiteRequestsNotifier(repository, initialProjectId: 15);

    final loading = notifier.loadRequests(refresh: true);
    notifier.dispose();
    repository.delayedResult!.complete([_request]);

    await loading;
  });

  test(
    'offline refresh сохраняет локальный поиск и ACK отмены заявки',
    () async {
      final acknowledgedRequest =
          SiteRequestModel()
            ..serverId = 576
            ..title = 'QA_FINAL_ACK_20260928_0513'
            ..status = 'draft'
            ..statusLabel = 'Черновик'
            ..priority = 'medium'
            ..priorityLabel = 'Средний'
            ..requestType = 'material_request'
            ..requestTypeLabel = 'Материалы'
            ..projectId = 15;
      final repository = _OfflineSearchRepository(acknowledgedRequest);
      final notifier = SiteRequestsNotifier(repository, initialProjectId: 15);

      await notifier.loadRequests(refresh: true);
      await notifier.changeStatus(576, 'cancelled', notes: 'QA отмена');

      notifier.setSearchFilter('QA_FINAL_ACK');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(notifier.state.error, 'Нет связи.');
      expect(notifier.state.requests.single.serverId, 576);
      expect(notifier.state.requests.single.status, 'cancelled');

      notifier.setSearchFilter(null);
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(notifier.state.searchFilter, isNull);
      expect(notifier.state.requests.single.status, 'cancelled');
    },
  );

  test(
    'inline ACK отмены попадает в сериализованный снимок offline списка',
    () async {
      final store = MemoryEntitySnapshotStore();
      var owner = const EntitySnapshotOwner(userId: 7, orgId: 10);
      final repository = _SnapshotSiteRequestsRepository();
      final adapter = SiteRequestsSnapshotAdapter(
        repository: repository,
        snapshots: Future.value(
          EntitySnapshotService(store: store, resolveOwner: () => owner),
        ),
      );
      final notifier = SiteRequestsNotifier(
        repository,
        snapshotAdapter: adapter,
        initialProjectId: 15,
      );

      await notifier.loadRequests(refresh: true);
      await notifier.changeStatus(576, 'cancelled', notes: 'QA отмена');
      expect(notifier.state.requests.single.status, 'cancelled');

      notifier.state.requests.single.status = 'draft';
      repository.offline = true;
      notifier.setSearchFilter('QA_FINAL_ACK');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      notifier.setSearchFilter(null);
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(notifier.state.searchFilter, isNull);
      expect(notifier.state.requests.single.status, 'cancelled');
      expect(notifier.state.fromCache, isTrue);

      owner = const EntitySnapshotOwner(userId: 8, orgId: 10);
      final otherOwner = await adapter.load(online: false, projectId: 15);
      expect(otherOwner.presence, SnapshotPresence.missing);
      expect(otherOwner.data, isNull);
    },
  );

  test(
    'inline ACK старого владельца не сохраняется после смены владельца',
    () async {
      final store = MemoryEntitySnapshotStore();
      var owner = const EntitySnapshotOwner(userId: 7, orgId: 10);
      final repository =
          _SnapshotSiteRequestsRepository()
            ..pendingStatus = Completer<Map<String, dynamic>>()
            ..statusStarted = Completer<void>();
      final adapter = SiteRequestsSnapshotAdapter(
        repository: repository,
        snapshots: Future.value(
          EntitySnapshotService(store: store, resolveOwner: () => owner),
        ),
      );
      final notifier = SiteRequestsNotifier(
        repository,
        snapshotAdapter: adapter,
        initialProjectId: 15,
      );
      await notifier.loadRequests(refresh: true);

      final mutation = notifier.changeStatus(576, 'cancelled');
      await repository.statusStarted!.future;
      owner = const EntitySnapshotOwner(userId: 8, orgId: 10);
      repository.pendingStatus!.complete({
        ...repository.payload,
        'status': 'cancelled',
        'status_label': 'Отменена',
      });
      await mutation;

      expect(notifier.state.requests, isEmpty);
      expect(notifier.state.permissionDenied, isTrue);
      final newOwnerSnapshot = await adapter.load(online: false, projectId: 15);
      expect(newOwnerSnapshot.presence, SnapshotPresence.missing);

      owner = const EntitySnapshotOwner(userId: 7, orgId: 10);
      final oldOwnerSnapshot = await adapter.load(online: false, projectId: 15);
      expect(oldOwnerSnapshot.data?.single.status, 'draft');
    },
  );

  test('смена проекта не принимает ответ устаревшей загрузки', () async {
    final repository = _ProjectSwitchRepository();
    final notifier = SiteRequestsNotifier(repository, initialProjectId: 15);
    final oldProjectLoad = notifier.loadRequests(refresh: true);

    notifier.syncProject(16);
    await notifier.loadRequests(refresh: true);
    repository.oldProjectResult.complete([
      {
        'id': 1,
        'project_id': 15,
        'title': 'Заявка старого объекта',
        'status': 'pending',
        'priority': 'medium',
        'request_type': 'material_request',
      },
    ]);
    await oldProjectLoad;

    expect(notifier.state.projectFilter, 16);
    expect(notifier.state.requests.map((request) => request.serverId), [16]);
    expect(notifier.state.isLoading, isFalse);
  });
}

class _ProjectSwitchRepository extends SiteRequestsRepository {
  _ProjectSwitchRepository() : super(Dio());

  final oldProjectResult = Completer<List<Map<String, dynamic>>>();

  @override
  Future<List<Map<String, dynamic>>> fetchSiteRequestPayloads({
    int page = 1,
    int perPage = 20,
    String? status,
    int? projectId,
    String? search,
    bool urgentOnly = false,
    int? assignedUserId,
    String? requestType,
    DateTime? requiredFrom,
    DateTime? requiredTo,
    SiteRequestsScope scope = SiteRequestsScope.own,
  }) {
    if (projectId == 15) return oldProjectResult.future;
    return Future.value([
      {
        'id': 16,
        'project_id': 16,
        'title': 'Заявка нового объекта',
        'status': 'pending',
        'priority': 'medium',
        'request_type': 'material_request',
      },
    ]);
  }
}
