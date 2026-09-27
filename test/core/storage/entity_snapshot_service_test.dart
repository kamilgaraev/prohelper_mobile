import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/storage/cached_entity.dart';
import 'package:prohelpers_mobile/core/storage/cached_entity_codec.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_provider.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_service.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_session_identity.dart';

void main() {
  final owner = EntitySnapshotOwner(userId: 7, orgId: 10);
  final other = EntitySnapshotOwner(userId: 99, orgId: 10);

  test('pullAndMerge writes fetched list for the current owner', () async {
    final store = _MemoryEntitySnapshotStore();
    final service = EntitySnapshotService(
      store: store,
      resolveOwner: () => owner,
      now: () => DateTime.utc(2026, 9, 18, 12),
    );

    await service.pullAndMerge(
      'site_requests',
      () async => <CachedEntity>[
        _entity(
          owner: owner,
          remoteId: '1',
          payload: '{"title":"Цемент"}',
          updatedAt: DateTime.utc(2026, 9, 18, 8),
        ),
        _entity(
          owner: owner,
          remoteId: '2',
          payload: '{"title":"Песок"}',
          updatedAt: DateTime.utc(2026, 9, 18, 9),
        ),
      ],
    );

    final list = await service.getList('site_requests', 15);
    expect(list.map((item) => item.remoteId), ['1', '2']);
    expect(list.map((item) => item.payloadJson), [
      '{"title":"Цемент"}',
      '{"title":"Песок"}',
    ]);
    expect(list.every((item) => item.dirty == false), isTrue);
    expect(
      list.every((item) => item.pulledAt == DateTime.utc(2026, 9, 18, 12)),
      isTrue,
    );
  });

  test('merge keeps the snapshot with the later updatedAt', () async {
    final store = _MemoryEntitySnapshotStore();
    final service = EntitySnapshotService(
      store: store,
      resolveOwner: () => owner,
      now: () => DateTime.utc(2026, 9, 18, 12),
    );
    await service.putSnapshot(
      _entity(
        owner: owner,
        remoteId: '1',
        payload: '{"title":"Старое"}',
        updatedAt: DateTime.utc(2026, 9, 18, 8),
      ),
    );

    await service.pullAndMerge(
      'site_requests',
      () async => <CachedEntity>[
        _entity(
          owner: owner,
          remoteId: '1',
          payload: '{"title":"Новое"}',
          updatedAt: DateTime.utc(2026, 9, 18, 10),
        ),
      ],
    );

    final stored = await service.getOne('site_requests', '1', projectId: 15);
    expect(stored?.payloadJson, '{"title":"Новое"}');
    expect(stored?.updatedAt, DateTime.utc(2026, 9, 18, 10));
  });

  test(
    'merge does not keep a stale remote over a newer local snapshot',
    () async {
      final store = _MemoryEntitySnapshotStore();
      final service = EntitySnapshotService(
        store: store,
        resolveOwner: () => owner,
        now: () => DateTime.utc(2026, 9, 18, 12),
      );
      await service.putSnapshot(
        _entity(
          owner: owner,
          remoteId: '1',
          payload: '{"title":"Новее локально"}',
          updatedAt: DateTime.utc(2026, 9, 18, 11),
        ),
      );

      await service.pullAndMerge(
        'site_requests',
        () async => <CachedEntity>[
          _entity(
            owner: owner,
            remoteId: '1',
            payload: '{"title":"Старее с сервера"}',
            updatedAt: DateTime.utc(2026, 9, 18, 9),
          ),
        ],
      );

      final stored = await service.getOne('site_requests', '1', projectId: 15);
      expect(stored?.payloadJson, '{"title":"Новее локально"}');
    },
  );

  test('does not silently overwrite a dirty local snapshot', () async {
    final store = _MemoryEntitySnapshotStore();
    final service = EntitySnapshotService(
      store: store,
      resolveOwner: () => owner,
      now: () => DateTime.utc(2026, 9, 18, 12),
    );
    await service.putSnapshot(
      _entity(
        owner: owner,
        remoteId: '1',
        payload: '{"title":"Черновик"}',
        updatedAt: DateTime.utc(2026, 9, 18, 8),
        dirty: true,
      ),
    );

    await service.pullAndMerge(
      'site_requests',
      () async => <CachedEntity>[
        _entity(
          owner: owner,
          remoteId: '1',
          payload: '{"title":"Сервер"}',
          updatedAt: DateTime.utc(2026, 9, 18, 11),
        ),
      ],
    );

    final stored = await service.getOne('site_requests', '1', projectId: 15);
    expect(stored?.payloadJson, '{"title":"Черновик"}');
    expect(stored?.dirty, isTrue);
    expect(stored?.updatedAt, DateTime.utc(2026, 9, 18, 8));
  });

  test('getList and getOne isolate snapshots by userId', () async {
    final store = _MemoryEntitySnapshotStore();
    final first = EntitySnapshotService(
      store: store,
      resolveOwner: () => owner,
      now: () => DateTime.utc(2026, 9, 18, 12),
    );
    final second = EntitySnapshotService(
      store: store,
      resolveOwner: () => other,
      now: () => DateTime.utc(2026, 9, 18, 12),
    );

    await first.putSnapshot(
      _entity(
        owner: owner,
        remoteId: '1',
        payload: '{"title":"Мои"}',
        updatedAt: DateTime.utc(2026, 9, 18, 8),
      ),
    );
    await second.putSnapshot(
      _entity(
        owner: other,
        remoteId: '1',
        payload: '{"title":"Чужие"}',
        updatedAt: DateTime.utc(2026, 9, 18, 9),
      ),
    );

    final ownList = await first.getList('site_requests', 15);
    final ownOne = await first.getOne('site_requests', '1', projectId: 15);
    final otherList = await second.getList('site_requests', 15);

    expect(ownList, hasLength(1));
    expect(ownList.single.payloadJson, '{"title":"Мои"}');
    expect(ownOne?.payloadJson, '{"title":"Мои"}');
    expect(otherList.single.payloadJson, '{"title":"Чужие"}');
    expect(ownList.single.userId, 7);
    expect(otherList.single.userId, 99);
  });

  test(
    'findOne scopes null project separately from project snapshots',
    () async {
      final store = _MemoryEntitySnapshotStore();
      final service = EntitySnapshotService(
        store: store,
        resolveOwner: () => owner,
      );
      await service.putSnapshot(
        cachedEntityFromPayload(
          type: 'site_requests',
          remoteId: '1',
          projectId: 15,
          payload: const {'title': 'Проект'},
        ),
      );

      expect(
        await service.getOne('site_requests', '1'),
        isNull,
        reason:
            'An unscoped record must not match an arbitrary project record.',
      );
    },
  );

  test('snapshot owner requires an authenticated user and organization', () {
    final resolved = entitySnapshotOwnerFromIdentity(
      const AuthSessionIdentity(
        userId: 7,
        organizationId: 10,
        sessionId: 'session-a',
      ),
    );
    final withoutOrganization = entitySnapshotOwnerFromIdentity(
      const AuthSessionIdentity(
        userId: 7,
        organizationId: null,
        sessionId: 'session-a',
      ),
    );

    expect(resolved?.userId, 7);
    expect(resolved?.orgId, 10);
    expect(withoutOrganization, isNull);
  });

  test('does not persist a fetched snapshot after owner changes', () async {
    var currentOwner = owner;
    final store = _MemoryEntitySnapshotStore();
    final service = EntitySnapshotService(
      store: store,
      resolveOwner: () => currentOwner,
    );

    await expectLater(
      service.pullAndMerge('site_requests', () async {
        currentOwner = other;
        return [
          _entity(
            owner: owner,
            remoteId: '1',
            payload: '{"title":"Не должна попасть в кэш"}',
            updatedAt: DateTime.utc(2026, 9, 18, 8),
          ),
        ];
      }),
      throwsA(isA<SnapshotOwnerChangedException>()),
    );
    expect(await service.getList('site_requests', 15), isEmpty);
    expect(
      await store.findList(
        userId: owner.userId,
        orgId: owner.orgId,
        type: 'site_requests',
        projectId: 15,
      ),
      isEmpty,
    );
  });
}

CachedEntity _entity({
  required EntitySnapshotOwner owner,
  required String remoteId,
  required String payload,
  required DateTime updatedAt,
  bool dirty = false,
}) {
  return CachedEntity()
    ..orgId = owner.orgId
    ..userId = owner.userId
    ..projectId = 15
    ..type = 'site_requests'
    ..remoteId = remoteId
    ..payloadJson = payload
    ..updatedAt = updatedAt
    ..pulledAt = DateTime.utc(2026, 9, 1)
    ..dirty = dirty;
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
    _items.removeWhere((_, entity) {
      return entity.userId == userId &&
          entity.orgId == orgId &&
          entity.type == type &&
          entity.projectId == projectId &&
          !entity.dirty &&
          !keepRemoteIds.contains(entity.remoteId);
    });
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
