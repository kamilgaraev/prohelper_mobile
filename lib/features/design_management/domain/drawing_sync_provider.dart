import 'dart:async';
import 'dart:math';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/domain/auth_provider.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/bim_repository.dart';
import '../data/drawing_annotations.dart';
import '../data/drawing_sync_models.dart';

typedef DrawingSyncKey =
    ({int projectId, int versionId, Object sessionIdentity});

final drawingSyncProvider = StateNotifierProvider.autoDispose
    .family<DrawingSyncNotifier, DrawingSyncState, DrawingSyncKey>((ref, key) {
      final identity = ref.watch(
        authProvider.select(
          (state) => state is AuthAuthenticated ? state.sessionIdentity : null,
        ),
      );
      final project = ref.watch(
        projectsProvider.select((state) => state.selectedProject?.serverId),
      );
      final auth = ref.read(authProvider);
      final notifier = DrawingSyncNotifier(
        ref.watch(bimRepositoryProvider),
        key.versionId,
        authorId: identity?.userId ?? 0,
        authorName:
            auth is AuthAuthenticated ? auth.user.name : 'Участник проекта',
      );
      if (identity != null &&
          identity == key.sessionIdentity &&
          project == key.projectId) {
        notifier.start();
      }
      return notifier;
    });

class DrawingSyncState {
  const DrawingSyncState({
    this.items = const [],
    this.pending = 0,
    this.saving = false,
    this.loading = true,
    this.saveError,
    this.readError,
    this.canAnnotate,
  });
  final List<SyncedDrawingStroke> items;
  final int pending;
  final bool saving;
  final bool loading;
  final String? saveError;
  final String? readError;
  final bool? canAnnotate;
}

class _DrawingOperation {
  _DrawingOperation(this.clientId, {this.annotations, this.remove = false})
    : createdAt = DateTime.now().toUtc();
  final String clientId;
  final DrawingAnnotations? annotations;
  final bool remove;
  final DateTime createdAt;
  bool attempted = false;
}

class DrawingSyncNotifier extends StateNotifier<DrawingSyncState> {
  DrawingSyncNotifier(
    this.api,
    this.versionId, {
    required this.authorId,
    required this.authorName,
  }) : super(const DrawingSyncState());
  final DrawingStrokeApi api;
  final int versionId;
  final int authorId;
  final String authorName;
  final _records = <String, SyncedDrawingStroke>{};
  final _queue = <_DrawingOperation>[];
  int _cursor = 0;
  int _epoch = 0;
  bool _active = false;
  bool _alive = true;
  Timer? _timer;
  Future<bool>? _writing;
  Future<void>? _reading;
  _DrawingOperation? _operation;

  void start({bool poll = true}) {
    _active = true;
    _epoch++;
    if (poll) setForeground(true);
  }

  void setForeground(bool foreground) {
    _timer?.cancel();
    _timer = null;
    if (!_active || !_alive || !foreground) return;
    refresh();
    flush();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      refresh();
      flush();
    });
  }

  void add(DrawingAnnotations annotations) {
    if (!_active || !_alive) return;
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    _queue.add(_DrawingOperation(id, annotations: annotations));
    _publish();
    flush();
  }

  void remove(String clientId) {
    if (!_active ||
        !_alive ||
        _queue.any((item) => item.remove && item.clientId == clientId)) {
      return;
    }
    final record =
        state.items.where((item) => item.clientId == clientId).firstOrNull;
    if (record == null || !record.canDelete) return;
    final create =
        _queue
            .where((item) => !item.remove && item.clientId == clientId)
            .firstOrNull;
    if (create != null && create != _operation) _queue.remove(create);
    if (create == null || create.attempted) {
      _queue.add(_DrawingOperation(clientId, remove: true));
    }
    _publish(clearSaveError: true);
    flush();
  }

  Future<bool> flush() {
    if (_writing != null) return _writing!;
    if (!_active || !_alive) return Future.value(false);
    if (_queue.isEmpty) return Future.value(true);
    if (state.canAnnotate == false) {
      _publish(
        saveError:
            'Рисование недоступно для вашей роли. Несохранённые штрихи остаются на экране.',
      );
      return Future.value(false);
    }
    return _writing = _drain(_epoch).whenComplete(() => _writing = null);
  }

  Future<bool> _drain(int epoch) async {
    _publish(saving: true, clearSaveError: true);
    try {
      while (_queue.isNotEmpty && _active && _alive && epoch == _epoch) {
        final operation = _queue.first;
        _operation = operation;
        operation.attempted = true;
        try {
          final record =
              operation.remove
                  ? await api.deleteDrawingStroke(versionId, operation.clientId)
                  : await api.createDrawingStroke(
                    versionId,
                    operation.clientId,
                    operation.annotations!,
                  );
          if (!_active || !_alive || epoch != _epoch) return false;
          _merge(record);
          _queue.remove(operation);
          _publish();
        } catch (error) {
          if (!_active || !_alive || epoch != _epoch) return false;
          if (!operation.remove &&
              _queue.any(
                (item) => item.remove && item.clientId == operation.clientId,
              )) {
            _queue.remove(operation);
            continue;
          }
          _publish(
            saveError:
                error is ApiException
                    ? error.message
                    : 'Не удалось сохранить рисунки. Повторите отправку.',
          );
          return false;
        }
      }
      return _active && _alive && epoch == _epoch && _queue.isEmpty;
    } finally {
      _operation = null;
      if (_active && _alive && epoch == _epoch) _publish(saving: false);
    }
  }

  Future<void> refresh() {
    if (_reading != null) return _reading!;
    if (!_active || !_alive) return Future.value();
    return _reading = _read(_epoch).whenComplete(() => _reading = null);
  }

  Future<void> _read(int epoch) async {
    try {
      while (_active && _alive && epoch == _epoch) {
        final delta = await api.drawingChanges(versionId, _cursor);
        if (!_active || !_alive || epoch != _epoch) return;
        if (delta.revision < _cursor ||
            (delta.hasMore && delta.revision <= _cursor)) {
          throw const FormatException('Invalid drawing cursor');
        }
        for (final item in delta.items) {
          _merge(item);
        }
        _cursor = delta.revision;
        _publish(
          loading: false,
          clearReadError: true,
          canAnnotate: delta.canAnnotate,
        );
        if (!delta.hasMore) return;
      }
    } catch (error) {
      if (_active && _alive && epoch == _epoch) {
        _publish(
          loading: false,
          readError:
              error is ApiException
                  ? error.message
                  : 'Не удалось обновить общую разметку. Повторим загрузку автоматически.',
        );
      }
    }
  }

  void _merge(SyncedDrawingStroke record) {
    final previous = _records[record.clientId];
    if (previous == null || record.revision >= previous.revision) {
      _records[record.clientId] = record;
    }
  }

  void _publish({
    bool? saving,
    bool? loading,
    String? saveError,
    String? readError,
    bool clearSaveError = false,
    bool clearReadError = false,
    bool? canAnnotate,
  }) {
    if (!_alive) return;
    final projected = Map<String, SyncedDrawingStroke>.of(_records);
    final pending = <String>{};
    for (final operation in _queue) {
      pending.add(operation.clientId);
      if (operation.remove) {
        projected.remove(operation.clientId);
        continue;
      }
      projected.putIfAbsent(
        operation.clientId,
        () => SyncedDrawingStroke(
          clientId: operation.clientId,
          versionId: versionId,
          revision: 0,
          authorId: authorId,
          authorName: authorName,
          createdAt: operation.createdAt,
          canDelete: true,
          annotations: operation.annotations,
        ),
      );
    }
    final items =
        projected.values
            .where((item) => item.deletedAt == null && item.annotations != null)
            .map((item) => item.withPending(pending.contains(item.clientId)))
            .toList()
          ..sort((a, b) {
            if (a.revision > 0 && b.revision > 0) {
              return a.revision.compareTo(b.revision);
            }
            if (a.revision > 0) return -1;
            if (b.revision > 0) return 1;
            return _queue
                .indexWhere((item) => item.clientId == a.clientId)
                .compareTo(
                  _queue.indexWhere((item) => item.clientId == b.clientId),
                );
          });
    state = DrawingSyncState(
      items: List.unmodifiable(items),
      pending: _queue.length,
      saving: saving ?? state.saving,
      loading: loading ?? state.loading,
      canAnnotate: canAnnotate ?? state.canAnnotate,
      saveError: clearSaveError ? null : saveError ?? state.saveError,
      readError: clearReadError ? null : readError ?? state.readError,
    );
  }

  @override
  void dispose() {
    _alive = false;
    _active = false;
    _epoch++;
    _timer?.cancel();
    super.dispose();
  }
}
