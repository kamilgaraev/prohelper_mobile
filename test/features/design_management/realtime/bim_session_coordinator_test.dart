import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/design_management/realtime/bim_realtime_viewer.dart';
import 'package:prohelpers_mobile/features/design_management/realtime/bim_session_coordinator.dart';
import 'package:prohelpers_mobile/features/design_management/realtime/bim_session_models.dart';

const session = BimSessionSummary(id: 4, name: 'Разбор', modelSetRevisionId: 9);
const leader = BimParticipant(
  clientId: 'second-device',
  userId: 7,
  name: 'Анна',
  color: '#123456',
);

void main() {
  testWidgets(
    'presence error after join reports failure and actual subscription restores queued selection',
    (tester) async {
      final api = _Api();
      final viewer = _Viewer();
      final coordinator = _coordinator(api, viewer);
      await coordinator.join(session);
      expect(coordinator.currentState.connection, BimSessionConnection.joining);
      expect(api.snapshotReads, 0);
      viewer.emit('presenceError');
      expect(coordinator.currentState.connection, BimSessionConnection.failed);
      expect(
        coordinator.currentState.error.toString(),
        contains('Не удалось подключиться к совместному просмотру'),
      );
      expect(coordinator.currentState.session, session);
      expect(viewer.commands.last.$1, 'clearRemote');
      viewer.emit('selection', {'version_id': 10, 'element_id': 42});
      viewer.emit('selection');
      await tester.pump(const Duration(seconds: 1));
      expect(api.sent, isEmpty);
      viewer.emit('presenceDisconnected');
      expect(
        coordinator.currentState.connection,
        BimSessionConnection.reconnecting,
      );
      expect(coordinator.currentState.error, isNotNull);
      viewer.emit('presenceSubscribed');
      await tester.pump();
      expect(
        coordinator.currentState.connection,
        BimSessionConnection.connected,
      );
      expect(coordinator.currentState.error, isNull);
      expect(api.snapshotReads, 1);
      expect(api.sent.single['payload'], {
        'model_version_id': null,
        'element_id': null,
      });
      coordinator.dispose();
      await tester.pump();
      await viewer.close();
    },
  );

  testWidgets(
    'presence error cancels pending follow and restores cleared remotes only after subscription',
    (tester) async {
      final api =
          _Api()
            ..snapshots = [
              _event('cursor', 8, {'x': 1, 'y': 2, 'z': 3}),
            ];
      final viewer = _Viewer()..blockedApply = Completer<void>();
      final coordinator = _coordinator(api, viewer);
      viewer.emit('ready');
      await coordinator.join(session);
      viewer.emit('presenceSubscribed');
      await tester.pump();
      final following = coordinator.follow(leader.clientId);
      await tester.pump();
      expect(coordinator.currentState.followLoading, isTrue);
      final clearCount =
          viewer.commands
              .where((command) => command.$1 == 'clearRemote')
              .length;
      final cancelCount =
          viewer.commands
              .where((command) => command.$1 == 'cancelRemoteView')
              .length;
      viewer.emit('presenceError');
      expect(coordinator.currentState.connection, BimSessionConnection.failed);
      expect(coordinator.currentState.followingClientId, isNull);
      expect(coordinator.currentState.followLoading, isFalse);
      expect(
        viewer.commands.where((command) => command.$1 == 'clearRemote').length,
        clearCount + 1,
      );
      expect(
        viewer.commands
            .where((command) => command.$1 == 'cancelRemoteView')
            .length,
        cancelCount + 1,
      );
      viewer.blockedApply!.complete();
      await following;
      viewer.emit(
        'presence',
        _event('cursor', 9, {'x': 4, 'y': 5, 'z': 6}).toJson(),
      );
      viewer.emit('viewChanged');
      await tester.pump(const Duration(seconds: 2));
      expect(viewer.applied, isEmpty);
      expect(api.viewWrites, 0);
      expect(
        viewer.commands.where((command) => command.$1 == 'remoteCursor').length,
        1,
      );
      viewer.emit('presenceSubscribed');
      await tester.pump();
      expect(coordinator.currentState.error, isNull);
      expect(coordinator.currentState.followingClientId, isNull);
      expect(api.snapshotReads, 2);
      expect(
        viewer.commands.where((command) => command.$1 == 'remoteCursor').length,
        2,
      );
      expect(viewer.applied, isEmpty);
      coordinator.dispose();
      await tester.pump();
      await viewer.close();
    },
  );

  testWidgets(
    'subscription and reconnect restore per-type latest snapshots and keep same-user devices',
    (tester) async {
      final api =
          _Api()
            ..snapshots = [
              _event('select', 5, {'model_version_id': 10, 'element_id': '42'}),
            ];
      final viewer = _Viewer();
      final coordinator = _coordinator(api, viewer);
      await coordinator.join(session);
      viewer.emit('presenceSubscribed');
      await tester.pump();
      expect(api.snapshotReads, 1);
      expect(
        viewer.commands
            .where((value) => value.$1 == 'remoteSelection')
            .last
            .$2['selection'],
        [
          {'version_id': 10, 'express_id': 42},
        ],
      );
      viewer.emit(
        'presence',
        _event('cursor', 1, {'x': 1, 'y': 2, 'z': 3}).toJson(),
      );
      viewer.emit(
        'presence',
        _event('select', 4, {
          'model_version_id': 10,
          'element_id': '99',
        }).toJson(),
      );
      viewer.emit(
        'presence',
        _event('select', 6, {
          'model_version_id': 10,
          'element_id': '88',
        }, clientId: 'own').toJson(),
      );
      await tester.pump();
      expect(
        viewer.commands.where((value) => value.$1 == 'remoteSelection').length,
        1,
      );
      expect(
        viewer.commands
            .where((value) => value.$1 == 'remoteCursor')
            .last
            .$2['position'],
        {'x': 1, 'y': 2, 'z': 3},
      );
      api.snapshots = [
        _event('select', 7, {'model_version_id': null, 'element_id': null}),
      ];
      viewer.emit('presenceDisconnected');
      expect(
        coordinator.currentState.connection,
        BimSessionConnection.reconnecting,
      );
      viewer.emit('presenceSubscribed');
      await tester.pump();
      expect(api.snapshotReads, 2);
      expect(
        viewer.commands
            .where((value) => value.$1 == 'remoteSelection')
            .last
            .$2['selection'],
        isEmpty,
      );
      coordinator.dispose();
      await tester.pump();
      await viewer.close();
    },
  );

  testWidgets(
    'failed selection keeps latest clear while camera and cursor send independently',
    (tester) async {
      final api = _Api()..blockedSelect = Completer<void>();
      final viewer = _Viewer();
      final coordinator = _coordinator(api, viewer);
      await coordinator.join(session);
      viewer.emit('presenceSubscribed');
      await tester.pump();
      viewer.emit('selection', {'version_id': 10, 'element_id': 42});
      await tester.pump();
      viewer.emit('selection');
      viewer.emit('camera', {
        'position': [1, 2, 3],
      });
      viewer.emit('cursor', {
        'position': {'x': 1, 'y': 2, 'z': 3},
      });
      await tester.pump(const Duration(milliseconds: 101));
      expect(
        api.sent.map((value) => value['type']),
        containsAll(['camera', 'cursor', 'select']),
      );
      api.blockedSelect!.completeError(StateError('Temporary failure'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 751));
      final selected =
          api.sent.where((value) => value['type'] == 'select').last;
      expect(selected['payload'], {
        'model_version_id': null,
        'element_id': null,
      });
      coordinator.dispose();
      await tester.pump();
      await viewer.close();
    },
  );

  testWidgets('cursor hit reaches API before clear after a slow cursor clear', (
    tester,
  ) async {
    final api = _Api()..blockedCursorClear = Completer<void>();
    final viewer = _Viewer();
    final coordinator = _coordinator(api, viewer);
    await coordinator.join(session);
    viewer.emit('presenceSubscribed');
    await tester.pump();

    viewer.emit('cursor');
    await tester.pump(const Duration(milliseconds: 71));
    expect(api.sent.where((event) => event['type'] == 'cursor').length, 1);
    expect(api.sent.last['payload'], isNull);

    viewer.emit('cursor', {
      'position': {'x': 1, 'y': 2, 'z': 3},
    });
    viewer.emit('cursor');
    api.blockedCursorClear!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    final cursorEvents =
        api.sent.where((event) => event['type'] == 'cursor').toList();
    expect(cursorEvents.map((event) => event['payload']), [
      null,
      {'x': 1, 'y': 2, 'z': 3},
      null,
    ]);
    coordinator.dispose();
    await tester.pump();
    await viewer.close();
  });

  testWidgets('failed cursor hit retries before the queued clear', (
    tester,
  ) async {
    final api = _Api()..blockedCursorHit = Completer<void>();
    final viewer = _Viewer();
    final coordinator = _coordinator(api, viewer);
    await coordinator.join(session);
    viewer.emit('presenceSubscribed');
    await tester.pump();

    viewer.emit('cursor', {
      'position': {'x': 4, 'y': 5, 'z': 6},
    });
    await tester.pump(const Duration(milliseconds: 71));
    viewer.emit('cursor');
    api.blockedCursorHit!.completeError(StateError('Temporary failure'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 751));

    final cursorEvents =
        api.sent.where((event) => event['type'] == 'cursor').toList();
    expect(cursorEvents.map((event) => event['payload']), [
      {'x': 4, 'y': 5, 'z': 6},
      {'x': 4, 'y': 5, 'z': 6},
      null,
    ]);
    coordinator.dispose();
    await tester.pump();
    await viewer.close();
  });

  testWidgets(
    'follow waits for models, applies full state without feedback and own interaction keeps current view',
    (tester) async {
      final api = _Api();
      final viewer = _Viewer()..feedbackDuringApply = true;
      final coordinator = _coordinator(api, viewer);
      await coordinator.join(session);
      viewer.emit('presenceSubscribed');
      await tester.pump();
      viewer.emit('loading');
      final following = coordinator.follow(leader.clientId);
      await tester.pump();
      expect(coordinator.currentState.followLoading, isTrue);
      expect(viewer.applied, isEmpty);
      viewer.emit('ready');
      await following;
      await tester.pump(const Duration(milliseconds: 350));
      expect(viewer.applied.single, api.view);
      expect(coordinator.currentState.followingClientId, leader.clientId);
      expect(api.sent, isEmpty);
      expect(api.viewWrites, 0);
      viewer.emit('interaction', {'kind': 'section'});
      expect(coordinator.currentState.followingClientId, isNull);
      expect(viewer.commands.where((value) => value.$1 == 'fit'), isEmpty);
      expect(viewer.applied.length, 1);
      coordinator.dispose();
      await tester.pump();
      await viewer.close();
    },
  );

  testWidgets('leader leave stops follow and preserves full view', (
    tester,
  ) async {
    final api = _Api();
    final viewer = _Viewer();
    final coordinator = _coordinator(api, viewer);
    viewer.emit('ready');
    await coordinator.join(session);
    viewer.emit('presenceSubscribed');
    await tester.pump();
    await coordinator.follow(leader.clientId);
    api.participants = [];
    viewer.emit('presenceMemberLeft', {'client_id': leader.clientId});
    await tester.pump();
    expect(coordinator.currentState.followingClientId, isNull);
    expect(coordinator.currentState.notice, contains('Текущий вид сохранён'));
    expect(viewer.applied.length, 1);
    coordinator.dispose();
    await tester.pump();
    await viewer.close();
  });

  testWidgets(
    'own selection cancels a slow remote full view before it can overwrite the current view',
    (tester) async {
      final api = _Api();
      final viewer = _Viewer()..blockedApply = Completer<void>();
      final coordinator = _coordinator(api, viewer);
      viewer.emit('ready');
      await coordinator.join(session);
      viewer.emit('presenceSubscribed');
      await tester.pump();
      final following = coordinator.follow(leader.clientId);
      await tester.pump();
      expect(coordinator.currentState.followingClientId, leader.clientId);
      final cancellations =
          viewer.commands
              .where((command) => command.$1 == 'cancelRemoteView')
              .length;
      viewer.emit('selection', {'version_id': 10, 'element_id': 77});
      expect(coordinator.currentState.followingClientId, isNull);
      expect(
        viewer.commands
            .where((command) => command.$1 == 'cancelRemoteView')
            .length,
        cancellations + 1,
      );
      viewer.blockedApply!.complete();
      await following;
      await tester.pump(const Duration(milliseconds: 350));
      expect(viewer.applied, isEmpty);
      expect(
        api.sent.where((event) => event['type'] == 'select').single['payload'],
        {'model_version_id': 10, 'element_id': 77},
      );
      expect(coordinator.currentState.followLoading, isFalse);
      coordinator.dispose();
      await tester.pump();
      await viewer.close();
    },
  );

  testWidgets('own interaction cancels a delayed remote camera update', (
    tester,
  ) async {
    final api = _Api();
    final viewer = _Viewer();
    final coordinator = _coordinator(api, viewer);
    viewer.emit('ready');
    await coordinator.join(session);
    viewer.emit('presenceSubscribed');
    await tester.pump();
    await coordinator.follow(leader.clientId);
    viewer.blockedCamera = Completer<void>();
    viewer.emit(
      'presence',
      _event('camera', 10, {
        'position': [5, 5, 5],
      }).toJson(),
    );
    await tester.pump();
    viewer.emit('interaction', {'kind': 'camera'});
    expect(coordinator.currentState.followingClientId, isNull);
    viewer.blockedCamera!.complete();
    await tester.pump();
    expect(viewer.appliedCameras, isEmpty);
    expect(viewer.applied.length, 1);
    coordinator.dispose();
    await tester.pump();
    await viewer.close();
  });

  testWidgets(
    'offline performs no network operations and dispose cancels retries and heartbeat',
    (tester) async {
      final api = _Api();
      final viewer = _Viewer();
      final coordinator = _coordinator(api, viewer);
      coordinator.setOnline(false);
      await coordinator.join(session);
      expect(api.bootstrapReads, 0);
      coordinator.setOnline(true);
      await coordinator.join(session);
      viewer.emit('presenceSubscribed');
      await tester.pump();
      coordinator.setOnline(false);
      final calls = api.calls;
      viewer.emit('selection', {'version_id': 10, 'element_id': 42});
      await tester.pump(const Duration(seconds: 46));
      expect(api.calls, calls);
      coordinator.dispose();
      await tester.pump(const Duration(seconds: 46));
      expect(api.calls, calls);
      expect(
        viewer.commands.where((value) => value.$1 == 'sessionStop'),
        isNotEmpty,
      );
      await viewer.close();
    },
  );

  testWidgets(
    'public config strips tokens and ignores late snapshots after leave',
    (tester) async {
      final api =
          _Api()..blockedSnapshots = Completer<List<BimPresenceEnvelope>>();
      final viewer = _Viewer();
      final coordinator = _coordinator(api, viewer);
      await coordinator.join(session);
      final config =
          viewer.commands.where((value) => value.$1 == 'sessionStart').last.$2;
      expect((config['realtime'] as Map).containsKey('token'), isFalse);
      viewer.emit('presenceSubscribed');
      await tester.pump();
      await coordinator.leave();
      api.blockedSnapshots!.complete([
        _event('select', 5, {'model_version_id': 10, 'element_id': '42'}),
      ]);
      await tester.pump();
      expect(
        viewer.commands.where((value) => value.$1 == 'remoteSelection'),
        isEmpty,
      );
      coordinator.dispose();
      await tester.pump();
      await viewer.close();
    },
  );
}

BimSessionCoordinator _coordinator(_Api api, _Viewer viewer) =>
    BimSessionCoordinator(
      api: api,
      viewer: viewer,
      userId: 7,
      userName: 'Анна',
      clientId: 'own',
    );

BimPresenceEnvelope _event(
  String type,
  int sequence,
  Map<String, dynamic> payload, {
  String clientId = 'second-device',
}) => BimPresenceEnvelope(
  sessionId: 4,
  modelSetRevisionId: 9,
  clientId: clientId,
  sequence: sequence,
  type: type,
  senderId: 7,
  senderName: 'Анна',
  occurredAt: DateTime.utc(2026),
  payload: payload,
);

class _Viewer implements BimRealtimeViewer {
  final _events = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  @override
  bool get isReady => true;
  final commands = <(String, Map<String, dynamic>)>[];
  final applied = <BimViewState>[];
  final appliedCameras = <Map<String, dynamic>>[];
  Completer<void>? blockedApply;
  Completer<void>? blockedCamera;
  int remoteGeneration = 0;
  bool feedbackDuringApply = false;
  void emit(String type, [Map<String, dynamic>? payload]) =>
      _events.add({'type': type, 'payload': payload});
  Future<void> close() => _events.close();
  @override
  Stream<Map<String, dynamic>> get events => _events.stream;
  @override
  Future<Map<String, dynamic>> command(
    String type, [
    Map<String, dynamic> payload = const {},
  ]) async {
    commands.add((type, payload));
    if (type == 'cancelRemoteView') ++remoteGeneration;
    if (type == 'remoteCamera') {
      final generation = remoteGeneration;
      if (blockedCamera != null) await blockedCamera!.future;
      if (generation == remoteGeneration) appliedCameras.add(payload);
    }
    return {};
  }

  @override
  Future<BimViewState> getViewState() async => {
    'schema_version': 1,
    'camera': {},
    'models': [],
    'selection': [],
    'sections': [],
  };
  @override
  Future<void> applyViewState(BimViewState viewState) async {
    final generation = remoteGeneration;
    if (blockedApply != null) await blockedApply!.future;
    if (generation != remoteGeneration) return;
    applied.add(viewState);
    if (feedbackDuringApply) {
      emit('camera', {
        'position': [9, 9, 9],
        'source': 'remote',
      });
      emit('selection', {'source': 'remote'});
      emit('viewChanged', {'source': 'remote'});
    }
  }
}

class _Api implements BimSessionApi {
  int bootstrapReads = 0;
  int snapshotReads = 0;
  int viewWrites = 0;
  int calls = 0;
  final sent = <Map<String, dynamic>>[];
  List<BimParticipant> participants = [leader];
  List<BimPresenceEnvelope> snapshots = [];
  Completer<void>? blockedSelect;
  Completer<void>? blockedCursorClear;
  Completer<void>? blockedCursorHit;
  Completer<List<BimPresenceEnvelope>>? blockedSnapshots;
  final BimViewState view = {
    'schema_version': 1,
    'model_set_revision_id': 9,
    'camera': {'projection': 'orthographic'},
    'models': [
      {'version_id': 10, 'visible': false},
    ],
    'selection': [
      {'version_id': 10, 'element_id': '42'},
    ],
    'sections': [
      {'id': 'section', 'enabled': true},
    ],
  };
  @override
  Future<Map<String, dynamic>> bootstrap(
    int sessionId, {
    required String clientId,
  }) async {
    ++calls;
    ++bootstrapReads;
    return {
      'channel': 'presence-design-model-session.4',
      'realtime': {'enabled': true, 'key': 'public', 'token': 'never-in-js'},
    };
  }

  @override
  Future<void> sendEvent(int sessionId, Map<String, dynamic> envelope) async {
    ++calls;
    sent.add(envelope);
    if (envelope['type'] == 'select' &&
        blockedSelect != null &&
        !blockedSelect!.isCompleted) {
      await blockedSelect!.future;
    }
    if (envelope['type'] == 'cursor' &&
        envelope['payload'] == null &&
        blockedCursorClear != null &&
        !blockedCursorClear!.isCompleted) {
      await blockedCursorClear!.future;
    }
    if (envelope['type'] == 'cursor' &&
        envelope['payload'] != null &&
        blockedCursorHit != null &&
        !blockedCursorHit!.isCompleted) {
      await blockedCursorHit!.future;
    }
  }

  @override
  Future<List<BimParticipant>> heartbeat(
    int sessionId, {
    required String clientId,
    required int sequence,
  }) async {
    ++calls;
    return participants;
  }

  @override
  Future<List<BimPresenceEnvelope>> fetchSnapshots(int sessionId) async {
    ++calls;
    ++snapshotReads;
    return blockedSnapshots == null
        ? snapshots
        : await blockedSnapshots!.future;
  }

  @override
  Future<void> publishViewState(
    int sessionId,
    String clientId,
    int sequence,
    BimViewState viewState,
  ) async {
    ++calls;
    ++viewWrites;
  }

  @override
  Future<BimViewState?> fetchViewState(int sessionId, String clientId) async {
    ++calls;
    return view;
  }

  @override
  Future<void> leave(
    int sessionId, {
    required String clientId,
    required int sequence,
  }) async {
    ++calls;
  }
}
