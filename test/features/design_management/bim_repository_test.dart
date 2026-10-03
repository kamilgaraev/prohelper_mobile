import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/design_management/data/bim_models.dart';
import 'package:prohelpers_mobile/features/design_management/data/bim_repository.dart';

void main() {
  test('cancelled opening cannot start preparation', () async {
    final methods = <String>[];
    final repository = _repository((request) {
      methods.add(request.method);
      return {
        'success': true,
        'data': {
          'derivative': {
            'status': 'missing',
            'metadata': {'is_stale': true},
          },
          'available_actions': [
            {'key': 'prepare_viewer', 'enabled': true},
          ],
        },
      };
    });
    await repository.viewerForOpening(55, isActive: () => false);
    expect(methods, ['GET']);
  });
  test(
    'opening an outdated model upgrades its shared preparation once',
    () async {
      final requests = <RequestOptions>[];
      final repository = _repository((request) {
        requests.add(request);
        return {
          'success': true,
          'data': {
            'derivative': {
              'status': request.method == 'POST' ? 'queued' : 'missing',
              'metadata': {'is_stale': request.method != 'POST'},
            },
            'available_actions': [
              {'key': 'prepare_viewer', 'enabled': true},
            ],
          },
        };
      });
      final result = await repository.viewerForOpening(55);
      expect(result.status, 'queued');
      expect(requests.map((request) => request.method), ['GET', 'POST']);
      expect(
        requests.last.path,
        '/design-management/model-versions/55/viewer/preparation',
      );
    },
  );

  test(
    'opening does not prepare ready, new, failed or unauthorized models',
    () async {
      for (final scenario in [
        {
          'status': 'ready',
          'stale': false,
          'allowed': true,
          'url': 'https://files.test/model.frag',
        },
        {'status': 'missing', 'stale': false, 'allowed': true},
        {'status': 'failed', 'stale': true, 'allowed': true},
        {'status': 'missing', 'stale': true, 'allowed': false},
      ]) {
        final methods = <String>[];
        final repository = _repository((request) {
          methods.add(request.method);
          return {
            'success': true,
            'data': {
              'derivative': {
                'status': scenario['status'],
                'download_url': scenario['url'],
                'metadata': {'is_stale': scenario['stale']},
              },
              'available_actions': [
                {'key': 'prepare_viewer', 'enabled': scenario['allowed']},
              ],
            },
          };
        });
        await repository.viewerForOpening(55);
        expect(methods, ['GET'], reason: '$scenario');
      }
    },
  );
  test('assignee search uses canonical search parameter', () async {
    RequestOptions? captured;
    final repository = _repository((request) {
      captured = request;
      return {
        'success': true,
        'data': [],
        'meta': {'total': 0},
      };
    });
    await repository.assignees(9, query: 'Анна');
    expect(captured!.queryParameters, containsPair('search', 'Анна'));
  });
  test('keeps legacy admin camera and full mobile view state unchanged', () {
    for (final camera in [
      {
        'position': [1, 2, 3],
        'target': [0, 0, 0],
      },
      {
        'schema_version': 1,
        'models': [55],
        'sections': [],
        'camera': {
          'position': [1, 2, 3],
        },
      },
    ]) {
      final context = BimViewContext.fromJson({
        'models': [55],
        'camera': camera,
        'transforms': {
          '55': {
            'shift': [0, 2, 3],
            'rotation': 30,
          },
        },
      });
      expect(context.viewState, camera);
      expect(context.versionIds, [55]);
      expect(context.transforms[55]!.rotation, 30);
    }
  });
  test(
    'keeps all catalog statuses, nested pagination and server permissions',
    () async {
      final requests = <RequestOptions>[];
      final repository = _repository((options) {
        requests.add(options);
        return {
          'success': true,
          'data': [
            {
              'id': 5,
              'title': 'ОВ',
              'derivative_status': 'processing',
              'derivative': {'progress_percent': 41},
              'available_actions': [
                {
                  'key': 'prepare_viewer',
                  'label': 'Подготовить',
                  'enabled': false,
                },
              ],
            },
          ],
          'meta': {'current_page': 2, 'last_page': 4, 'total': 90},
        };
      });
      final page = await repository.versions(9, page: 2, query: 'ОВ');
      expect(requests.single.path, '/design-management/project-model-versions');
      expect(requests.single.queryParameters, containsPair('project_id', 9));
      expect(requests.single.queryParameters, containsPair('search', 'ОВ'));
      expect(requests.single.queryParameters, isNot(contains('status')));
      expect(page.page, 2);
      expect(page.lastPage, 4);
      expect(page.total, 90);
      expect(page.items.single.processing, isTrue);
      expect(page.items.single.progress, 41);
      expect(page.items.single.can('prepare_viewer'), isFalse);
    },
  );
  test(
    'reads ready derivative URL and exact version plus element identity',
    () async {
      final requests = <RequestOptions>[];
      final repository = _repository((options) {
        requests.add(options);
        return {
          'success': true,
          'data':
              options.path.endsWith('/viewer')
                  ? {
                    'version': {'id': 55},
                    'derivative': {
                      'status': 'ready',
                      'download_url': 'https://files.test/55.frag',
                      'metadata': {'derivative_size_bytes': 4096},
                    },
                  }
                  : {
                    'express_id': 71,
                    'properties': {'Name': 'Стена'},
                  },
        };
      });
      final viewer = await repository.viewer(55);
      final element = await repository.element(55, 71);
      expect(viewer.ready, isTrue);
      expect(viewer.versionId, 55);
      expect(viewer.url!.path, '/55.frag');
      expect(viewer.sizeBytes, 4096);
      expect(element['express_id'], 71);
      expect(
        requests.last.path,
        '/design-management/model-versions/55/elements/71',
      );
    },
  );
  test(
    'updates set with exact expected revision, pinned versions and transforms',
    () async {
      final requests = <RequestOptions>[];
      final repository = _repository((options) {
        requests.add(options);
        return {
          'success': true,
          'data': {
            'id': 3,
            'project_id': 9,
            'title': 'Координация',
            'revision': 5,
            'models': [55, 56],
            'model_set_revision': 4,
            'model_set_revision_id': 14,
            'transforms': {
              '55': {
                'shift': [1, 2, 3],
                'rotation': 90,
              },
            },
          },
        };
      });
      await repository.saveSet(
        projectId: 9,
        title: 'Координация',
        existing: const BimModelSet(
          id: 3,
          projectId: 9,
          title: 'Координация',
          revision: 4,
        ),
        composition: {
          55: const BimTransform(shift: [1, 2, 3], rotation: 90),
          56: const BimTransform(),
        },
      );
      final context = BimViewContext.fromJson(await repository.openSet(3, 4));
      expect(requests.first.method, 'PATCH');
      expect(requests.first.data['expected_revision'], 4);
      expect(requests.first.data['version_ids'], [55, 56]);
      expect(requests.first.data['transforms']['55']['shift'], [1, 2, 3]);
      expect(
        requests.last.path,
        '/design-management/model-sets/3/revisions/4/open',
      );
      expect(context.versionIds, [55, 56]);
      expect(context.modelSetRevisionId, 14);
      expect(context.transforms[55]!.rotation, 90);
    },
  );
  test('keeps issue camera, elements, revision and idempotency key', () async {
    final requests = <RequestOptions>[];
    final repository = _repository((options) {
      requests.add(options);
      return {
        'success': true,
        'data': {
          'id': 6,
          'project_id': 9,
          'revision': 2,
          'title': 'Коллизия',
          'status': 'open',
        },
      };
    });
    final issue = await repository.createIssue(9, {
      'title': 'Коллизия',
      'severity': 'major',
      'version_id': 55,
      'camera': {
        'section_planes': [
          {'axis': 'x', 'offset': 10},
        ],
      },
      'elements': [
        {'version_id': 55, 'element_id': 71},
      ],
    }, idempotencyKey: 'stable-create');
    await repository.issueAction(issue, 'verify', {
      'accepted': false,
    }, idempotencyKey: 'stable-action');
    expect(requests.first.headers['Idempotency-Key'], 'stable-create');
    expect(requests.first.data['camera']['section_planes'], isNotEmpty);
    expect(requests.first.data['elements'].single['version_id'], 55);
    expect(
      requests.last.path,
      '/design-management/project-issues/6/actions/verify',
    );
    expect(requests.last.data['expected_revision'], 2);
    expect(requests.last.data['accepted'], isFalse);
  });
  test('preserves permission denial and revision conflict for UI', () async {
    for (final status in [403, 409]) {
      final dio = Dio();
      dio.httpClientAdapter = _Adapter(
        (_) => {'success': false, 'message': 'Данные изменились.'},
        status: status,
      );
      final repository = BimRepository(dio);
      await expectLater(
        repository.viewer(55),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            status,
          ),
        ),
      );
    }
  });
}

BimRepository _repository(
  Map<String, dynamic> Function(RequestOptions) handler,
) {
  final dio = Dio();
  dio.httpClientAdapter = _Adapter(handler);
  return BimRepository(dio);
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler, {this.status = 200});
  final Map<String, dynamic> Function(RequestOptions) handler;
  final int status;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(handler(options)),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
