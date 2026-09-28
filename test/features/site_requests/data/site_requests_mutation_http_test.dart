import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';

void main() {
  test('creates a material batch and parses its primary request', () async {
    final server = _Server({
      'primary_request': _request(status: 'draft'),
      'group_id': 12,
      'created_count': 2,
      'request_ids': [575, 576],
    }, status: 201);
    final payload = {
      'project_id': 52,
      'title': 'Материалы для фундамента',
      'request_type': 'material_request',
      'priority': 'medium',
      'idempotency_key': 'qa-request-stable-key',
      'materials': [
        {
          'material_name': 'Бетон',
          'material_quantity': 1.5,
          'material_unit': 'м3',
        },
        {
          'material_name': 'Арматура',
          'material_quantity': 25,
          'material_unit': 'кг',
        },
      ],
    };

    final result = await server.repository.createSiteRequest(payload);

    expect(server.requests.single.path, '/site-requests');
    expect(server.requests.single.method, 'POST');
    expect(server.requests.single.data, payload);
    expect(
      server.requests.single.headers['Idempotency-Key'],
      'qa-request-stable-key',
    );
    expect(result.serverId, 575);
    expect(result.status, 'draft');
    expect(result.materialQuantity, 1.5);
  });

  test('edits a request and reads the authoritative response', () async {
    final server = _Server(_request(status: 'draft'));
    final payload = {
      'title': 'Материалы для фундамента',
      'material_quantity': 1.5,
    };

    final result = await server.repository.updateSiteRequest(575, payload);

    expect(server.requests.single.path, '/site-requests/575');
    expect(server.requests.single.method, 'PUT');
    expect(server.requests.single.data, payload);
    expect(result.title, 'Материалы для фундамента');
    expect(result.materialQuantity, 1.5);
  });

  test('edits a group and reads the primary request envelope', () async {
    final server = _Server({
      'primary_request': _request(status: 'draft'),
      'group_id': 12,
      'updated_count': 2,
      'request_ids': [575, 576],
    });
    final payload = {'title': 'Материалы для фундамента', 'priority': 'medium'};

    final result = await server.repository.updateSiteRequestGroup(12, payload);

    expect(server.requests.single.path, '/site-requests/groups/12');
    expect(server.requests.single.method, 'PUT');
    expect(server.requests.single.data, payload);
    expect(result.serverId, 575);
    expect(result.status, 'draft');
  });

  test(
    'changes status with a comment and reads server history and actions',
    () async {
      final server = _Server({
        ..._request(status: 'approved'),
        'available_transitions': [
          {'status': 'in_progress', 'name': 'В исполнение'},
        ],
        'history': [
          {
            'id': 91,
            'action': 'status_changed',
            'action_label': 'Статус изменён',
            'notes': 'Проверено',
            'new_status_label': 'Одобрена',
          },
        ],
      });

      final result = await server.repository.changeSiteRequestStatus(
        575,
        'approved',
        notes: '  Проверено  ',
      );

      expect(server.requests.single.path, '/site-requests/575/status');
      expect(server.requests.single.method, 'POST');
      expect(server.requests.single.data, {
        'status': 'approved',
        'notes': 'Проверено',
      });
      expect(result.status, 'approved');
      expect(result.history.single.notes, 'Проверено');
      expect(result.availableTransitions.single.status, 'in_progress');
    },
  );

  test(
    'assigns and unassigns the employee through the same mobile endpoint',
    () async {
      for (final assignee in [23, null]) {
        final server = _Server({
          ..._request(status: 'pending'),
          'assigned_to': assignee,
          'assigned_user': assignee == null ? null : {'id': 23, 'name': 'Иван'},
        });

        final result = await server.repository.assignSiteRequest(575, assignee);

        expect(server.requests.single.path, '/site-requests/575/assignee');
        expect(server.requests.single.method, 'PUT');
        expect(server.requests.single.data, {'assigned_user_id': assignee});
        expect(result.assignedUserName, assignee == null ? isNull : 'Иван');
      }
    },
  );

  test(
    'status validation and permission failures do not produce a success',
    () async {
      for (final status in [403, 422]) {
        final server = _Server(
          null,
          status: status,
          message: 'Переход недоступен',
        );

        await expectLater(
          server.repository.changeSiteRequestStatus(575, 'approved'),
          throwsA(
            isA<ApiException>()
                .having((error) => error.statusCode, 'status', status)
                .having(
                  (error) => error.message,
                  'message',
                  'Переход недоступен',
                ),
          ),
        );
        expect(server.requests.single.data, {'status': 'approved'});
      }
    },
  );

  test(
    'a disconnected status action is not silently treated as queued or sent',
    () async {
      final server = _Server(null, disconnected: true);

      await expectLater(
        server.repository.changeSiteRequestStatus(575, 'completed'),
        throwsA(isA<ApiException>()),
      );

      expect(server.requests, hasLength(1));
      expect(server.requests.single.path, '/site-requests/575/status');
    },
  );
}

Map<String, dynamic> _request({required String status}) => {
  'id': 575,
  'project_id': 52,
  'title': 'Материалы для фундамента',
  'status': status,
  'priority': 'medium',
  'request_type': 'material_request',
  'material_name': 'Бетон',
  'material_quantity': '1.500',
  'material_unit': 'м3',
};

class _Server {
  _Server(
    dynamic data, {
    int status = 200,
    String? message,
    bool disconnected = false,
  }) {
    final dio = Dio(
      BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final response = Response<dynamic>(
            requestOptions: options,
            statusCode: status,
            data: {'success': status < 400, 'message': message, 'data': data},
          );
          if (disconnected || status >= 400) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: disconnected ? null : response,
                type:
                    disconnected
                        ? DioExceptionType.connectionError
                        : DioExceptionType.badResponse,
              ),
            );
          } else {
            handler.resolve(response);
          }
        },
      ),
    );
    repository = SiteRequestsRepository(dio);
  }

  final requests = <RequestOptions>[];
  late final SiteRequestsRepository repository;
}
