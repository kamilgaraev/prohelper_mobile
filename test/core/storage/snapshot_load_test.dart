import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/cached_entity_codec.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_service.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';
import 'package:prohelpers_mobile/core/storage/list_snapshot.dart';
import 'package:prohelpers_mobile/core/storage/snapshot_load.dart';
import 'package:prohelpers_mobile/core/storage/snapshot_read.dart';

import '../../helpers/memory_entity_snapshot_store.dart';

void main() {
  const owner = EntitySnapshotOwner(userId: 7, orgId: 10);

  test('offline list read works after rebuilding snapshot service', () async {
    final store = MemoryEntitySnapshotStore();
    final writer = EntitySnapshotService(
      store: store,
      resolveOwner: () => owner,
    );
    final pulledAt = DateTime.utc(2026, 9, 18, 12);
    await writer.putSnapshot(
      cachedEntityFromPayload(
        type: 'site_requests',
        remoteId: '1',
        projectId: 15,
        payload: const {'id': 1, 'title': 'Заявка'},
        updatedAt: pulledAt,
        pulledAt: pulledAt,
      ),
    );
    await writer.putSnapshot(
      snapshotCollectionMarker(
        type: 'site_requests',
        projectId: 15,
        at: pulledAt,
      ),
    );

    final restartedReader = EntitySnapshotService(
      store: store,
      resolveOwner: () => owner,
    );
    final result = await loadListSnapshot<Map<String, dynamic>>(
      snapshots: Future.value(restartedReader),
      type: 'site_requests',
      online: false,
      fetchPayloads: () async => throw StateError('Offline read fetched.'),
      decode: (entity) => decodeSnapshotPayload(entity),
      missingMessage: 'Откройте список при связи.',
      permissionFallback: 'Нет доступа.',
      incompleteFallback: 'Не удалось загрузить список.',
      projectId: 15,
    );

    expect(result.presence, SnapshotPresence.ready);
    expect(result.fromCache, isTrue);
    expect(result.data?.single['title'], 'Заявка');
  });

  test('permission failure preserves cached list and is visible', () async {
    final store = MemoryEntitySnapshotStore();
    final service = EntitySnapshotService(
      store: store,
      resolveOwner: () => owner,
    );
    await _seedList(service);
    await service.putSnapshot(
      cachedEntityFromPayload(
        type: 'site_requests',
        remoteId: '2',
        projectId: 15,
        payload: const {'id': 2, 'title': 'Локальное изменение'},
        dirty: true,
      ),
    );

    final result = await loadListSnapshot<Map<String, dynamic>>(
      snapshots: Future.value(service),
      type: 'site_requests',
      online: true,
      fetchPayloads:
          () async =>
              throw const ApiException(
                'Недостаточно прав для просмотра заявок.',
                statusCode: 403,
              ),
      decode: (entity) => decodeSnapshotPayload(entity),
      missingMessage: 'Откройте список при связи.',
      permissionFallback: 'Нет доступа.',
      incompleteFallback: 'Не удалось загрузить список.',
      projectId: 15,
    );

    expect(result.presence, SnapshotPresence.permissionDenied);
    expect(result.fromCache, isFalse);
    expect(result.data, isNull);
    expect(result.error, 'Недостаточно прав для просмотра заявок.');
    final offlineRead = await readListSnapshot<Map<String, dynamic>>(
      snapshots: Future.value(service),
      type: 'site_requests',
      decode: (entity) => decodeSnapshotPayload(entity),
      missingMessage: 'Откройте список при связи.',
      projectId: 15,
    );
    expect(offlineRead.presence, SnapshotPresence.permissionDenied);
    expect(offlineRead.data, isNull);
    expect(
      (await service.getList(
        'site_requests',
        15,
      )).map((item) => item.remoteId).toSet(),
      {snapshotCollectionRemoteId, '2'},
    );
  });

  test(
    'refresh failure preserves cached data and exposes a retry message',
    () async {
      final store = MemoryEntitySnapshotStore();
      final service = EntitySnapshotService(
        store: store,
        resolveOwner: () => owner,
      );
      await _seedList(service);

      final result = await loadListSnapshot<Map<String, dynamic>>(
        snapshots: Future.value(service),
        type: 'site_requests',
        online: true,
        fetchPayloads:
            () async => throw const ApiException('Сервер не ответил вовремя.'),
        decode: (entity) => decodeSnapshotPayload(entity),
        missingMessage: 'Откройте список при связи.',
        permissionFallback: 'Нет доступа.',
        incompleteFallback: 'Не удалось обновить список.',
        projectId: 15,
      );

      expect(result.presence, SnapshotPresence.ready);
      expect(result.fromCache, isTrue);
      expect(result.data?.single['title'], 'Сохраненная заявка');
      expect(result.error, 'Сервер не ответил вовремя.');
    },
  );

  test(
    'does not return old owner data when identity changes during refresh',
    () async {
      const newOwner = EntitySnapshotOwner(userId: 8, orgId: 10);
      var currentOwner = owner;
      final store = MemoryEntitySnapshotStore();
      final service = EntitySnapshotService(
        store: store,
        resolveOwner: () => currentOwner,
      );
      await _seedList(service);

      final result = await loadListSnapshot<Map<String, dynamic>>(
        snapshots: Future.value(service),
        type: 'site_requests',
        online: true,
        fetchPayloads: () async {
          currentOwner = newOwner;
          return const [
            {'id': 2, 'title': 'Другой пользователь'},
          ];
        },
        decode: (entity) => decodeSnapshotPayload(entity),
        missingMessage: 'Откройте список при связи.',
        permissionFallback: 'Нет доступа.',
        incompleteFallback: 'Не удалось обновить список.',
        projectId: 15,
      );

      expect(result.presence, SnapshotPresence.error);
      expect(result.data, isNull);
      expect(result.error, 'Сеанс изменился. Обновите экран.');
      expect(
        await store.findList(
          userId: newOwner.userId,
          orgId: newOwner.orgId,
          type: 'site_requests',
          projectId: 15,
        ),
        isEmpty,
      );
    },
  );

  test(
    'conflict refresh keeps cache but marks the result for review',
    () async {
      final store = MemoryEntitySnapshotStore();
      final service = EntitySnapshotService(
        store: store,
        resolveOwner: () => owner,
      );
      await _seedList(service);

      final result = await loadListSnapshot<Map<String, dynamic>>(
        snapshots: Future.value(service),
        type: 'site_requests',
        online: true,
        fetchPayloads:
            () async =>
                throw const ApiException('Конфликт версии.', statusCode: 409),
        decode: (entity) => decodeSnapshotPayload(entity),
        missingMessage: 'Откройте список при связи.',
        permissionFallback: 'Нет доступа.',
        incompleteFallback: 'Не удалось обновить список.',
        projectId: 15,
      );

      expect(result.presence, SnapshotPresence.conflict);
      expect(result.fromCache, isTrue);
      expect(result.data?.single['title'], 'Сохраненная заявка');
      expect(result.error, SnapshotUserMessages.conflict);
      expect(result.hasDirtyLocal, isTrue);
    },
  );

  test('full list refresh prunes only absent clean records', () async {
    final store = MemoryEntitySnapshotStore();
    final service = EntitySnapshotService(
      store: store,
      resolveOwner: () => owner,
    );
    await _seedList(service);
    await service.putSnapshot(
      cachedEntityFromPayload(
        type: 'site_requests',
        remoteId: '2',
        projectId: 15,
        payload: const {'id': 2, 'title': 'Локальное изменение'},
        dirty: true,
      ),
    );

    final result = await loadListSnapshot<Map<String, dynamic>>(
      snapshots: Future.value(service),
      type: 'site_requests',
      online: true,
      fetchPayloads:
          () async => const [
            {'id': 3, 'title': 'Актуальная заявка'},
          ],
      decode: (entity) => decodeSnapshotPayload(entity),
      missingMessage: 'Откройте список при связи.',
      permissionFallback: 'Нет доступа.',
      incompleteFallback: 'Не удалось обновить список.',
      projectId: 15,
      replaceFullList: true,
    );

    expect(result.presence, SnapshotPresence.conflict);
    expect(result.data?.map((item) => item['id']).toSet(), {2, 3});
    expect(await service.getOne('site_requests', '1', projectId: 15), isNull);
    expect(
      (await service.getOne('site_requests', '2', projectId: 15))?.dirty,
      isTrue,
    );
  });

  test(
    'partial list refresh keeps records missing from the response',
    () async {
      final store = MemoryEntitySnapshotStore();
      final service = EntitySnapshotService(
        store: store,
        resolveOwner: () => owner,
      );
      await _seedList(service);

      final result = await loadListSnapshot<Map<String, dynamic>>(
        snapshots: Future.value(service),
        type: 'site_requests',
        online: true,
        fetchPayloads:
            () async => const [
              {'id': 3, 'title': 'Новая страница'},
            ],
        decode: (entity) => decodeSnapshotPayload(entity),
        missingMessage: 'Откройте список при связи.',
        permissionFallback: 'Нет доступа.',
        incompleteFallback: 'Не удалось обновить список.',
        projectId: 15,
      );

      expect(result.presence, SnapshotPresence.ready);
      expect(result.data?.map((item) => item['id']).toSet(), {1, 3});
    },
  );

  test('single resource 403 invalidates cached detail scope', () async {
    final service = EntitySnapshotService(
      store: MemoryEntitySnapshotStore(),
      resolveOwner: () => owner,
    );
    await service.putSnapshot(
      cachedEntityFromPayload(
        type: 'site_request',
        remoteId: '1',
        projectId: 15,
        payload: const {'id': 1, 'title': 'Старая карточка'},
      ),
    );

    final result = await loadSingleEntitySnapshot<Map<String, dynamic>>(
      online: true,
      readCached:
          ({fromNetwork = false}) async => decodeSingleSnapshot(
            entity: await service.getOne('site_request', '1', projectId: 15),
            decode: (payload) => payload,
            missingMessage: 'Откройте карточку при связи.',
            isEmpty: (_) => false,
            fromNetwork: fromNetwork,
          ),
      flushQueue: null,
      snapshots: Future.value(service),
      type: 'site_request',
      remoteId: '1',
      fetchPayload:
          () async =>
              throw const ApiException(
                'Доступ к заявке отозван.',
                statusCode: 403,
              ),
      projectId: 15,
      permissionFallback: 'Нет доступа.',
      malformedFallback: 'Не удалось загрузить карточку.',
    );

    expect(result.presence, SnapshotPresence.permissionDenied);
    expect(result.data, isNull);
    expect(await service.getOne('site_request', '1', projectId: 15), isNull);
  });

  test(
    'single snapshot reports online failure when cache is missing',
    () async {
      final service = EntitySnapshotService(
        store: MemoryEntitySnapshotStore(),
        resolveOwner: () => owner,
      );

      final result = await loadSingleEntitySnapshot<Map<String, dynamic>>(
        online: true,
        readCached:
            ({fromNetwork = false}) async => decodeSingleSnapshot(
              entity: await service.getOne('site_request', '1', projectId: 15),
              decode: (payload) => payload,
              missingMessage: 'Откройте заявку при связи.',
              isEmpty: (_) => false,
              fromNetwork: fromNetwork,
            ),
        flushQueue: null,
        snapshots: Future.value(service),
        type: 'site_request',
        remoteId: '1',
        fetchPayload:
            () async => throw const ApiException('Нет соединения с сервером.'),
        projectId: 15,
        permissionFallback: 'Нет доступа к заявке.',
        malformedFallback: 'Не удалось загрузить заявку.',
      );

      expect(result.presence, SnapshotPresence.error);
      expect(result.data, isNull);
      expect(result.error, 'Нет соединения с сервером.');
    },
  );
}

Future<void> _seedList(EntitySnapshotService service) async {
  final pulledAt = DateTime.utc(2026, 9, 18, 12);
  await service.putSnapshot(
    cachedEntityFromPayload(
      type: 'site_requests',
      remoteId: '1',
      projectId: 15,
      payload: const {'id': 1, 'title': 'Сохраненная заявка'},
      updatedAt: pulledAt,
      pulledAt: pulledAt,
    ),
  );
  await service.putSnapshot(
    snapshotCollectionMarker(
      type: 'site_requests',
      projectId: 15,
      at: pulledAt,
    ),
  );
}
