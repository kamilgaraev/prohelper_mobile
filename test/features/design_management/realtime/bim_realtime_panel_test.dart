import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/design_management/realtime/bim_realtime_panel.dart';
import 'package:prohelpers_mobile/features/design_management/realtime/bim_realtime_viewer.dart';
import 'package:prohelpers_mobile/features/design_management/realtime/bim_session_coordinator.dart';
import 'package:prohelpers_mobile/features/design_management/realtime/bim_session_models.dart';
import 'package:prohelpers_mobile/features/design_management/viewer/bim_viewer_contract.dart';

void main() {
  testWidgets('offline disables network actions in both themes', (
    tester,
  ) async {
    final viewer = _Viewer();
    final api = _Api();
    final coordinator = BimSessionCoordinator(
      api: api,
      viewer: viewer,
      userId: 7,
      userName: 'Анна',
      clientId: 'own',
    )..setOnline(false);
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: BimRealtimePanel(
              coordinator: coordinator,
              sessions: const [
                BimSessionSummary(id: 4, name: 'Разбор', modelSetRevisionId: 9),
              ],
              isLoading: false,
              offline: true,
              canCreate: true,
              onRefresh: () async {
                api.calls++;
              },
              onCreate: (_) async {
                api.calls++;
              },
              onJoin: (_) async {
                api.calls++;
              },
            ),
          ),
        ),
      );
      expect(
        find.text('Совместный просмотр недоступен без сети.'),
        findsOneWidget,
      );
      expect(
        tester.widget<IconButton>(_icon('Обновить просмотры')).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(_icon('Создать совместный просмотр'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Войти'),
            )
            .onPressed,
        isNull,
      );
    }
    expect(api.calls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    coordinator.dispose();
    await tester.pump();
    await viewer.close();
  });

  testWidgets(
    'shows same-user other device as a followable participant with server name and color',
    (tester) async {
      final viewer = _Viewer();
      final api = _Api();
      final coordinator = BimSessionCoordinator(
        api: api,
        viewer: viewer,
        userId: 7,
        userName: 'Анна',
        clientId: 'own',
      );
      await coordinator.join(
        const BimSessionSummary(id: 4, name: 'Разбор', modelSetRevisionId: 9),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BimRealtimePanel(
              coordinator: coordinator,
              sessions: const [],
              isLoading: false,
              offline: false,
              onRefresh: () async {},
              onCreate: (_) async {},
              onJoin: (_) async {},
            ),
          ),
        ),
      );
      viewer.emit('presenceSubscribed');
      await tester.pump();
      expect(find.text('Анна (вы)'), findsOneWidget);
      expect(find.text('Анна'), findsOneWidget);
      expect(_icon('Следовать за участником'), findsOneWidget);
      final avatars = tester.widgetList<CircleAvatar>(
        find.byType(CircleAvatar),
      );
      expect(avatars.last.backgroundColor, const Color(0xff123456));
      expect(
        tester.widget<IconButton>(_icon('Следовать за участником')).onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      coordinator.dispose();
      await tester.pump();
      await viewer.close();
    },
  );

  testWidgets('join waits for loaded models and cancels stale requests', (
    tester,
  ) async {
    const first = BimSessionSummary(
      id: 4,
      name: 'Первый просмотр',
      modelSetRevisionId: 9,
    );
    const second = BimSessionSummary(
      id: 5,
      name: 'Второй просмотр',
      modelSetRevisionId: 9,
    );
    final controller = BimViewerController();
    final commands = <(String, Map<String, dynamic>)>[];
    final coordinator = BimSessionCoordinator(
      api: _Api(),
      viewer: BimRealtimeViewerAdapter(controller),
      userId: 7,
      userName: 'Анна',
      clientId: 'own',
    );
    await expectLater(controller.command('sessionStart'), throwsStateError);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BimRealtimePanel(
            coordinator: coordinator,
            sessions: const [first],
            isLoading: false,
            offline: false,
            canCreate: true,
            onRefresh: () async {},
            onCreate: (_) async {},
            onJoin: coordinator.join,
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Войти'))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<IconButton>(_icon('Создать совместный просмотр')).onPressed,
      isNull,
    );

    final stale = coordinator.join(first);
    await tester.pump();
    expect(coordinator.currentState.connection, BimSessionConnection.joining);
    final active = coordinator.join(second);
    await tester.pump();
    expect(commands.where((entry) => entry.$1 == 'sessionStart'), isEmpty);
    controller.attach((type, payload) async {
      commands.add((type, payload));
      return {};
    }, () async => Uint8List(0));
    await tester.pump();
    expect(commands.where((entry) => entry.$1 == 'sessionStart'), isEmpty);
    controller.markReady();
    controller.emit({'type': 'ready'});
    await Future.wait([stale, active]);
    await tester.pump();
    expect(
      commands
          .where((entry) => entry.$1 == 'sessionStart')
          .map((entry) => entry.$2['session_id']),
      [second.id],
    );

    await coordinator.leave();
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Войти'))
          .onPressed,
      isNotNull,
    );
    expect(
      tester.widget<IconButton>(_icon('Создать совместный просмотр')).onPressed,
      isNotNull,
    );
    controller.emit({'type': 'loading'});
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Войти'))
          .onPressed,
      isNull,
    );
    final left = coordinator.join(first);
    await tester.pump();
    await coordinator.leave();
    await left;
    controller.emit({'type': 'ready'});
    await tester.pump();
    expect(commands.where((entry) => entry.$1 == 'sessionStart').length, 1);

    controller.emit({'type': 'loading'});
    final disposed = coordinator.join(first);
    await tester.pump();
    coordinator.dispose();
    await disposed;
    controller.emit({'type': 'ready'});
    await tester.pump();
    expect(commands.where((entry) => entry.$1 == 'sessionStart').length, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await controller.dispose();
  });
}

Finder _icon(String tooltip) => find.byWidgetPredicate(
  (widget) => widget is IconButton && widget.tooltip == tooltip,
);

class _Viewer implements BimRealtimeViewer {
  final _events = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  @override
  bool get isReady => true;
  void emit(String type) => _events.add({'type': type});
  Future<void> close() => _events.close();
  @override
  Stream<Map<String, dynamic>> get events => _events.stream;
  @override
  Future<Map<String, dynamic>> command(
    String type, [
    Map<String, dynamic> payload = const {},
  ]) async => {};
  @override
  Future<BimViewState> getViewState() async => {};
  @override
  Future<void> applyViewState(BimViewState viewState) async {}
}

class _Api implements BimSessionApi {
  int calls = 0;
  @override
  Future<Map<String, dynamic>> bootstrap(
    int sessionId, {
    required String clientId,
  }) async => {};
  @override
  Future<void> sendEvent(int sessionId, Map<String, dynamic> envelope) async {}
  @override
  Future<List<BimParticipant>> heartbeat(
    int sessionId, {
    required String clientId,
    required int sequence,
  }) async => [
    const BimParticipant(clientId: 'own', userId: 7, name: 'Анна'),
    const BimParticipant(
      clientId: 'other',
      userId: 7,
      name: 'Анна',
      color: '#123456',
    ),
  ];
  @override
  Future<List<BimPresenceEnvelope>> fetchSnapshots(int sessionId) async => [];
  @override
  Future<void> publishViewState(
    int sessionId,
    String clientId,
    int sequence,
    BimViewState viewState,
  ) async {}
  @override
  Future<BimViewState?> fetchViewState(int sessionId, String clientId) async =>
      null;
  @override
  Future<void> leave(
    int sessionId, {
    required String clientId,
    required int sequence,
  }) async {}
}
