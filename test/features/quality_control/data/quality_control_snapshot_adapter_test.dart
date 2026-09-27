import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/cached_entity_codec.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_service.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';
import 'package:prohelpers_mobile/core/storage/snapshot_read.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_control_repository.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_control_snapshot_adapter.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_defect_model.dart';

import '../../../helpers/memory_entity_snapshot_store.dart';

void main() {
  final owner = EntitySnapshotOwner(userId: 7, orgId: 10);

  test('офлайн читает кэш замечаний без сети', () async {
    final service = EntitySnapshotService(
      store: MemoryEntitySnapshotStore(),
      resolveOwner: () => owner,
    );
    await service.putSnapshot(
      cachedEntityFromPayload(
        type: QualityControlSnapshotAdapter.type,
        remoteId: '1',
        projectId: 15,
        payload: _defectPayload(title: 'Скол'),
      ),
    );
    await service.putSnapshot(
      snapshotCollectionMarker(
        type: QualityControlSnapshotAdapter.type,
        projectId: 15,
        at: DateTime.utc(2026, 9, 17),
      ),
    );
    final repository = _FakeQualityRepository();
    final adapter = QualityControlSnapshotAdapter(
      repository: repository,
      snapshots: Future.value(service),
      flushQueue: () async => repository.flushCount++,
    );

    final result = await adapter.load(online: false, projectId: 15);

    expect(result.presence, SnapshotPresence.ready);
    expect(result.data?.single.title, 'Скол');
    expect(repository.fetchCount, 0);
    expect(repository.flushCount, 0);
  });

  test('офлайн без маркера коллекции — нет снимка', () async {
    final adapter = QualityControlSnapshotAdapter(
      repository: _FakeQualityRepository(),
      snapshots: Future.value(
        EntitySnapshotService(
          store: MemoryEntitySnapshotStore(),
          resolveOwner: () => owner,
        ),
      ),
    );

    final result = await adapter.load(online: false, projectId: 15);

    expect(result.presence, SnapshotPresence.missing);
    expect(result.error, SnapshotUserMessages.openQualityOnce);
  });

  test('онлайн сначала flush, затем pull пустого списка', () async {
    final repository = _FakeQualityRepository(payloads: const []);
    final adapter = QualityControlSnapshotAdapter(
      repository: repository,
      snapshots: Future.value(
        EntitySnapshotService(
          store: MemoryEntitySnapshotStore(),
          resolveOwner: () => owner,
        ),
      ),
      flushQueue: () async => repository.flushCount++,
    );

    final result = await adapter.load(online: true, projectId: 15);

    expect(repository.flushCount, 1);
    expect(repository.fetchCount, 1);
    expect(result.presence, SnapshotPresence.empty);
    expect(result.data, isEmpty);
  });

  test('403 не маскируется пустым списком', () async {
    final adapter = QualityControlSnapshotAdapter(
      repository: _FakeQualityRepository(permissionDenied: true),
      snapshots: Future.value(
        EntitySnapshotService(
          store: MemoryEntitySnapshotStore(),
          resolveOwner: () => owner,
        ),
      ),
      flushQueue: () async {},
    );

    final result = await adapter.load(online: true, projectId: 15);

    expect(result.presence, SnapshotPresence.permissionDenied);
    expect(result.error, 'Недостаточно прав для просмотра контроля качества.');
  });

  test('конфликт 409 остаётся отдельным состоянием', () async {
    final adapter = QualityControlSnapshotAdapter(
      repository: _FakeQualityRepository(conflict: true),
      snapshots: Future.value(
        EntitySnapshotService(
          store: MemoryEntitySnapshotStore(),
          resolveOwner: () => owner,
        ),
      ),
      flushQueue: () async {},
    );

    final result = await adapter.load(online: true, projectId: 15);

    expect(result.presence, SnapshotPresence.conflict);
    expect(result.error, SnapshotUserMessages.conflict);
  });
}

Map<String, dynamic> _defectPayload({String title = 'Скол плитки'}) {
  return {
    'id': 1,
    'project_id': 15,
    'defect_number': 'QD-1',
    'title': title,
    'severity': 'major',
    'status': 'open',
    'inspection_required': false,
    'workflow_summary': {
      'status': 'open',
      'available_actions': ['start'],
      'problem_flags': [],
    },
    'available_actions': ['start'],
    'photos': [],
    'status_history': [],
    'problem_flags': [],
    'updated_at': '2026-09-17T10:00:00Z',
  };
}

class _FakeQualityRepository extends QualityControlRepository {
  _FakeQualityRepository({
    this.payloads,
    this.permissionDenied = false,
    this.conflict = false,
  }) : super(Dio());

  final List<Map<String, dynamic>>? payloads;
  final bool permissionDenied;
  final bool conflict;
  int fetchCount = 0;
  int flushCount = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchDefectPayloads({
    int page = 1,
    int perPage = 50,
    int? projectId,
    String? status,
    String? severity,
    bool overdueOnly = false,
  }) async {
    fetchCount++;
    if (permissionDenied) {
      throw const ApiException(
        'Недостаточно прав для просмотра контроля качества.',
        statusCode: 403,
      );
    }
    if (conflict) {
      throw const ApiException('Конфликт версии замечания.', statusCode: 409);
    }
    return payloads ?? [_defectPayload()];
  }

  @override
  Future<List<QualityDefectModel>> fetchDefects({
    int page = 1,
    int perPage = 50,
    int? projectId,
    String? status,
    String? severity,
    bool overdueOnly = false,
  }) async {
    return (await fetchDefectPayloads(
      page: page,
      perPage: perPage,
      projectId: projectId,
      status: status,
      severity: severity,
      overdueOnly: overdueOnly,
    )).map(QualityDefectModel.fromJson).toList();
  }
}
