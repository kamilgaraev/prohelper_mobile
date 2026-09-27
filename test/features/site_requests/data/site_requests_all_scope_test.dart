import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';

void main() {
  test(
    'заявки объекта запрашивают все доступные записи выбранного объекта',
    () async {
      RequestOptions? request;
      final dio = Dio(
        BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
      );
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': [
                    for (var id = 1; id <= 5; id++)
                      {
                        'id': id,
                        'project_id': 52,
                        'title': 'Заявка $id',
                        'status': 'pending',
                        'priority': 'medium',
                        'request_type': 'material_request',
                      },
                  ],
                  'meta': {'total': 5, 'current_page': 1},
                },
              ),
            );
          },
        ),
      );

      final rows = await SiteRequestsRepository(
        dio,
      ).fetchSiteRequests(projectId: 52);

      expect(request?.path, '/site-requests');
      expect(request?.queryParameters['scope'], 'all');
      expect(request?.queryParameters['project_id'], 52);
      expect(rows, hasLength(5));
      expect(rows.last.title, 'Заявка 5');
    },
  );
}
