import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/design_management/realtime/bim_realtime_viewer.dart';
import 'package:prohelpers_mobile/features/design_management/realtime/bim_session_coordinator.dart';
import 'package:prohelpers_mobile/features/design_management/realtime/bim_session_models.dart';
import 'package:prohelpers_mobile/features/design_management/realtime/dio_bim_session_api.dart';
import 'package:prohelpers_mobile/features/design_management/viewer/bim_viewer_contract.dart';

void main() {
  test(
    'native JS string selection posts numeric IDs, drops invalid pairs and preserves sequence and null clears',
    () async {
      final requests = <RequestOptions>[];
      final selectedRequests = List.generate(
        3,
        (_) => Completer<RequestOptions>(),
      );
      var selectedCount = 0;
      final api = _api((options) {
        requests.add(options);
        if (options.method == 'POST' &&
            options.path.endsWith('/events') &&
            options.data['type'] == 'select' &&
            selectedCount < selectedRequests.length) {
          selectedRequests[selectedCount++].complete(options);
        }
        if (options.path.endsWith('/bootstrap')) {
          return {
            'success': true,
            'data': {'id': 4, 'model_set_revision_id': 9},
          };
        }
        if (options.path.endsWith('/participants')) {
          return {'success': true, 'data': []};
        }
        return {'success': true, 'data': {}};
      });
      final controller =
          BimViewerController()
            ..attach((type, payload) async => {}, () async => Uint8List(0));
      final coordinator = BimSessionCoordinator(
        api: api,
        viewer: BimRealtimeViewerAdapter(controller),
        userId: 7,
        userName: 'Анна',
        clientId: 'native',
      );
      await coordinator.join(
        const BimSessionSummary(id: 4, name: 'Разбор', modelSetRevisionId: 9),
      );
      controller.emit({'type': 'presenceSubscribed'});
      await _settleEvents();
      controller.emit({
        'type': 'selection',
        'payload': {'version_id': '10', 'element_id': '42'},
      });
      final selection = await selectedRequests[0].future.timeout(
        const Duration(seconds: 5),
      );
      expect(selection.data, {
        'schema_version': 2,
        'client_id': 'native',
        'sequence': 2,
        'type': 'select',
        'payload': {'model_version_id': 10, 'element_id': 42},
      });
      for (final invalid in [
        {'version_id': '10x', 'element_id': '42'},
        {'version_id': '10', 'element_id': '0'},
        {'version_id': '10', 'element_id': 42.5},
        {'version_id': null, 'element_id': '42'},
        {'version_id': -1, 'element_id': '42'},
        {'version_id': '10', 'element_id': true},
      ]) {
        controller.emit({'type': 'selection', 'payload': invalid});
        await _settleEvents();
      }
      expect(
        requests
            .where(
              (request) =>
                  request.method == 'POST' &&
                  request.path.endsWith('/events') &&
                  request.data['type'] == 'select',
            )
            .length,
        1,
      );
      controller.emit({
        'type': 'selection',
        'payload': {'version_id': '10', 'element_id': null},
      });
      await selectedRequests[1].future.timeout(const Duration(seconds: 5));
      await _settleEvents();
      controller.emit({'type': 'selection', 'payload': null});
      await selectedRequests[2].future.timeout(const Duration(seconds: 5));
      final selected =
          requests
              .where(
                (request) =>
                    request.method == 'POST' &&
                    request.path.endsWith('/events') &&
                    request.data['type'] == 'select',
              )
              .toList();
      expect(selected.map((request) => request.data['sequence']), [2, 3, 4]);
      expect(selected[1].data['payload'], {
        'model_version_id': 10,
        'element_id': null,
      });
      expect(selected[2].data['payload'], {
        'model_version_id': null,
        'element_id': null,
      });
      coordinator.dispose();
      await _settleEvents();
      await controller.dispose();
    },
  );

  test(
    'lists all pages for current revision and preserves server permission to create',
    () async {
      final requests = <RequestOptions>[];
      final api = _api((options) {
        requests.add(options);
        final page = options.queryParameters['page'];
        return {
          'success': true,
          'data': [
            {
              'id': page,
              'title': 'Просмотр $page',
              'model_set_revision_id': page == 1 ? 7 : 9,
            },
          ],
          'meta': {
            'last_page': 2,
            'available_actions': [
              {'key': 'create', 'enabled': true},
            ],
          },
        };
      });
      final result = await api.listSessions(3, 9);
      expect(requests.map((value) => value.queryParameters), [
        {'project_id': 3, 'per_page': 100, 'page': 1},
        {'project_id': 3, 'per_page': 100, 'page': 2},
      ]);
      expect(result.sessions.single.id, 2);
      expect(result.canCreate, isTrue);
    },
  );

  test(
    'posts v2 event without trusting sender and uses scoped native full view endpoints',
    () async {
      final requests = <RequestOptions>[];
      final api = _api((options) {
        requests.add(options);
        return {
          'success': true,
          'data': {
            'id': 4,
            'title': 'Разбор',
            'model_set_revision_id': 9,
            'view_state': {'schema_version': 1, 'model_set_revision_id': 9},
          },
        };
      });
      await api.createSession(
        projectId: 3,
        modelSetRevisionId: 9,
        title: 'Разбор',
      );
      await api.sendEvent(4, {
        'schema_version': 2,
        'client_id': 'native',
        'sequence': 10,
        'type': 'select',
        'sender': {'id': 900},
        'payload': {'model_version_id': 5, 'element_id': '42'},
      });
      await api.publishViewState(4, 'native', 11, {'schema_version': 1});
      final view = await api.fetchViewState(4, 'second-device');
      expect(requests[0].data, {
        'project_id': 3,
        'model_set_revision_id': 9,
        'title': 'Разбор',
      });
      expect(requests[1].data, {
        'schema_version': 2,
        'client_id': 'native',
        'sequence': 10,
        'type': 'select',
        'payload': {'model_version_id': 5, 'element_id': '42'},
      });
      expect(
        requests[2].path,
        '/design-management/model-sessions/4/view-state',
      );
      expect(requests[2].data, {
        'client_id': 'native',
        'sequence': 11,
        'view_state': {'schema_version': 1},
      });
      expect(requests[3].queryParameters, {'client_id': 'second-device'});
      expect(view, {'schema_version': 1, 'model_set_revision_id': 9});
    },
  );

  test('restores sender names, colors, latest events and null view', () async {
    final api = _api((options) {
      if (options.path.endsWith('/participants')) {
        return {
          'success': true,
          'data': [
            {
              'client_id': 'second-device',
              'sender': {'id': 7, 'name': 'Анна', 'color': '#123456'},
              'latest_events': {
                'select': {
                  'schema_version': 2,
                  'session_id': 4,
                  'model_set_revision_id': 9,
                  'client_id': 'second-device',
                  'sequence': 2,
                  'type': 'select',
                  'sender': {'id': 7, 'name': 'Анна'},
                  'occurred_at': '2026-09-29T00:00:00Z',
                  'payload': {'model_version_id': 5, 'element_id': null},
                },
              },
            },
          ],
        };
      }
      return {'success': true, 'data': null};
    });
    final participants = await api.heartbeat(
      4,
      clientId: 'native',
      sequence: 1,
    );
    expect(participants.single.name, 'Анна');
    expect(participants.single.color, '#123456');
    final snapshots = await api.fetchSnapshots(4);
    expect(snapshots.single.type, 'select');
    expect(snapshots.single.payload['element_id'], isNull);
    expect(await api.fetchViewState(4, 'native'), isNull);
  });
}

Future<void> _settleEvents() =>
    Future<void>.delayed(const Duration(milliseconds: 1));

DioBimSessionApi _api(Map<String, dynamic> Function(RequestOptions) respond) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.httpClientAdapter = _Adapter(respond);
  return DioBimSessionApi(dio);
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Map<String, dynamic> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(respond(options)),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
  @override
  void close({bool force = false}) {}
}
