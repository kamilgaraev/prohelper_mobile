import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/workforce/data/month_timekeeping_model.dart';
import 'package:prohelpers_mobile/features/workforce/data/month_timekeeping_repository.dart';
import 'package:prohelpers_mobile/features/workforce/data/timekeeping_interval_input.dart';

import '../timekeeping_fixture.dart';

void main() {
  test(
    'reads mobile pagination and keeps organization and project scope explicit',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': [timekeepingFixture()],
                  'meta': {'current_page': 2, 'last_page': 3},
                },
              ),
            );
          },
        ),
      );
      final repository = MonthTimekeepingRepository(dio);
      final result = await repository.periods('2026-09', page: 2);
      expect(result.page, 2);
      expect(result.lastPage, 3);
      expect(result.periods.single.rows.single.name, 'Иван Петров');
      expect(requests.first.path, '/workforce/timekeeping/periods');
      expect(requests.first.queryParameters, {
        'month': '2026-09',
        'page': 2,
        'per_page': 25,
        'scope': 'organization',
      });
      await repository.periods('2026-09', projectId: 9);
      expect(requests.last.queryParameters['project_id'], 9);
      expect(requests.last.queryParameters, isNot(contains('scope')));
    },
  );

  test('posts hours with the server revision and empty intervals', () async {
    RequestOptions? request;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': timekeepingFixture(revision: 2, minutes: 450),
              },
            ),
          );
        },
      ),
    );
    final updated = await MonthTimekeepingRepository(
      dio,
    ).saveCell(TimekeepingPeriod.fromJson(timekeepingFixture()), {
      'employee_id': 12,
      'work_date': '2026-09-02',
      'duration_minutes': 450,
      'intervals': [],
    });
    expect(request!.path, '/workforce/timekeeping/periods/7/cells');
    expect(request!.data, {
      'employee_id': 12,
      'work_date': '2026-09-02',
      'duration_minutes': 450,
      'intervals': [],
      'expected_revision': 1,
    });
    expect(updated.revision, 2);
    expect(updated.rows.single.days[1].factMinutes, 450);
  });

  test(
    'rejects insecure export links and preserves server error messages',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('download')) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {'url': 'http://unsafe.test/file'},
                  },
                ),
              );
            } else {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: options,
                    statusCode: 422,
                    data: {'message': 'Табель изменён. Обновите данные.'},
                  ),
                ),
              );
            }
          },
        ),
      );
      final repository = MonthTimekeepingRepository(dio);
      await expectLater(repository.download(1), throwsFormatException);
      await expectLater(
        repository.period(7),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)),
      );
    },
  );

  test(
    'accepts Russian decimal hours and rejects invalid or excessive input',
    () {
      expect(parseTimekeepingHours('7,5'), 450);
      expect(parseTimekeepingHours('8'), 480);
      expect(parseTimekeepingHours('24'), 1440);
      expect(parseTimekeepingHours('0'), 0);
      for (final input in ['', '-1', '25', 'NaN', '8e0', '7,555', '1:30']) {
        expect(parseTimekeepingHours(input), isNull, reason: input);
      }
      expect(timekeepingHours(0), '0');
      expect(timekeepingHours(450), '7,5');
    },
  );

  test(
    'shows server instants in the work timezone and preserves unchanged intervals',
    () {
      final original = <String, dynamic>{
        'start_at': '2026-09-02T06:00:00Z',
        'end_at': '2026-09-02T15:00:00Z',
        'timezone': 'Europe/Moscow',
        'break_intervals': [
          {
            'start_at': '2026-09-02T09:00:00Z',
            'end_at': '2026-09-02T09:30:00Z',
          },
        ],
      };
      final input = TimekeepingIntervalInput.fromJson(original);
      expect(input.start, '02.09.2026 09:00');
      expect(input.breaks.single.start, '02.09.2026 12:00');
      expect(input.toJson(), same(original));
      input.original = null;
      input.end = '02.09.2026 17:00';
      expect(input.toJson()['end_at'], '2026-09-02T17:00:00');
      expect(input.toJson()['timezone'], 'Europe/Moscow');
      expect(timekeepingWallClock('31.09.2026 10:00'), isNull);
      input.breaks.single.end = '02.09.2026 20:00';
      expect(input.toJson, throwsFormatException);
    },
  );
}
