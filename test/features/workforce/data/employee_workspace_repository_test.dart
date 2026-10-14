import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/workforce/data/employee_workspace_repository.dart';

void main() {
  test(
    'loads working timezone options for the selected work date without financial terms',
    () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://mobile-api.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'employee': {
                      'full_name': 'Иван Петров',
                      'personnel_number': '001',
                      'working_timezone': 'Europe/Moscow',
                      'working_timezone_date': '2026-10-15',
                      'working_contract_id': 41,
                      'working_timezones': [
                        {
                          'employment_contract_id': 41,
                          'contract_number': 'ТД-41',
                          'timezone': 'Europe/Moscow',
                        },
                      ],
                    },
                    'documents': [],
                    'requests': [],
                    'monthly_facts': {'periods': []},
                  },
                },
              ),
            );
          },
        ),
      );
      final result = await EmployeeWorkspaceRepository(
        dio,
      ).fetch('2026-10', workDate: '2026-10-15');
      expect(captured!.queryParameters, {
        'month': '2026-10',
        'work_date': '2026-10-15',
      });
      expect(result.workingTimezone, 'Europe/Moscow');
      expect(result.workingTimezoneDate, '2026-10-15');
      expect(result.workingContractId, 41);
      expect(result.workingTimezones.single.contractNumber, 'ТД-41');
    },
  );

  test(
    'reads the paginated own request archive with server metadata',
    () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://mobile-api.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': [
                    {
                      'id': 8,
                      'kind': 'absence',
                      'status': 'rejected',
                      'date_from': '2026-10-15',
                      'date_to': '2026-10-16',
                      'basis': 'История',
                    },
                  ],
                  'meta': {
                    'current_page': 3,
                    'last_page': 4,
                    'total': 180,
                    'pending_count': 1,
                  },
                },
              ),
            );
          },
        ),
      );
      final result = await EmployeeWorkspaceRepository(
        dio,
      ).fetchRequests(page: 3);
      expect(captured!.path, '/workforce/self-service/requests');
      expect(captured!.queryParameters, {'page': 3, 'per_page': 50});
      expect(result.currentPage, 3);
      expect(result.lastPage, 4);
      expect(result.total, 180);
      expect(result.requests.single.id, 8);
    },
  );

  test(
    'сохраняет идентификатор повтора и не отправляет чужой employee_id',
    () async {
      RequestOptions? captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://mobile-api.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 201,
                data: {'success': true, 'data': {}},
              ),
            );
          },
        ),
      );
      await EmployeeWorkspaceRepository(dio).submit(
        idempotencyKey: '147e7d7e-0565-4c5d-8d65-ecb113bb020a',
        kind: 'absence',
        dateFrom: '2026-10-14',
        dateTo: '2026-10-15',
        basis: 'Прошу отпуск',
        requestedData: {'absence_type_code': 'vacation'},
      );
      expect(captured!.path, '/workforce/self-service/requests');
      expect(
        captured!.data['idempotency_key'],
        '147e7d7e-0565-4c5d-8d65-ecb113bb020a',
      );
      expect((captured!.data as Map).containsKey('employee_id'), isFalse);
    },
  );
}
