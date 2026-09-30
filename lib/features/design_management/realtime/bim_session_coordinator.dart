import 'dart:async';
import 'dart:math';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import 'bim_realtime_viewer.dart';
import 'bim_session_models.dart';

class BimSessionCoordinator extends StateNotifier<BimSessionState> {
  BimSessionCoordinator({
    required BimSessionApi api,
    required BimRealtimeViewer viewer,
    required this.userId,
    required this.userName,
    String? clientId,
    DateTime Function()? now,
    this.heartbeatInterval = const Duration(seconds: 15),
    this.retryInterval = const Duration(milliseconds: 750),
  }) : _api = api,
       _viewer = viewer,
       clientId =
           clientId ??
           'mobile-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
       _now = now ?? DateTime.now,
       super(const BimSessionState()) {
    _subscription = _viewer.events.listen(
      _onViewerEvent,
      onError: _onTransportError,
    );
    _ready = _viewer.isReady;
  }

  final BimSessionApi _api;
  final BimRealtimeViewer _viewer;
  final int userId;
  final String userName;
  final String clientId;
  final DateTime Function() _now;
  final Duration heartbeatInterval;
  final Duration retryInterval;
  late final StreamSubscription<Map<String, dynamic>> _subscription;
  final _pending = <String, Map<String, dynamic>>{};
  final _cursorPending = <Map<String, dynamic>>[];
  final _sending = <String>{};
  final _lastSequence = <String, Map<String, int>>{};
  final _eventTimers = <String, Timer>{};
  Timer? _heartbeatTimer;
  Timer? _viewTimer;
  Timer? _followTimer;
  Completer<void>? _modelsReady;
  Completer<void>? _joinReady;
  bool _ready = false;
  bool _disposed = false;
  bool _online = true;
  bool _heartbeatRunning = false;
  int _generation = 0;
  int _joinRequest = 0;
  int _sequence = 0;
  int _followGeneration = 0;

  bool get online => _online;
  bool get rendererReady => _ready;
  BimSessionState get currentState => state;

  Future<void> join(BimSessionSummary session) async {
    if (_disposed || !_online) return;
    final request = ++_joinRequest;
    await _leave(invalidateJoinRequest: false);
    if (_disposed || !_online || request != _joinRequest) return;
    final generation = ++_generation;
    state = BimSessionState(
      session: session,
      connection: BimSessionConnection.joining,
    );
    try {
      final bootstrap = await _api.bootstrap(session.id, clientId: clientId);
      if (!_current(generation)) return;
      final revision = bimInt(bootstrap['model_set_revision_id']);
      if (revision != 0 && revision != session.modelSetRevisionId) {
        throw StateError(
          'Совместный просмотр относится к другой версии моделей.',
        );
      }
      if (bimMap(bootstrap['realtime'])['enabled'] == false) {
        throw StateError('Совместный просмотр временно недоступен.');
      }
      final participants = bootstrap['participants'];
      if (participants is List) {
        _updateParticipants(
          participants
              .map((value) => BimParticipant.fromJson(bimMap(value)))
              .toList(),
        );
      }
      final realtime = _publicRealtime(bimMap(bootstrap['realtime']));
      if (!_ready) {
        _joinReady ??= Completer<void>();
        await _joinReady!.future;
      }
      if (!_current(generation)) return;
      await _viewer.command('sessionStart', {
        'session_id': session.id,
        'model_set_revision_id': session.modelSetRevisionId,
        'client_id': clientId,
        'user': {'id': userId, 'name': userName},
        'channel': bootstrap['channel'] ?? realtime['channel'],
        'realtime': realtime,
      });
      if (!_current(generation)) return;
      _heartbeatTimer = Timer.periodic(
        heartbeatInterval,
        (_) => unawaited(_heartbeat(generation)),
      );
    } catch (error) {
      if (_current(generation)) {
        state = state.copyWith(
          connection: BimSessionConnection.failed,
          error: error,
        );
      }
    }
  }

  void setOnline(bool value) {
    if (_disposed || _online == value) return;
    _online = value;
    if (!value) {
      ++_joinRequest;
      _wakeJoinWaiter();
      stopFollowing(notice: 'Совместный просмотр приостановлен: нет сети.');
      _cancelTimers();
      _pending.clear();
      _cursorPending.clear();
      if (state.session != null) {
        state = state.copyWith(connection: BimSessionConnection.offline);
      }
      unawaited(_safeCommand('sessionStop'));
    } else if (state.session case final session?) {
      unawaited(join(session));
    }
  }

  Future<void> leave() => _leave(invalidateJoinRequest: true);

  Future<void> _leave({required bool invalidateJoinRequest}) async {
    if (invalidateJoinRequest) ++_joinRequest;
    _wakeJoinWaiter();
    final session = state.session;
    ++_generation;
    ++_followGeneration;
    _cancelTimers();
    _pending.clear();
    _cursorPending.clear();
    _sending.clear();
    _lastSequence.clear();
    if (!_disposed) state = const BimSessionState();
    await _safeCommand('cancelRemoteView');
    await _safeCommand('sessionStop');
    await _safeCommand('clearRemote');
    if (session != null && _online) {
      try {
        await _api.leave(session.id, clientId: clientId, sequence: ++_sequence);
      } catch (_) {}
    }
  }

  Future<void> follow(String leaderClientId) async {
    if (_disposed ||
        !_online ||
        state.connection != BimSessionConnection.connected ||
        leaderClientId == clientId) {
      return;
    }
    if (!state.participants.any(
      (participant) => participant.clientId == leaderClientId,
    )) {
      return;
    }
    final generation = ++_followGeneration;
    _followTimer?.cancel();
    state = state.copyWith(
      followingClientId: leaderClientId,
      followLoading: true,
      clearError: true,
    );
    _pending.remove('camera');
    _pending.remove('select');
    _viewTimer?.cancel();
    try {
      await _safeCommand('cancelRemoteView');
      if (!_following(leaderClientId, generation)) return;
      await _applyLeaderView(leaderClientId, generation);
      if (!_following(leaderClientId, generation)) return;
      state = state.copyWith(followLoading: false);
      _followTimer?.cancel();
      _followTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(_refreshFollow(leaderClientId, generation)),
      );
    } catch (error) {
      if (_following(leaderClientId, generation)) {
        state = state.copyWith(
          clearFollow: true,
          followLoading: false,
          error: error,
          notice: 'Не удалось получить вид участника.',
        );
      }
    }
  }

  void stopFollowing({String? notice}) {
    if (_disposed) return;
    ++_followGeneration;
    _followTimer?.cancel();
    unawaited(_safeCommand('cancelRemoteView'));
    state = state.copyWith(
      clearFollow: true,
      followLoading: false,
      notice: notice,
    );
  }

  bool _followRefreshing = false;
  Future<void> _refreshFollow(String leaderClientId, int generation) async {
    if (_followRefreshing || !_following(leaderClientId, generation)) return;
    _followRefreshing = true;
    try {
      await _applyLeaderView(leaderClientId, generation);
    } catch (_) {
    } finally {
      _followRefreshing = false;
    }
  }

  Future<void> _applyLeaderView(String leaderClientId, int generation) async {
    final session = state.session;
    if (session == null) return;
    final view = await _api.fetchViewState(session.id, leaderClientId);
    if (!_following(leaderClientId, generation)) return;
    if (view == null) throw StateError('Участник ещё не передал свой вид.');
    if (!_ready) {
      _modelsReady ??= Completer<void>();
      await _modelsReady!.future;
    }
    if (!_following(leaderClientId, generation)) return;
    await _viewer.applyViewState(view);
  }

  bool _following(String leader, int generation) =>
      !_disposed &&
      _online &&
      _followGeneration == generation &&
      state.followingClientId == leader;
  bool _current(int generation) =>
      !_disposed &&
      _online &&
      _generation == generation &&
      state.session != null;

  void _wakeJoinWaiter() {
    final waiter = _joinReady;
    _joinReady = null;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  void _onViewerEvent(Map<String, dynamic> event) {
    if (_disposed) return;
    final type = event['type'];
    final payload = bimMap(event['payload']);
    if (type == 'ready') {
      final changed = !_ready;
      _ready = true;
      if (!(_modelsReady?.isCompleted ?? true)) _modelsReady!.complete();
      _wakeJoinWaiter();
      if (changed) state = state.copyWith();
      return;
    }
    if (type == 'loading') {
      final changed = _ready;
      _ready = false;
      if (_modelsReady?.isCompleted == true) _modelsReady = null;
      if (changed) state = state.copyWith();
      return;
    }
    if (state.session == null || !_online) return;
    switch (type) {
      case 'presenceSubscribed':
      case 'sessionSubscribed':
      case 'sessionReconnect':
        state = state.copyWith(
          connection: BimSessionConnection.connected,
          clearError: true,
        );
        unawaited(_reconcile(_generation));
      case 'presenceDisconnected':
        state = state.copyWith(connection: BimSessionConnection.reconnecting);
      case 'presenceError':
        stopFollowing();
        _viewTimer?.cancel();
        _lastSequence.clear();
        state = state.copyWith(
          connection: BimSessionConnection.failed,
          error: const ApiException(
            'Не удалось подключиться к совместному просмотру. Завершите участие и войдите снова.',
          ),
        );
        unawaited(_safeCommand('clearRemote'));
      case 'participantsChanged':
        final values = payload['participants'];
        if (values is List) {
          _updateParticipants(
            values
                .map((value) => BimParticipant.fromJson(bimMap(value)))
                .toList(),
          );
        }
      case 'presenceMemberLeft':
        final departedClient = (payload['client_id'] ?? '').toString();
        if (departedClient.isNotEmpty) _removeParticipant(departedClient);
        unawaited(_heartbeat(_generation));
      case 'presence':
      case 'presenceEvent':
        final envelope = BimPresenceEnvelope.tryParse(event['payload']);
        if (envelope != null) unawaited(_receive(envelope));
      case 'interaction':
        if (state.followingClientId != null) {
          stopFollowing(notice: 'Вы продолжили просмотр самостоятельно.');
        }
      case 'camera':
      case 'selection':
      case 'cursor':
        if (payload['source'] == 'remote' || event['source'] == 'remote') {
          return;
        }
        if (state.followingClientId != null && type != 'cursor') {
          stopFollowing(notice: 'Вы продолжили просмотр самостоятельно.');
        }
        _queue(type == 'selection' ? 'select' : type as String, payload);
        if (type != 'cursor') _scheduleViewState();
      case 'viewChanged':
        if (payload['source'] == 'remote' || event['source'] == 'remote') {
          return;
        }
        if (state.followingClientId != null) {
          stopFollowing(notice: 'Вы продолжили просмотр самостоятельно.');
        }
        _scheduleViewState();
    }
  }

  Future<void> _reconcile(int generation) async {
    await _heartbeat(generation);
    if (!_current(generation)) return;
    try {
      final snapshots = await _api.fetchSnapshots(state.session!.id);
      if (!_current(generation)) return;
      for (final snapshot in snapshots) {
        if (!_current(generation)) return;
        await _receive(snapshot);
      }
      if (!_current(generation)) return;
      for (final type in _pending.keys.toList()) {
        unawaited(_flush(type, generation));
      }
      if (_cursorPending.isNotEmpty) {
        unawaited(_flush('cursor', generation));
      }
      _scheduleViewState();
      if (state.followingClientId case final leader?) {
        unawaited(_refreshFollow(leader, _followGeneration));
      }
    } catch (error) {
      if (_current(generation)) state = state.copyWith(error: error);
    }
  }

  Future<void> _heartbeat(int generation) async {
    if (!_current(generation) || _heartbeatRunning) return;
    _heartbeatRunning = true;
    try {
      final participants = await _api.heartbeat(
        state.session!.id,
        clientId: clientId,
        sequence: ++_sequence,
      );
      if (_current(generation)) _updateParticipants(participants);
    } catch (error) {
      if (_current(generation)) state = state.copyWith(error: error);
    } finally {
      _heartbeatRunning = false;
    }
  }

  void _updateParticipants(List<BimParticipant> participants) {
    if (_disposed) return;
    final cutoff = _now().subtract(const Duration(seconds: 45));
    final active =
        participants
            .where(
              (participant) =>
                  participant.clientId.isNotEmpty &&
                  (participant.lastSeenAt == null ||
                      !participant.lastSeenAt!.isBefore(cutoff)),
            )
            .toList();
    for (final participant in state.participants) {
      if (!active.any((value) => value.clientId == participant.clientId)) {
        unawaited(
          _safeCommand('clearRemote', {'client_id': participant.clientId}),
        );
      }
    }
    final leader = state.followingClientId;
    state = state.copyWith(participants: List.unmodifiable(active));
    if (leader != null && !active.any((value) => value.clientId == leader)) {
      stopFollowing(
        notice: 'Участник покинул совместный просмотр. Текущий вид сохранён.',
      );
    }
  }

  void _removeParticipant(String departedClient) {
    _lastSequence.remove(departedClient);
    _updateParticipants(
      state.participants
          .where((value) => value.clientId != departedClient)
          .toList(),
    );
    unawaited(_safeCommand('clearRemote', {'client_id': departedClient}));
  }

  Future<void> _receive(BimPresenceEnvelope event) async {
    final session = state.session;
    if (_disposed ||
        !_online ||
        state.connection != BimSessionConnection.connected ||
        session == null ||
        event.sessionId != session.id ||
        event.modelSetRevisionId != session.modelSetRevisionId ||
        event.clientId == clientId) {
      return;
    }
    final sequences = _lastSequence.putIfAbsent(
      event.clientId,
      () => <String, int>{},
    );
    if (event.sequence <= (sequences[event.type] ?? 0)) return;
    sequences[event.type] = event.sequence;
    final participant =
        state.participants
            .where((value) => value.clientId == event.clientId)
            .firstOrNull;
    final metadata = {
      'client_id': event.clientId,
      'label': participant?.name ?? event.senderName,
      'color': participant?.color ?? '#3b82f6',
    };
    try {
      switch (event.type) {
        case 'camera':
          if (state.followingClientId == event.clientId &&
              !state.followLoading) {
            await _viewer.command('remoteCamera', {
              ...metadata,
              'camera': event.payload['camera'] ?? event.payload,
              'follow': true,
            });
          }
        case 'cursor':
          await _viewer.command('remoteCursor', {
            ...metadata,
            'position':
                event.payload['position'] ??
                event.payload['cursor'] ??
                (event.payload.isEmpty ? null : event.payload),
          });
        case 'select':
          final versionId = bimInt(event.payload['model_version_id']);
          final element = event.payload['element_id'];
          await _viewer.command('remoteSelection', {
            ...metadata,
            'selection':
                element == null
                    ? []
                    : [
                      {'version_id': versionId, 'express_id': bimInt(element)},
                    ],
          });
        case 'view':
          if (state.followingClientId == event.clientId) {
            unawaited(_refreshFollow(event.clientId, _followGeneration));
          }
      }
    } catch (_) {}
  }

  void _queue(String type, Map<String, dynamic> payload) {
    if (!_online || state.session == null) return;
    final queued = Map<String, dynamic>.of(payload)..remove('source');
    if (type == 'cursor') {
      if (_cursorClear(queued)) {
        if (_cursorPending.isNotEmpty && _cursorClear(_cursorPending.last)) {
          _cursorPending.removeLast();
        }
        _cursorPending.add(queued);
      } else {
        _cursorPending
          ..clear()
          ..add(queued);
      }
    } else {
      _pending[type] = queued;
    }
    if (_sending.contains(type) || (_eventTimers[type]?.isActive ?? false)) {
      return;
    }
    final delay = switch (type) {
      'camera' => const Duration(milliseconds: 100),
      'cursor' => const Duration(milliseconds: 70),
      _ => Duration.zero,
    };
    _eventTimers[type] = Timer(
      delay,
      () => unawaited(_flush(type, _generation)),
    );
  }

  Future<void> _flush(String type, int generation) async {
    if (!_current(generation) ||
        state.connection != BimSessionConnection.connected ||
        _sending.contains(type)) {
      return;
    }
    final payload =
        type == 'cursor'
            ? (_cursorPending.isEmpty ? null : _cursorPending.removeAt(0))
            : _pending.remove(type);
    if (payload == null) return;
    final wirePayload = _wirePayload(type, payload);
    if (wirePayload == null) return;
    final session = state.session!;
    _sending.add(type);
    var failed = false;
    try {
      final envelope =
          BimPresenceEnvelope(
            sessionId: session.id,
            modelSetRevisionId: session.modelSetRevisionId,
            clientId: clientId,
            sequence: ++_sequence,
            type: type,
            senderId: userId,
            senderName: userName,
            occurredAt: _now(),
            payload: wirePayload,
          ).toJson();
      if (type == 'cursor' &&
          payload['position'] == null &&
          payload['cursor'] == null &&
          !payload.containsKey('x')) {
        envelope['payload'] = null;
      }
      await _api.sendEvent(session.id, envelope);
    } catch (error) {
      failed = true;
      if (_current(generation)) {
        if (type == 'cursor') {
          if (_cursorPending.isEmpty ||
              (!_cursorClear(payload) && _cursorClear(_cursorPending.first))) {
            _cursorPending.insert(0, payload);
          }
        } else {
          _pending.putIfAbsent(type, () => payload);
        }
        state = state.copyWith(error: error);
      }
    } finally {
      if (_current(generation)) {
        _sending.remove(type);
        if (type == 'cursor'
            ? _cursorPending.isNotEmpty
            : _pending.containsKey(type)) {
          _eventTimers[type] = Timer(
            failed ? retryInterval : Duration.zero,
            () => unawaited(_flush(type, generation)),
          );
        }
      }
    }
  }

  bool _cursorClear(Map<String, dynamic> payload) =>
      payload['position'] == null &&
      payload['cursor'] == null &&
      !payload.containsKey('x');

  void _scheduleViewState() {
    _viewTimer?.cancel();
    if (!_online ||
        state.connection != BimSessionConnection.connected ||
        state.followingClientId != null) {
      return;
    }
    _viewTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_publishViewState(_generation)),
    );
  }

  bool _viewPublishing = false;
  bool _viewDirty = false;
  Future<void> _publishViewState(int generation) async {
    if (!_current(generation) ||
        !_ready ||
        state.connection != BimSessionConnection.connected ||
        state.followingClientId != null) {
      return;
    }
    if (_viewPublishing) {
      _viewDirty = true;
      return;
    }
    _viewPublishing = true;
    try {
      final view = await _viewer.getViewState();
      if (_current(generation) &&
          state.connection == BimSessionConnection.connected &&
          state.followingClientId == null) {
        await _api.publishViewState(
          state.session!.id,
          clientId,
          ++_sequence,
          view,
        );
      }
    } catch (error) {
      if (_current(generation)) {
        state = state.copyWith(error: error);
        _viewDirty = true;
      }
    } finally {
      _viewPublishing = false;
      if (_viewDirty && _current(generation)) {
        _viewDirty = false;
        _viewTimer = Timer(
          retryInterval,
          () => unawaited(_publishViewState(generation)),
        );
      }
    }
  }

  void _onTransportError(Object error) {
    if (!_disposed && state.session != null) {
      state = state.copyWith(
        connection: BimSessionConnection.reconnecting,
        error: error,
      );
    }
  }

  Future<void> _safeCommand(
    String type, [
    Map<String, dynamic> payload = const {},
  ]) async {
    try {
      await _viewer.command(type, payload);
    } catch (_) {}
  }

  Map<String, dynamic> _publicRealtime(Map<String, dynamic> config) => {
    for (final key in [
      'enabled',
      'event',
      'schema_version',
      'broadcaster',
      'key',
      'app_key',
      'host',
      'wsHost',
      'wsPort',
      'wssPort',
      'port',
      'scheme',
      'forceTLS',
      'encrypted',
      'cluster',
      'enabledTransports',
      'channel',
      'channel_name',
    ])
      if (config.containsKey(key)) key: config[key],
  };

  Map<String, dynamic>? _wirePayload(
    String type,
    Map<String, dynamic> payload,
  ) {
    if (type == 'camera') return bimMap(payload['camera'] ?? payload);
    if (type == 'cursor') {
      return bimMap(payload['position'] ?? payload['cursor'] ?? payload);
    }
    if (type == 'select') {
      final selection = payload['selection'];
      final selected =
          selection is List && selection.isNotEmpty
              ? bimMap(selection.first)
              : bimMap(selection ?? payload);
      final element =
          selected['express_id'] ??
          selected['expressId'] ??
          selected['element_id'];
      final version = selected['version_id'] ?? selected['model_version_id'];
      if (version == null && element == null) {
        return {'model_version_id': null, 'element_id': null};
      }
      final versionId = _positiveId(version);
      final elementId = element == null ? null : _positiveId(element);
      if (versionId == null || (element != null && elementId == null)) {
        return null;
      }
      return {'model_version_id': versionId, 'element_id': elementId};
    }
    return payload;
  }

  int? _positiveId(Object? value) {
    if (value is String && !RegExp(r'^[0-9]+$').hasMatch(value)) return null;
    if (value is! String && value is! num) return null;
    if (value is num && !value.isFinite) return null;
    final parsed = bimInt(value);
    if (parsed <= 0 || (value is num && value != parsed)) return null;
    return parsed;
  }

  void _cancelTimers() {
    _heartbeatTimer?.cancel();
    _viewTimer?.cancel();
    _followTimer?.cancel();
    for (final timer in _eventTimers.values) {
      timer.cancel();
    }
    _eventTimers.clear();
  }

  @override
  void dispose() {
    if (_disposed) return;
    final session = state.session;
    _disposed = true;
    ++_joinRequest;
    ++_generation;
    ++_followGeneration;
    _cancelTimers();
    _pending.clear();
    _cursorPending.clear();
    _wakeJoinWaiter();
    if (!(_modelsReady?.isCompleted ?? true)) _modelsReady!.complete();
    unawaited(_subscription.cancel());
    unawaited(_safeCommand('cancelRemoteView'));
    unawaited(_safeCommand('sessionStop'));
    unawaited(_safeCommand('clearRemote'));
    if (session != null && _online) {
      unawaited(
        _api
            .leave(session.id, clientId: clientId, sequence: ++_sequence)
            .catchError((Object _) {}),
      );
    }
    super.dispose();
  }
}
