import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/cached_entity.dart';
import 'package:prohelpers_mobile/core/storage/cached_entity_codec.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_service.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';
import 'package:prohelpers_mobile/core/storage/snapshot_read.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_repository.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_snapshot_adapter.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_summary_model.dart';

void main() {
  final owner = EntitySnapshotOwner(userId: 7, orgId: 10);

  WarehouseSnapshotAdapter adapterFor(_FakeWarehouseRepository repository) {
    final memory = _MemoryEntitySnapshotStore();
    var flushes = 0;
    final service = EntitySnapshotService(
      store: memory,
      resolveOwner: () => owner,
      now: () => DateTime.utc(2026, 9, 18, 12),
    );
    return WarehouseSnapshotAdapter(
      repository: repository,
      snapshots: Future.value(service),
      flushQueue: () async {
        flushes++;
        repository.flushCount = flushes;
      },
    );
  }

  test('офлайн читает локальный снимок и не ходит в сеть', () async {
    final store = _MemoryEntitySnapshotStore();
    final service = EntitySnapshotService(
      store: store,
      resolveOwner: () => owner,
    );
    await service.putSnapshot(
      cachedEntityFromPayload(
        type: WarehouseSnapshotAdapter.type,
        remoteId: WarehouseSnapshotAdapter.remoteId,
        payload: _warehousePayload(name: 'Кэш склада'),
        updatedAt: DateTime.utc(2026, 9, 17),
      ),
    );
    final repository = _FakeWarehouseRepository();
    final adapter = WarehouseSnapshotAdapter(
      repository: repository,
      snapshots: Future.value(service),
      flushQueue: () async => repository.flushCount++,
    );

    final result = await adapter.load(online: false);

    expect(result.presence, SnapshotPresence.ready);
    expect(result.fromCache, isTrue);
    expect(result.data?.warehouses.single.name, 'Кэш склада');
    expect(repository.fetchCount, 0);
    expect(repository.flushCount, 0);
  });

  test('офлайн без снимка даёт честное отсутствие данных', () async {
    final adapter = adapterFor(_FakeWarehouseRepository());

    final result = await adapter.load(online: false);

    expect(result.presence, SnapshotPresence.missing);
    expect(result.data, isNull);
    expect(result.error, SnapshotUserMessages.openWarehouseOnce);
  });

  test('онлайн сначала сбрасывает очередь, затем pullAndMerge', () async {
    final repository = _FakeWarehouseRepository(
      payload: _warehousePayload(name: 'Сеть'),
    );
    final adapter = adapterFor(repository);

    final result = await adapter.load(online: true);

    expect(repository.flushCount, 1);
    expect(repository.fetchCount, 1);
    expect(result.presence, SnapshotPresence.ready);
    expect(result.data?.warehouses.single.name, 'Сеть');
    expect(result.fromCache, isFalse);
  });

  test('успешный пустой склад — empty, а не missing', () async {
    final repository = _FakeWarehouseRepository(
      payload: _emptyWarehousePayload,
    );
    final adapter = adapterFor(repository);

    final result = await adapter.load(online: true);

    expect(result.presence, SnapshotPresence.empty);
    expect(result.data?.warehouses, isEmpty);
  });

  test('403 не маскируется пустым успехом', () async {
    final adapter = adapterFor(
      _FakeWarehouseRepository(permissionDenied: true),
    );

    final result = await adapter.load(online: true);

    expect(result.presence, SnapshotPresence.permissionDenied);
    expect(result.error, 'Недостаточно прав для просмотра склада.');
  });

  test('грязный локальный снимок остаётся конфликтом после pull', () async {
    final store = _MemoryEntitySnapshotStore();
    final service = EntitySnapshotService(
      store: store,
      resolveOwner: () => owner,
      now: () => DateTime.utc(2026, 9, 18, 12),
    );
    await service.putSnapshot(
      cachedEntityFromPayload(
        type: WarehouseSnapshotAdapter.type,
        remoteId: WarehouseSnapshotAdapter.remoteId,
        payload: _warehousePayload(name: 'Локально'),
        updatedAt: DateTime.utc(2026, 9, 17),
        dirty: true,
      ),
    );
    final repository = _FakeWarehouseRepository(
      payload: _warehousePayload(
        name: 'Сервер',
        updatedAt: '2026-09-18T11:00:00Z',
      ),
    );
    final adapter = WarehouseSnapshotAdapter(
      repository: repository,
      snapshots: Future.value(service),
      flushQueue: () async {},
    );

    final result = await adapter.load(online: true);

    expect(result.presence, SnapshotPresence.conflict);
    expect(result.data?.warehouses.single.name, 'Локально');
    expect(result.hasDirtyLocal, isTrue);
  });

  test('офлайн после сети использует уже сохранённый снимок', () async {
    final repository = _FakeWarehouseRepository(
      payload: _warehousePayload(name: 'После связи'),
    );
    final store = _MemoryEntitySnapshotStore();
    final service = EntitySnapshotService(
      store: store,
      resolveOwner: () => owner,
      now: () => DateTime.utc(2026, 9, 18, 12),
    );
    final adapter = WarehouseSnapshotAdapter(
      repository: repository,
      snapshots: Future.value(service),
      flushQueue: () async => repository.flushCount++,
    );

    await adapter.load(online: true);
    repository.payload = _warehousePayload(name: 'Не должны увидеть');
    final offline = await adapter.load(online: false);

    expect(offline.presence, SnapshotPresence.ready);
    expect(offline.data?.warehouses.single.name, 'После связи');
    expect(repository.fetchCount, 1);
  });

  test('парсер неполного движения не валит снимок склада', () async {
    final payload = _warehousePayload(name: 'Основной');
    payload['recent_movements'] = [
      {
        'id': 1,
        'movement_type': 'reserved_issue',
        'quantity': 1,
        'price': 10,
        'warehouse_name': 'Основной',
        'material_name': 'Цемент',
      },
      {'id': 2, 'movement_type': 'receipt'},
    ];
    final adapter = adapterFor(_FakeWarehouseRepository(payload: payload));

    final result = await adapter.load(online: true);

    expect(result.presence, SnapshotPresence.ready);
    expect(result.data?.recentMovements, hasLength(1));
    expect(result.data?.recentMovements.single.movementType, 'reserved_issue');
  });
}

Map<String, dynamic> _warehousePayload({
  required String name,
  String? updatedAt,
}) {
  return {
    'summary': {
      'warehouse_count': 1,
      'unique_items_count': 4,
      'low_stock_count': 0,
      'reserved_items_count': 1,
      'recent_movements_count': 0,
      'total_value': 12000,
    },
    'warehouses': [
      {
        'id': 1,
        'name': name,
        'is_main': true,
        'unique_items_count': 4,
        'total_value': 12000,
      },
    ],
    'recent_movements': <Map<String, dynamic>>[],
    if (updatedAt != null) 'updated_at': updatedAt,
  };
}

const _emptyWarehousePayload = {
  'summary': {
    'warehouse_count': 0,
    'unique_items_count': 0,
    'low_stock_count': 0,
    'reserved_items_count': 0,
    'recent_movements_count': 0,
    'total_value': 0,
  },
  'warehouses': <Map<String, dynamic>>[],
  'recent_movements': <Map<String, dynamic>>[],
};

class _FakeWarehouseRepository extends WarehouseRepository {
  _FakeWarehouseRepository({this.payload, this.permissionDenied = false})
    : super(Dio());

  Map<String, dynamic>? payload;
  final bool permissionDenied;
  int fetchCount = 0;
  int flushCount = 0;

  @override
  Future<Map<String, dynamic>> fetchWarehouseSummaryPayload() async {
    fetchCount++;
    if (permissionDenied) {
      throw const ApiException(
        'Недостаточно прав для просмотра склада.',
        statusCode: 403,
      );
    }
    return payload ?? _warehousePayload(name: 'Сеть');
  }

  @override
  Future<WarehouseSummaryModel> fetchWarehouseSummary() async {
    return WarehouseSummaryModel.fromJson(await fetchWarehouseSummaryPayload());
  }
}

class _MemoryEntitySnapshotStore implements EntitySnapshotStore {
  final _items = <String, CachedEntity>{};
  var _nextId = 1;

  @override
  Future<void> put(CachedEntity entity) async {
    if (entity.id == 0) {
      entity.id = _nextId++;
    }
    _items[_key(entity)] = entity;
  }

  @override
  Future<void> deleteCleanScope({
    required int userId,
    required int orgId,
    required String type,
    required int? projectId,
    required Set<String> keepRemoteIds,
  }) async {
    final keys =
        _items.entries
            .where((entry) {
              final entity = entry.value;
              return entity.userId == userId &&
                  entity.orgId == orgId &&
                  entity.type == type &&
                  entity.projectId == projectId &&
                  !entity.dirty &&
                  !keepRemoteIds.contains(entity.remoteId);
            })
            .map((entry) => entry.key)
            .toList();
    for (final key in keys) {
      _items.remove(key);
    }
  }

  @override
  Future<CachedEntity?> findOne({
    required int userId,
    required int orgId,
    required String type,
    required String remoteId,
    int? projectId,
  }) async {
    return _items[_composeKey(
      userId: userId,
      orgId: orgId,
      type: type,
      remoteId: remoteId,
      projectId: projectId,
    )];
  }

  @override
  Future<List<CachedEntity>> findList({
    required int userId,
    required int orgId,
    required String type,
    int? projectId,
  }) async {
    return _items.values.where((entity) {
      return entity.userId == userId &&
          entity.orgId == orgId &&
          entity.type == type &&
          entity.projectId == projectId;
    }).toList();
  }

  String _key(CachedEntity entity) {
    return _composeKey(
      userId: entity.userId,
      orgId: entity.orgId,
      type: entity.type,
      remoteId: entity.remoteId,
      projectId: entity.projectId,
    );
  }

  String _composeKey({
    required int userId,
    required int orgId,
    required String type,
    required String remoteId,
    int? projectId,
  }) {
    return '$userId|$orgId|$type|$remoteId|${projectId ?? ''}';
  }
}
