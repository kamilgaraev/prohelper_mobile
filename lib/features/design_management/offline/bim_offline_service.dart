import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import '../../../core/storage/encrypted_local_file_cache.dart';
import 'bim_offline_models.dart';
import 'bim_offline_record.dart';
import 'bim_offline_store.dart';
import 'bim_offline_transport.dart';
import '../data/bim_models.dart';

class BimOfflineService {
  BimOfflineService({
    required this.store,
    required this.files,
    required this.transport,
    required this.currentScope,
    required this.canUseOffline,
    required this.isOnline,
    required this.verifyOnline,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final BimOfflineStore store;
  final EncryptedLocalFileCache files;
  final BimOfflineTransport transport;
  final String? Function() currentScope;
  final Future<bool> Function() canUseOffline;
  final Future<bool> Function() isOnline;
  final Future<bool> Function() verifyOnline;
  final DateTime Function() clock;
  final _changes = StreamController<void>.broadcast();
  final Map<int, CancelToken> _downloads = {};
  final Map<int, Future<void>> _downloadTasks = {};
  final Map<int, BimOfflineRecord> _activePackages = {};
  final Map<String, Future<void>> _setTasks = {};
  final Map<String, CancelToken> _setTokens = {};
  CancelToken? _syncToken;
  Future<void>? _syncTask;
  Future<void> _mutations = Future<void>.value();
  int _epoch = 0;
  bool _disposed = false;
  bool _transitioning = false;
  Stream<void> get changes => _changes.stream;
  String _owner(String scope) => 'bim:$scope';
  String _packageKey(String scope, int versionId) =>
      '$scope:package:$versionId';
  void _notify() {
    if (!_disposed) _changes.add(null);
  }

  String _scope() {
    final scope = currentScope();
    if (_disposed || _transitioning || scope == null) {
      throw StateError('Войдите в МОСТ для работы с сохранёнными моделями.');
    }
    return scope;
  }

  void _guard(String scope, int epoch) {
    if (_disposed ||
        _transitioning ||
        epoch != _epoch ||
        currentScope() != scope) {
      throw StateError('Контекст работы изменился.');
    }
  }

  Future<void> _access(
    String scope,
    int epoch, {
    bool onlineRequired = false,
  }) async {
    if (!await canUseOffline()) {
      throw StateError('Подтвердите вход в МОСТ через интернет.');
    }
    _guard(scope, epoch);
    if (onlineRequired && (!await isOnline() || !await verifyOnline())) {
      throw StateError('Для отправки нужен интернет и подтверждённый вход.');
    }
    _guard(scope, epoch);
  }

  Future<List<BimOfflinePackage>> packages() async {
    final scope = _scope();
    final epoch = _epoch;
    await _access(scope, epoch);
    final records = await store.records(scope);
    _guard(scope, epoch);
    final packages = <BimOfflinePackage>[];
    for (final stored in records.where((item) => item.kind == 'package')) {
      final active = _activePackages[stored.versionId];
      final record = active?.scope == scope ? active! : stored;
      final manifest = BimPackageManifest(
        jsonDecode(record.manifestJson) as Map<String, dynamic>,
      );
      var status = record.status;
      if (!_activePackages.containsKey(record.versionId) && status != 'ready') {
        if (status == 'downloading') status = 'paused';
        try {
          if (record.encryptedPath.isNotEmpty) {
            record.geometryBytes = await files.streamLength(
              encryptedPath: record.encryptedPath,
              totalLength: manifest.geometry.size,
              repair: true,
            );
          }
          if (record.propertiesPath.isNotEmpty) {
            record.propertiesBytes = await files.streamLength(
              encryptedPath: record.propertiesPath,
              totalLength: manifest.properties.size,
              repair: true,
            );
          }
        } catch (_) {}
      }
      packages.add(
        BimOfflinePackage(
          versionId: record.versionId,
          title: record.title,
          status: status,
          downloadedBytes: record.geometryBytes + record.propertiesBytes,
          totalBytes: manifest.totalBytes,
          manifest: manifest.json,
          lastError: record.lastError,
        ),
      );
    }
    _guard(scope, epoch);
    return packages;
  }

  Future<void> saveVersion(int versionId, {String? title, int? projectId}) {
    if (_downloadTasks.containsKey(versionId)) {
      return _downloadTasks[versionId]!;
    }
    final task = _save(versionId, title, projectId).whenComplete(() {
      _downloadTasks.remove(versionId);
      _downloads.remove(versionId);
      _activePackages.remove(versionId);
    });
    _downloadTasks[versionId] = task;
    return task;
  }

  Future<void> _save(int versionId, String? title, int? projectId) async {
    final scope = _scope();
    final epoch = _epoch;
    final token = CancelToken();
    _downloads[versionId] = token;
    BimOfflineRecord? record;
    try {
      await _access(scope, epoch, onlineRequired: true);
      var manifest = await transport.manifest(versionId, token);
      _guard(scope, epoch);
      if (manifest.organizationId != int.parse(scope.split(':')[1])) {
        throw StateError('Модель принадлежит другой организации.');
      }
      if (projectId != null && manifest.projectId != projectId) {
        throw StateError('Модель принадлежит другому проекту.');
      }
      if (!bimRuntimeCompatible(manifest.json)) {
        throw StateError('Подготовьте модель для текущей версии просмотрщика.');
      }
      final key = _packageKey(scope, versionId);
      record = await store.get(key);
      if (record != null &&
          BimPackageManifest(
                jsonDecode(record.manifestJson) as Map<String, dynamic>,
              ).fingerprint !=
              manifest.fingerprint) {
        await _deleteRecord(record);
        record = null;
      }
      record ??=
          BimOfflineRecord()
            ..scope = scope
            ..key = key
            ..kind = 'package'
            ..versionId = versionId;
      record.title = title ?? record.title;
      record.manifestJson = jsonEncode(manifest.json);
      record.status = 'downloading';
      record.lastError = null;
      _activePackages[versionId] = record;
      await store.put(record);
      _notify();
      for (final geometry in [true, false]) {
        final context =
            '$key:${manifest.generation}:${geometry ? 'geometry' : 'properties'}';
        final path = await files.streamPath(
          ownerIdentity: _owner(scope),
          context: context,
        );
        if (geometry) {
          record.encryptedPath = path;
        } else {
          record.propertiesPath = path;
        }
        await store.put(record);
        for (var refresh = 0; ; refresh++) {
          final asset = geometry ? manifest.geometry : manifest.properties;
          final offset = await files.streamLength(
            encryptedPath: path,
            totalLength: asset.size,
            repair: true,
          );
          _guard(scope, epoch);
          try {
            if (offset < asset.size) {
              final bytes = await transport.download(asset, offset, token);
              final received = await files.appendEncryptedStream(
                ownerIdentity: _owner(scope),
                context: context,
                encryptedPath: path,
                totalLength: asset.size,
                source: bytes,
                cancelled:
                    () =>
                        token.isCancelled ||
                        _disposed ||
                        epoch != _epoch ||
                        currentScope() != scope,
                onProgress: (length) {
                  if (geometry) {
                    record!.geometryBytes = length;
                  } else {
                    record!.propertiesBytes = length;
                  }
                  _notify();
                },
              );
              if (received != asset.size) {
                throw const FormatException('Загрузка пакета не завершена.');
              }
            }
            final digest =
                await sha256
                    .bind(
                      files.decryptStream(
                        ownerIdentity: _owner(scope),
                        encryptedPath: path,
                        context: context,
                        totalLength: asset.size,
                      ),
                    )
                    .first;
            if (digest.toString().toLowerCase() != asset.sha256.toLowerCase()) {
              await files.deleteStagedUpload(path);
              throw const FormatException(
                'Проверка сохранённой модели не пройдена. Повторите загрузку.',
              );
            }
            if (geometry) {
              record.geometryBytes = asset.size;
            } else {
              record.propertiesBytes = asset.size;
            }
            _guard(scope, epoch);
            await store.put(record);
            break;
          } on DioException catch (error) {
            if (token.isCancelled ||
                refresh >= 1 ||
                ![401, 403, 410].contains(error.response?.statusCode)) {
              rethrow;
            }
            final updated = await transport.manifest(versionId, token);
            _guard(scope, epoch);
            if (updated.fingerprint != manifest.fingerprint) {
              await _deleteRecord(record);
              throw const FormatException(
                'Модель обновилась. Сохраните новую версию.',
              );
            }
            manifest = updated;
            record.manifestJson = jsonEncode(updated.json);
            await store.put(record);
          }
        }
      }
      await _indexProperties(record, manifest, scope, epoch);
      _guard(scope, epoch);
      record.status = 'ready';
      await store.put(record);
    } catch (error) {
      if (record != null &&
          !_disposed &&
          epoch == _epoch &&
          currentScope() == scope &&
          await store.get(record.key) != null) {
        record.status =
            token.isCancelled
                ? 'paused'
                : (_denied(error) ? 'blocked' : 'error');
        record.lastError = token.isCancelled ? null : _errorMessage(error);
        await store.put(record);
      }
      if (!token.isCancelled) rethrow;
    } finally {
      _notify();
    }
  }

  void cancelVersion(int versionId) =>
      _downloads[versionId]?.cancel('Загрузка отменена.');

  Future<void> resumeInterruptedDownloads() async {
    if (_disposed ||
        _transitioning ||
        currentScope() == null ||
        !await isOnline()) {
      return;
    }
    final scope = _scope();
    final epoch = _epoch;
    for (final candidate in await store.records(scope)) {
      final record = await store.get(candidate.key);
      if (record == null) continue;
      if (_disposed ||
          _transitioning ||
          currentScope() != scope ||
          epoch != _epoch) {
        return;
      }
      if (record.kind == 'package' && record.status == 'downloading') {
        try {
          try {
            await _downloadTasks[record.versionId];
          } catch (_) {}
          _guard(scope, epoch);
          final latest = await store.get(record.key);
          if (latest?.status == 'downloading') {
            await saveVersion(record.versionId, title: record.title);
          }
        } catch (_) {}
      }
      if (record.kind == 'saved_set' && record.status == 'downloading') {
        try {
          try {
            await _setTasks[record.key];
          } catch (_) {}
          _guard(scope, epoch);
          final latest = await store.get(record.key);
          if (latest?.status == 'downloading') await _startSet(latest!);
        } catch (_) {}
      }
    }
  }

  Future<void> saveSet({
    required int projectId,
    required int setId,
    required int modelSetRevisionId,
    required String title,
    required List<int> versionIds,
    Map<int, BimTransform> transforms = const {},
  }) async {
    final scope = _scope();
    final epoch = _epoch;
    if (projectId <= 0 ||
        setId <= 0 ||
        modelSetRevisionId <= 0 ||
        versionIds.isEmpty ||
        versionIds.any((id) => id <= 0) ||
        versionIds.toSet().length != versionIds.length ||
        transforms.keys.any((id) => !versionIds.contains(id))) {
      throw ArgumentError('Нужны точная версия набора и состав моделей.');
    }
    final key = '$scope:saved_set:$projectId:$setId:$modelSetRevisionId';
    if (_setTasks.containsKey(key)) return _setTasks[key]!;
    final content = {
      'schema_version': 1,
      'user_id': int.parse(scope.split(':')[0]),
      'organization_id': int.parse(scope.split(':')[1]),
      'project_id': projectId,
      'set_id': setId,
      'model_set_revision_id': modelSetRevisionId,
      'title': title,
      'version_ids': List<int>.of(versionIds),
      'transforms': {
        for (final id in versionIds)
          '$id': (transforms[id] ?? const BimTransform()).toJson(),
      },
      'versions': <String, dynamic>{},
    };
    final snapshot = jsonDecode(jsonEncode(content)) as Map<String, dynamic>;
    late BimOfflineRecord record;
    await _mutate(() async {
      await _access(scope, epoch);
      record =
          await store.get(key) ??
          (BimOfflineRecord()
            ..scope = scope
            ..key = key
            ..kind = 'saved_set');
      record.title = title;
      record.status = 'downloading';
      record.lastError = null;
      await _writeDraft(record, snapshot);
      _guard(scope, epoch);
    });
    _notify();
    await _startSet(record);
  }

  Future<void> _startSet(BimOfflineRecord record) {
    final existing = _setTasks[record.key];
    if (existing != null) return existing;
    final token = CancelToken();
    _setTokens[record.key] = token;
    late final Future<void> task;
    task = _runSet(record, token).whenComplete(() {
      if (identical(_setTasks[record.key], task)) {
        _setTasks.remove(record.key);
        _setTokens.remove(record.key);
      }
      _notify();
    });
    _setTasks[record.key] = task;
    return task;
  }

  Future<void> _runSet(BimOfflineRecord record, CancelToken token) async {
    final scope = record.scope;
    final epoch = _epoch;
    try {
      _guard(scope, epoch);
      final content = await _readDraft(record);
      _validateSetScope(content, scope);
      final versions = content['versions'] as Map<String, dynamic>;
      for (final id in (content['version_ids'] as List).cast<int>()) {
        _guard(scope, epoch);
        if (token.isCancelled) return;
        final previous = await store.get(_packageKey(scope, id));
        if (previous?.status == 'ready' && versions['$id'] != null) {
          final local = await cachedVersion(id);
          if (local == null ||
              BimPackageManifest(local.manifest).fingerprint !=
                  versions['$id']) {
            throw StateError(
              'Сохранённая версия модели изменилась. Сохраните набор заново.',
            );
          }
        } else {
          await saveVersion(
            id,
            title: '${record.title} · $id',
            projectId: content['project_id'] as int,
          );
        }
        _guard(scope, epoch);
        if (token.isCancelled) return;
        final package = await store.get(_packageKey(scope, id));
        if (package == null || package.status != 'ready') {
          throw StateError(
            'Не все модели набора сохранены. Продолжите загрузку.',
          );
        }
        final packageManifest = BimPackageManifest(
          jsonDecode(package.manifestJson) as Map<String, dynamic>,
        );
        if (packageManifest.projectId != content['project_id'] ||
            packageManifest.organizationId != content['organization_id']) {
          throw StateError(
            'Модель не принадлежит проекту сохранённого набора.',
          );
        }
        final fingerprint = packageManifest.fingerprint;
        if (versions['$id'] != null && versions['$id'] != fingerprint) {
          throw StateError(
            'Сохранённая версия модели изменилась. Сохраните набор заново.',
          );
        }
        versions['$id'] = fingerprint;
        await _writeDraft(record, content);
        _notify();
      }
      _guard(scope, epoch);
      record.status = 'ready';
      await store.put(record);
    } catch (error) {
      if (!_disposed && epoch == _epoch && currentScope() == scope) {
        record.status =
            token.isCancelled
                ? 'paused'
                : _denied(error)
                ? 'blocked'
                : 'error';
        record.lastError = token.isCancelled ? null : _errorMessage(error);
        await store.put(record);
      }
      if (!token.isCancelled) rethrow;
    }
  }

  void _validateSetScope(Map<String, dynamic> content, String scope) {
    final identity = scope.split(':');
    if (content['schema_version'] != 1 ||
        content['user_id'] != int.parse(identity[0]) ||
        content['organization_id'] != int.parse(identity[1])) {
      throw StateError('Сохранённый набор принадлежит другому контексту.');
    }
  }

  Future<List<BimSavedSet>> savedSets() async {
    final scope = _scope();
    final epoch = _epoch;
    await _access(scope, epoch);
    final result = <BimSavedSet>[];
    for (final record in (await store.records(
      scope,
    )).where((item) => item.kind == 'saved_set')) {
      final content = await _readDraft(record);
      _guard(scope, epoch);
      _validateSetScope(content, scope);
      final ids = (content['version_ids'] as List).cast<int>();
      final versions = content['versions'] as Map<String, dynamic>;
      var completed = 0;
      for (final id in ids) {
        final package = await store.get(_packageKey(scope, id));
        if (package?.status == 'ready') {
          final manifest = BimPackageManifest(
            jsonDecode(package!.manifestJson) as Map<String, dynamic>,
          );
          if (manifest.fingerprint == versions['$id'] &&
              bimRuntimeCompatible(manifest.json) &&
              manifest.projectId == content['project_id'] &&
              manifest.organizationId == content['organization_id']) {
            completed++;
          }
        }
      }
      var status = record.status;
      if (status == 'ready' && completed != ids.length) status = 'incomplete';
      if (status == 'downloading' && !_setTasks.containsKey(record.key)) {
        status = 'paused';
      }
      result.add(
        BimSavedSet(
          localId: record.key.split(':saved_set:').last,
          projectId: content['project_id'] as int,
          setId: content['set_id'] as int,
          modelSetRevisionId: content['model_set_revision_id'] as int,
          title: content['title'] as String,
          versionIds: ids,
          transforms: (content['transforms'] as Map<String, dynamic>).map(
            (key, value) =>
                MapEntry(int.parse(key), BimTransform.fromJson(value)),
          ),
          status: status,
          completedModels: completed,
          totalModels: ids.length,
          lastError: record.lastError,
        ),
      );
    }
    _guard(scope, epoch);
    return result;
  }

  Future<BimSavedSet?> cachedSet(String localId) async {
    final sets = await savedSets();
    BimSavedSet? saved;
    for (final set in sets) {
      if (set.localId == localId) saved = set;
    }
    if (saved == null || !saved.isReady) return null;
    for (final id in saved.versionIds) {
      if (await cachedVersion(id) == null) return null;
    }
    for (final set in await savedSets()) {
      if (set.localId == localId && set.isReady) return set;
    }
    return null;
  }

  Future<void> cancelSet(String localId) async {
    final scope = _scope();
    final epoch = _epoch;
    final key = '$scope:saved_set:$localId';
    final token = _setTokens[key];
    token?.cancel();
    final record = await store.get(key);
    if (record == null) return;
    final content = await _readDraft(record);
    if (token != null) {
      for (final id in (content['version_ids'] as List).cast<int>()) {
        cancelVersion(id);
      }
    }
    try {
      await _setTasks[key];
    } catch (_) {}
    _guard(scope, epoch);
    record.status = 'paused';
    await store.put(record);
    _notify();
  }

  Future<void> resumeSet(String localId) async {
    final scope = _scope();
    final epoch = _epoch;
    final record = await store.get('$scope:saved_set:$localId');
    _guard(scope, epoch);
    if (record == null) throw StateError('Сохранённый набор не найден.');
    record.status = 'downloading';
    record.lastError = null;
    await store.put(record);
    _notify();
    await _startSet(record);
  }

  Future<void> removeSet(String localId) async {
    final scope = _scope();
    final epoch = _epoch;
    await cancelSet(localId);
    _guard(scope, epoch);
    final record = await store.get('$scope:saved_set:$localId');
    if (record != null) await _deleteRecord(record);
    _notify();
  }

  Future<void> removeVersion(int versionId) async {
    final scope = _scope();
    final epoch = _epoch;
    cancelVersion(versionId);
    try {
      await _downloadTasks[versionId];
    } catch (_) {}
    final record = await store.get(_packageKey(scope, versionId));
    _guard(scope, epoch);
    if (record != null) await _deleteRecord(record);
    _notify();
  }

  Future<void> _deleteRecord(BimOfflineRecord record) async {
    for (final path in [record.encryptedPath, record.propertiesPath]) {
      if (path.isNotEmpty) await files.deleteStagedUpload(path);
    }
    await store.clearElements(record.key);
    await store.delete(record.key);
  }

  Future<BimLocalVersion?> cachedVersion(int versionId) async {
    final scope = _scope();
    final epoch = _epoch;
    await _access(scope, epoch);
    final record = await store.get(_packageKey(scope, versionId));
    if (record == null || record.status != 'ready') return null;
    var manifest = BimPackageManifest(
      jsonDecode(record.manifestJson) as Map<String, dynamic>,
    );
    if (manifest.organizationId != int.parse(scope.split(':')[1])) {
      throw StateError('Модель принадлежит другой организации.');
    }
    if (!bimRuntimeCompatible(manifest.json)) {
      throw StateError(
        'Сохранённая модель несовместима с этим просмотрщиком. Сохраните модель заново после подготовки.',
      );
    }
    if (await isOnline()) {
      try {
        final verified = await verifyOnline();
        _guard(scope, epoch);
        if (verified) {
          final latest = await transport.manifest(versionId, CancelToken());
          _guard(scope, epoch);
          if (latest.fingerprint != manifest.fingerprint) {
            record.status = 'outdated';
            await store.put(record);
            _notify();
            throw StateError('Модель обновилась. Сохраните новую версию.');
          }
          manifest = latest;
          if (!bimRuntimeCompatible(latest.json)) {
            throw StateError(
              'Подготовьте модель для текущей версии просмотрщика.',
            );
          }
          record.manifestJson = jsonEncode(latest.json);
          await store.put(record);
        } else {
          await _access(scope, epoch);
        }
      } catch (error) {
        if (_denied(error)) {
          record.status = 'blocked';
          record.lastError = 'Доступ к модели закрыт.';
          await store.put(record);
          _notify();
          rethrow;
        }
        if (error is! DioException ||
            (error.response?.statusCode != null &&
                error.response!.statusCode! < 500)) {
          rethrow;
        }
        await _access(scope, epoch);
      }
    }
    _guard(scope, epoch);
    return BimLocalVersion(
      versionId: versionId,
      length: manifest.geometry.size,
      mime: manifest.geometry.mime,
      manifest: manifest.json,
      geometry: ({int start = 0, int? end}) async* {
        await _access(scope, epoch);
        await for (final bytes in files.decryptStream(
          ownerIdentity: _owner(scope),
          encryptedPath: record.encryptedPath,
          context: '${record.key}:${manifest.generation}:geometry',
          totalLength: manifest.geometry.size,
          start: start,
          end: end,
        )) {
          _guard(scope, epoch);
          yield bytes;
        }
      },
    );
  }

  Future<void> _indexProperties(
    BimOfflineRecord record,
    BimPackageManifest manifest,
    String scope,
    int epoch,
  ) async {
    await store.clearElements(record.key);
    var offset = 0;
    var line = BytesBuilder(copy: false);
    var batch = <BimElementIndex>[];
    final source = files.decryptStream(
      ownerIdentity: _owner(scope),
      encryptedPath: record.propertiesPath,
      context: '${record.key}:${manifest.generation}:properties',
      totalLength: manifest.properties.size,
    );
    Future<void> indexLine(List<int> bytes, int length) async {
      if (bytes.length > 4 * 1024 * 1024) {
        throw const FormatException(
          'Свойства элемента превышают допустимый размер.',
        );
      }
      if (bytes.isNotEmpty) {
        final json = jsonDecode(utf8.decode(bytes));
        if (json is! Map || json['express_id'] is! int) {
          throw const FormatException('Некорректные свойства модели.');
        }
        batch.add(
          BimElementIndex()
            ..scope = scope
            ..packageKey = record.key
            ..expressId = json['express_id'] as int
            ..offset = offset
            ..length = bytes.length,
        );
      }
      offset += length;
      if (batch.length >= 200) {
        _guard(scope, epoch);
        await store.putElements(batch);
        batch = [];
      }
    }

    await for (final chunk in source) {
      var start = 0;
      for (var index = 0; index < chunk.length; index++) {
        if (chunk[index] == 10) {
          line.add(chunk.sublist(start, index));
          final bytes = line.takeBytes();
          await indexLine(bytes, bytes.length + 1);
          start = index + 1;
        }
      }
      line.add(chunk.sublist(start));
      if (line.length > 4 * 1024 * 1024) {
        throw const FormatException(
          'Свойства элемента превышают допустимый размер.',
        );
      }
      _guard(scope, epoch);
    }
    if (line.isNotEmpty) {
      final bytes = line.takeBytes();
      await indexLine(bytes, bytes.length);
    }
    _guard(scope, epoch);
    if (batch.isNotEmpty) await store.putElements(batch);
  }

  Future<Map<String, dynamic>?> elementProperties(
    int versionId,
    int expressId,
  ) async {
    final scope = _scope();
    final epoch = _epoch;
    await _access(scope, epoch);
    if (await isOnline()) await cachedVersion(versionId);
    final record = await store.get(_packageKey(scope, versionId));
    if (record == null || record.status != 'ready') return null;
    final pointer = await store.element(record.key, expressId);
    if (pointer == null) return null;
    final manifest = BimPackageManifest(
      jsonDecode(record.manifestJson) as Map<String, dynamic>,
    );
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in files.decryptStream(
      ownerIdentity: _owner(scope),
      encryptedPath: record.propertiesPath,
      context: '${record.key}:${manifest.generation}:properties',
      totalLength: manifest.properties.size,
      start: pointer.offset,
      end: pointer.offset + pointer.length,
    )) {
      _guard(scope, epoch);
      bytes.add(chunk);
    }
    return jsonDecode(utf8.decode(bytes.takeBytes())) as Map<String, dynamic>;
  }

  Future<List<BimIssueDraft>> drafts() async {
    final scope = _scope();
    final epoch = _epoch;
    await _access(scope, epoch);
    final records = await store.records(scope);
    final result = <BimIssueDraft>[];
    for (final record in records.where((item) => item.kind == 'draft')) {
      final content = await _readDraft(record);
      _guard(scope, epoch);
      result.add(
        BimIssueDraft(
          localId: record.key.split(':draft:').last,
          versionId: record.versionId,
          payload: content['payload'] as Map<String, dynamic>,
          attachments:
              (content['attachments'] as List).cast<Map<String, dynamic>>(),
          attempted: record.attempted,
          status: record.status,
          serverId: record.serverId,
          lastError: record.lastError,
        ),
      );
    }
    return result;
  }

  Future<BimIssueDraft> createDraft({
    required int versionId,
    required Map<String, dynamic> payload,
    List<BimDraftAttachmentInput> attachments = const [],
  }) async {
    final snapshot = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    return _mutate(
      () => _createDraft(
        versionId: versionId,
        payload: snapshot,
        attachments: List<BimDraftAttachmentInput>.of(attachments),
      ),
    );
  }

  Future<BimIssueDraft> _createDraft({
    required int versionId,
    required Map<String, dynamic> payload,
    required List<BimDraftAttachmentInput> attachments,
  }) async {
    final scope = _scope();
    final epoch = _epoch;
    await _access(scope, epoch);
    final localId = _randomKey();
    final key = '$scope:draft:$localId';
    final record =
        BimOfflineRecord()
          ..scope = scope
          ..key = key
          ..kind = 'draft'
          ..versionId = versionId
          ..status = 'queued';
    final staged = <Map<String, dynamic>>[];
    try {
      for (final attachment in attachments) {
        if (![
          'image/jpeg',
          'image/png',
          'image/webp',
        ].contains(attachment.mime)) {
          throw StateError('Можно приложить фото или снимок модели PNG.');
        }
        final size = await File(attachment.path).length();
        if (size <= 0 || size > 10 * 1024 * 1024) {
          throw StateError('Размер изображения должен быть не больше 10 МБ.');
        }
        final attachmentKey = _randomKey();
        final context = '$key:attachment:$attachmentKey';
        final path = await files.stageQueuedAttachment(
          ownerIdentity: _owner(scope),
          context: context,
          sourcePath: attachment.path,
        );
        staged.add({
          'key': attachmentKey,
          'path': path,
          'context': context,
          'size': size,
          'filename': attachment.filename,
          'mime': attachment.mime,
          'kind': attachment.kind,
        });
        _guard(scope, epoch);
      }
      await _writeDraft(record, {
        'payload': {...payload, 'model_version_id': versionId},
        'attachments': staged,
        'idempotency_key': _randomKey(),
      });
      _guard(scope, epoch);
      await store.put(record);
    } catch (_) {
      final persisted = await store.get(key);
      if (persisted != null && !persisted.attempted) {
        await _deleteDraft(persisted);
      } else if (record.encryptedPath.isNotEmpty) {
        await files.deleteStagedUpload(record.encryptedPath);
      }
      for (final item in staged) {
        await files.deleteStagedUpload(item['path'] as String);
      }
      rethrow;
    }
    _notify();
    return (await drafts()).firstWhere((item) => item.localId == localId);
  }

  Future<void> updateDraft(
    String localId, {
    required Map<String, dynamic> payload,
  }) async {
    final snapshot = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    return _mutate(() => _updateDraft(localId, payload: snapshot));
  }

  Future<void> _updateDraft(
    String localId, {
    required Map<String, dynamic> payload,
  }) async {
    final scope = _scope();
    final epoch = _epoch;
    await _access(scope, epoch);
    final record = await store.get('$scope:draft:$localId');
    if (record == null) throw StateError('Замечание не найдено.');
    if (record.attempted) {
      throw StateError(
        'Замечание уже отправлялось. Содержание зафиксировано для безопасного повтора.',
      );
    }
    final content = await _readDraft(record);
    content['payload'] = {...payload, 'model_version_id': record.versionId};
    await _writeDraft(record, content);
    _guard(scope, epoch);
    await store.put(record);
    _notify();
  }

  Future<void> removeDraft(String localId) async {
    return _mutate(() => _removeDraft(localId));
  }

  Future<void> _removeDraft(String localId) async {
    final scope = _scope();
    final record = await store.get('$scope:draft:$localId');
    if (record == null) return;
    if (record.attempted && record.status != 'completed') {
      throw StateError(
        'Отправляемое замечание можно удалить при выходе после подтверждения.',
      );
    }
    await _deleteDraft(record);
    _notify();
  }

  Future<Map<String, dynamic>> _readDraft(BimOfflineRecord record) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in files.decryptStream(
      ownerIdentity: _owner(record.scope),
      encryptedPath: record.encryptedPath,
      context: '${record.key}:content',
      totalLength: record.geometryBytes,
    )) {
      bytes.add(chunk);
    }
    return jsonDecode(utf8.decode(bytes.takeBytes())) as Map<String, dynamic>;
  }

  Future<void> _writeDraft(
    BimOfflineRecord record,
    Map<String, dynamic> content,
  ) async {
    final bytes = utf8.encode(jsonEncode(content));
    if (bytes.length > 1024 * 1024) {
      throw StateError('Содержание замечания превышает допустимый размер.');
    }
    final context = '${record.key}:content';
    final path = await files.streamPath(
      ownerIdentity: _owner(record.scope),
      context: '$context:${_randomKey()}',
    );
    await files.appendEncryptedStream(
      ownerIdentity: _owner(record.scope),
      context: context,
      encryptedPath: path,
      totalLength: bytes.length,
      source: Stream.value(bytes),
    );
    final oldPath = record.encryptedPath;
    record.encryptedPath = path;
    record.geometryBytes = bytes.length;
    await store.put(record);
    if (oldPath.isNotEmpty) await files.deleteStagedUpload(oldPath);
  }

  Future<void> _deleteDraft(BimOfflineRecord record) async {
    final content = await _readDraft(record);
    for (final attachment in content['attachments'] as List) {
      await files.deleteStagedUpload(attachment['path'] as String);
    }
    await _deleteRecord(record);
  }

  Future<void> syncPending({bool force = true}) =>
      _syncTask ??= _sync(force).whenComplete(() {
        _syncTask = null;
        _syncToken = null;
      });
  Future<void> _sync(bool force) async {
    final scope = _scope();
    final epoch = _epoch;
    final token = CancelToken();
    _syncToken = token;
    await _access(scope, epoch, onlineRequired: true);
    final records = await store.records(scope);
    for (final record in records.where(
      (item) => item.kind == 'draft' && item.status != 'completed',
    )) {
      _guard(scope, epoch);
      if (record.status == 'blocked' ||
          record.status == 'conflict' ||
          record.status == 'needs_review' ||
          (!force && record.nextAttemptAt?.isAfter(clock()) == true)) {
        continue;
      }
      try {
        await transport.manifest(record.versionId, token);
        _guard(scope, epoch);
        final content = await _mutate(() async {
          final latest = await store.get(record.key);
          if (latest == null) throw StateError('Замечание удалено.');
          record.encryptedPath = latest.encryptedPath;
          record.geometryBytes = latest.geometryBytes;
          final content = await _readDraft(record);
          record.attempted = true;
          record.status = 'sending';
          record.attempts++;
          record.lastError = null;
          await store.put(record);
          return content;
        });
        _notify();
        if (record.serverId == null) {
          final receipt = await transport.createIssue(
            content['payload'] as Map<String, dynamic>,
            content['idempotency_key'] as String,
            token,
          );
          _guard(scope, epoch);
          record.serverId = receipt.id;
          record.serverRevision = receipt.revision;
          await store.put(record);
        }
        for (final item
            in (content['attachments'] as List).cast<Map<String, dynamic>>()) {
          final key = item['key'] as String;
          if (record.attachmentAcks.contains(key)) continue;
          _guard(scope, epoch);
          final revisions =
              jsonDecode(record.attachmentRevisionsJson)
                  as Map<String, dynamic>;
          final expectedRevision =
              (revisions[key] as int?) ?? record.serverRevision!;
          revisions[key] = expectedRevision;
          record.attachmentRevisionsJson = jsonEncode(revisions);
          await store.put(record);
          final revision = await transport.attach(
            record.serverId!,
            expectedRevision,
            item,
            () => files.decryptStream(
              ownerIdentity: _owner(scope),
              encryptedPath: item['path'] as String,
              context: item['context'] as String,
              totalLength: item['size'] as int,
            ),
            key,
            token,
          );
          _guard(scope, epoch);
          record.attachmentAcks = [...record.attachmentAcks, key];
          record.serverRevision = revision;
          await store.put(record);
        }
        _guard(scope, epoch);
        record.status = 'completed';
        record.nextAttemptAt = null;
        await store.put(record);
      } catch (error) {
        _guard(scope, epoch);
        if (token.isCancelled) return;
        final status =
            error is DioException ? error.response?.statusCode : null;
        record.status =
            _denied(error)
                ? 'blocked'
                : status == 409
                ? 'conflict'
                : status == 422
                ? 'needs_review'
                : 'queued';
        record.lastError = _errorMessage(error);
        record.nextAttemptAt = clock().add(
          Duration(
            seconds: min(300, 5 * pow(2, min(record.attempts, 6)).toInt()),
          ),
        );
        await store.put(record);
      }
      _notify();
    }
  }

  Future<bool> hasPending() async => (await store.records(
    _scope(),
  )).any((item) => item.kind == 'draft' && item.status != 'completed');
  Future<void> prepareContextChange({bool discard = false}) async {
    final scope = _scope();
    _transitioning = true;
    ++_epoch;
    for (final token in _downloads.values) {
      token.cancel();
    }
    _syncToken?.cancel();
    try {
      await _mutations;
      await Future.wait(
        _setTasks.values.map((task) => task.catchError((Object _) {})),
      );
      await Future.wait(
        _downloadTasks.values.map((task) => task.catchError((Object _) {})),
      );
      try {
        await _syncTask;
      } catch (_) {}
      if (!discard &&
          (await store.records(scope)).any(
            (item) => item.kind == 'draft' && item.status != 'completed',
          )) {
        throw StateError(
          'Сначала отправьте сохранённые замечания или подтвердите их удаление.',
        );
      }
      for (final record in await store.records(scope)) {
        if (record.kind == 'draft') {
          await _deleteDraft(record);
        } else {
          await _deleteRecord(record);
        }
      }
      await files.clearIdentity(_owner(scope));
    } finally {
      _transitioning = false;
      _notify();
    }
  }

  Future<T> _mutate<T>(Future<T> Function() action) {
    final scope = _scope();
    final epoch = _epoch;
    final next = _mutations.then((_) async {
      _guard(scope, epoch);
      return action();
    });
    _mutations = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  void stopOperations() {
    ++_epoch;
    for (final token in _setTokens.values) {
      token.cancel();
    }
    for (final token in _downloads.values) {
      token.cancel();
    }
    _syncToken?.cancel();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stopOperations();
    unawaited(_changes.close());
  }

  bool _denied(Object error) =>
      error is DioException && [401, 403].contains(error.response?.statusCode);
  String _errorMessage(Object error) =>
      _denied(error)
          ? 'Доступ закрыт. Подтвердите права через интернет.'
          : error is FormatException
          ? error.message
          : error is StateError
          ? error.message
          : 'Операция не завершена. Повторите при доступном интернете.';
  String _randomKey() => base64UrlEncode(
    List<int>.generate(24, (_) => Random.secure().nextInt(256)),
  );
}
