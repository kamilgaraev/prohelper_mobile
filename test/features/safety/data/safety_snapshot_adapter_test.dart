import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/cached_entity_codec.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_service.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';
import 'package:prohelpers_mobile/core/storage/snapshot_read.dart';
import 'package:prohelpers_mobile/features/safety/data/safety_model.dart';
import 'package:prohelpers_mobile/features/safety/data/safety_repository.dart';
import 'package:prohelpers_mobile/features/safety/data/safety_snapshot_adapter.dart';

import '../../../helpers/memory_entity_snapshot_store.dart';

void main() {
  final owner = EntitySnapshotOwner(userId: 7, orgId: 10);

  test('офлайн читает охрану труда из getList', () async {
    final service = EntitySnapshotService(
      store: MemoryEntitySnapshotStore(),
      resolveOwner: () => owner,
    );
    await service.putSnapshot(
      cachedEntityFromPayload(
        type: SafetySnapshotAdapter.permitsType,
        remoteId: '10',
        projectId: 7,
        payload: _permitPayload(title: 'Высотные работы'),
      ),
    );
    await service.putSnapshot(
      snapshotCollectionMarker(
        type: SafetySnapshotAdapter.permitsType,
        projectId: 7,
        at: DateTime.utc(2026, 9, 17),
      ),
    );
    final repository = _FakeSafetyRepository();
    final adapter = SafetySnapshotAdapter(
      repository: repository,
      snapshots: Future.value(service),
      flushQueue: () async => repository.flushCount++,
    );

    final result = await adapter.load(online: false, projectId: 7);

    expect(result.presence, SnapshotPresence.ready);
    expect(result.data?.permits.single.title, 'Высотные работы');
    expect(repository.fetchCount, 0);
    expect(repository.flushCount, 0);
  });

  test('офлайн без снимка охраны труда — missing', () async {
    final adapter = SafetySnapshotAdapter(
      repository: _FakeSafetyRepository(),
      snapshots: Future.value(
        EntitySnapshotService(
          store: MemoryEntitySnapshotStore(),
          resolveOwner: () => owner,
        ),
      ),
    );

    final result = await adapter.load(online: false, projectId: 7);

    expect(result.presence, SnapshotPresence.missing);
    expect(result.error, SnapshotUserMessages.openSafetyOnce);
  });

  test('онлайн flush+pull пустой охраны труда — empty', () async {
    final repository = _FakeSafetyRepository();
    final adapter = SafetySnapshotAdapter(
      repository: repository,
      snapshots: Future.value(
        EntitySnapshotService(
          store: MemoryEntitySnapshotStore(),
          resolveOwner: () => owner,
        ),
      ),
      flushQueue: () async => repository.flushCount++,
    );

    final result = await adapter.load(online: true, projectId: 7);

    expect(repository.flushCount, 1);
    expect(repository.fetchCount, greaterThan(0));
    expect(result.presence, SnapshotPresence.empty);
  });

  test('403 охраны труда не маскируется пустым успехом', () async {
    final adapter = SafetySnapshotAdapter(
      repository: _FakeSafetyRepository(permissionDenied: true),
      snapshots: Future.value(
        EntitySnapshotService(
          store: MemoryEntitySnapshotStore(),
          resolveOwner: () => owner,
        ),
      ),
      flushQueue: () async {},
    );

    final result = await adapter.load(online: true, projectId: 7);

    expect(result.presence, SnapshotPresence.permissionDenied);
    expect(result.error, 'Недостаточно прав для просмотра охраны труда.');
  });

  test('конфликт 409 охраны труда остаётся конфликтом', () async {
    final adapter = SafetySnapshotAdapter(
      repository: _FakeSafetyRepository(conflict: true),
      snapshots: Future.value(
        EntitySnapshotService(
          store: MemoryEntitySnapshotStore(),
          resolveOwner: () => owner,
        ),
      ),
      flushQueue: () async {},
    );

    final result = await adapter.load(online: true, projectId: 7);

    expect(result.presence, SnapshotPresence.conflict);
    expect(result.error, SnapshotUserMessages.conflict);
  });

  test('404 охраны труда не возвращает старый снимок как успех', () async {
    final repository = _FakeSafetyRepository();
    final adapter = SafetySnapshotAdapter(
      repository: repository,
      snapshots: Future.value(
        EntitySnapshotService(
          store: MemoryEntitySnapshotStore(),
          resolveOwner: () => owner,
        ),
      ),
      flushQueue: () async {},
    );
    await adapter.load(online: true, projectId: 7);

    repository.errorStatusCode = 404;
    final result = await adapter.load(online: true, projectId: 7);

    expect(result.presence, SnapshotPresence.error);
    expect(result.data, isNull);
    expect(result.error, 'HTTP 404');
  });
}

Map<String, dynamic> _permitPayload({String title = 'Высотные работы'}) {
  return {
    'id': 10,
    'project_id': 7,
    'permit_number': 'HSE-P-7-001',
    'title': title,
    'permit_type': 'height_work',
    'risk_level': 'critical',
    'status': 'active',
    'status_label': 'Действует',
    'available_actions': ['suspend', 'close'],
    'valid_from': '2026-06-01T00:00:00Z',
    'valid_until': '2026-06-02T00:00:00Z',
    'required_controls': ['Ограждение'],
  };
}

Map<String, dynamic> _dashboardPayload() {
  return {
    'summary': {
      'active_permits': 0,
      'open_incidents': 0,
      'open_violations': 0,
      'open_corrective_actions': 0,
      'open_inspections': 0,
      'open_findings': 0,
    },
    'mine': {
      'open_permits': 0,
      'open_violations': 0,
      'open_findings': 0,
      'briefings_to_sign': 0,
    },
  };
}

class _FakeSafetyRepository extends SafetyRepository {
  _FakeSafetyRepository({this.permissionDenied = false, this.conflict = false})
    : super(Dio());

  final bool permissionDenied;
  final bool conflict;
  int? errorStatusCode;
  int fetchCount = 0;
  int flushCount = 0;

  void _guard() {
    fetchCount++;
    if (permissionDenied) {
      throw const ApiException(
        'Недостаточно прав для просмотра охраны труда.',
        statusCode: 403,
      );
    }
    if (conflict) {
      throw const ApiException(
        'Конфликт версии охраны труда.',
        statusCode: 409,
      );
    }
    if (errorStatusCode != null) {
      throw ApiException('HTTP $errorStatusCode', statusCode: errorStatusCode);
    }
  }

  @override
  Future<Map<String, dynamic>> fetchDashboardPayload({int? projectId}) async {
    _guard();
    return _dashboardPayload();
  }

  @override
  Future<Map<String, dynamic>?> fetchMyAdmissionPayload({
    int? projectId,
    String workCategory = 'general',
  }) async {
    _guard();
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPermitPayloads({
    int? projectId,
    String? status,
  }) async {
    _guard();
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchIncidentPayloads({
    int? projectId,
    String? status,
  }) async {
    _guard();
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchViolationPayloads({
    int? projectId,
    String? status,
  }) async {
    _guard();
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBriefingPayloads({
    int? projectId,
    String? status,
  }) async {
    _guard();
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchInspectionPayloads({
    int? projectId,
    String? status,
  }) async {
    _guard();
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchInspectionFindingPayloads({
    int? projectId,
    String? status,
  }) async {
    _guard();
    return const [];
  }

  @override
  Future<List<SafetyWorkPermitModel>> fetchPermits({
    int? projectId,
    String? status,
  }) async {
    return const [];
  }
}
