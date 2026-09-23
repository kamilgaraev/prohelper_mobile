import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/field_catalog/data/field_catalog_repository.dart';
import 'package:prohelpers_mobile/features/field_catalog/data/project_files_repository.dart';
import 'package:prohelpers_mobile/features/field_catalog/data/project_participants_repository.dart';
import 'package:prohelpers_mobile/features/field_catalog/data/budgeting_repository.dart';
import 'package:prohelpers_mobile/features/field_catalog/data/team_expansion_repository.dart';
import 'package:prohelpers_mobile/features/budget_estimates/data/budget_estimates_repository.dart';

void main() {
  test('passes estimate filters and pagination to the server', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      return {
        'success': true,
        'data': {
          'items': [],
          'meta': {'current_page': 2, 'last_page': 3, 'total': 45},
        },
      };
    });

    final page = await BudgetEstimatesRepository(dio).fetchEstimates(
      projectId: 31,
      page: 2,
      status: 'approved',
      search: 'кровля',
    );

    expect(request.path, '/budget-estimates/estimates');
    expect(request.queryParameters, {
      'project_id': 31,
      'page': 2,
      'per_page': 20,
      'status': 'approved',
      'search': 'кровля',
    });
    expect(page.currentPage, 2);
    expect(page.lastPage, 3);
    expect(page.total, 45);
  });

  test('passes project and date to personnel attendance list', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      return {
        'success': true,
        'data': [
          {
            'employee_id': 7,
            'employee_label': 'Иванов Иван',
            'status_label': 'На работе',
          },
        ],
        'meta': {'current_page': 1, 'last_page': 1, 'total': 1},
      };
    });

    final page = await FieldCatalogRepository(dio).fetchPage(
      catalog: 'workforce-attendance',
      apiPrefix: '/field-admin/personnel',
      entity: 'attendance',
      projectId: 31,
      extraQueryParameters: {'work_date': '2026-09-23'},
    );

    expect(request.path, '/field-admin/personnel/attendance');
    expect(request.queryParameters['project_id'], 31);
    expect(request.queryParameters['work_date'], '2026-09-23');
    expect(page.items.single.title, 'Иванов Иван');
    expect(page.items.single.subtitle, 'На работе');
  });
  test('uploads project files bound to the selected record', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      return {
        'success': true,
        'data': {
          'item': {'id': 1, 'name': 'Фото'},
        },
      };
    });
    final file = File('${Directory.systemTemp.path}/mobile-record-file.txt');
    await file.writeAsString('photo');
    try {
      await ProjectFilesRepository(dio).uploadProjectFile(
        projectId: 31,
        recordType: 'construction_journal_entry',
        recordId: 84,
        path: file.path,
        fileType: 'photo',
      );

      final form = request.data as FormData;
      final fields = Map<String, dynamic>.fromEntries(form.fields);
      expect(request.path, '/files');
      expect(fields['project_id'], '31');
      expect(fields['record_type'], 'construction_journal_entry');
      expect(fields['record_id'], '84');
    } finally {
      await file.delete();
    }
  });

  test('loads CRM list with UUID records, search and page metadata', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      return {
        'success': true,
        'data': [
          {
            'id': 'c124c9a8-138d-48c8-b9d1-148452fcc911',
            'name': 'North',
            'status_label': 'Активна',
          },
        ],
        'meta': {'current_page': 2, 'last_page': 4, 'total': 61},
      };
    });

    final page = await FieldCatalogRepository(dio).fetchPage(
      catalog: 'crm',
      entity: 'companies',
      query: ' North ',
      projectId: 19,
      page: 2,
    );

    expect(request.path, '/catalog/crm/companies');
    expect(request.queryParameters['q'], 'North');
    expect(request.queryParameters['page'], 2);
    expect(request.queryParameters['project_id'], 19);
    expect(page.currentPage, 2);
    expect(page.lastPage, 4);
    expect(page.total, 61);
    expect(page.items.single.title, 'North');
    expect(page.items.single.subtitle, 'Активна');
  });

  test('loads UUID details for a tender', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      return {
        'success': true,
        'data': {
          'item': {
            'id': 'e7e27d86-604b-49c5-b94b-6e2c6942a22e',
            'title': 'Tender 21',
            'submission_deadline_at': '2026-10-01',
          },
        },
      };
    });

    final detail = await FieldCatalogRepository(dio).fetchDetail(
      catalog: 'tenders',
      uuid: 'e7e27d86-604b-49c5-b94b-6e2c6942a22e',
      projectId: 19,
    );

    expect(
      request.path,
      '/catalog/tenders/e7e27d86-604b-49c5-b94b-6e2c6942a22e',
    );
    expect(request.queryParameters['project_id'], 19);
    expect(detail.title, 'Tender 21');
    expect(detail.fields['submission_deadline_at'], '2026-10-01');
  });

  test(
    'loads published report files with a server issued download link',
    () async {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        request = options;
        return {
          'success': true,
          'data': [
            {
              'id': '01J9W2KQYFJ1R3N7Q8M6BCPX2A',
              'name': 'Отчёт смены',
              'type': 'pdf',
              'download_url': 'https://files.example.test/signed.pdf',
            },
          ],
          'meta': {'current_page': 1, 'last_page': 1, 'total': 1},
        };
      });

      final page = await FieldCatalogRepository(
        dio,
      ).fetchPage(catalog: 'reports', query: 'смены');

      expect(request.path, '/catalog/reports');
      expect(request.queryParameters['q'], 'смены');
      expect(page.items.single.title, 'Отчёт смены');
      expect(
        page.items.single.fields['download_url'],
        'https://files.example.test/signed.pdf',
      );
    },
  );

  test('loads report templates by numeric identifier', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      return {
        'success': true,
        'data': {
          'item': {
            'id': 27,
            'name': 'Ежедневный отчёт',
            'report_type': 'daily',
          },
        },
      };
    });

    final item = await FieldCatalogRepository(
      dio,
    ).fetchDetail(catalog: 'templates', uuid: '27');

    expect(request.path, '/catalog/templates/27');
    expect(item.title, 'Ежедневный отчёт');
    expect(item.fields['report_type'], 'daily');
  });

  test(
    'loads organization workforce rows with the field-admin envelope',
    () async {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        request = options;
        return {
          'success': true,
          'data': {
            'items': [
              {
                'id': 14,
                'full_name': 'Иван Иванов',
                'personnel_number': 'P-014',
                'status_label': 'Работает',
              },
            ],
            'meta': {'current_page': 1, 'last_page': 3, 'total': 41},
          },
        };
      });

      final page = await FieldCatalogRepository(dio).fetchPage(
        catalog: 'workforce-personnel',
        apiPrefix: '/field-admin/personnel',
        entity: 'employees',
      );

      expect(request.path, '/field-admin/personnel/employees');
      expect(page.items.single.uuid, '14');
      expect(page.items.single.title, 'Иван Иванов');
      expect(page.lastPage, 3);
      expect(page.total, 41);
    },
  );

  test('requests a project workforce calendar for a bounded week', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      return {
        'success': true,
        'data': {
          'days': [
            {'date': '2026-09-21', 'label': '21.09', 'weekday': 'Пн'},
          ],
          'employees': [
            {
              'employee_id': 14,
              'full_name': 'Иван Иванов',
              'assignment_label': 'Монтажник / Бригада A',
              'days': {
                '2026-09-21': {
                  'status': 'work',
                  'status_label': 'Рабочий день',
                  'hours': 8,
                },
              },
            },
          ],
        },
      };
    });

    final payload = await FieldCatalogRepository(dio).fetchPayload(
      path: '/field-admin/personnel/calendar',
      queryParameters: {
        'project_id': 9,
        'date_from': '2026-09-21',
        'date_to': '2026-09-27',
      },
    );

    expect(request.path, '/field-admin/personnel/calendar');
    expect(request.queryParameters['project_id'], 9);
    expect(request.queryParameters['date_from'], '2026-09-21');
    expect(payload['days'], hasLength(1));
    expect((payload['employees'] as List).first['full_name'], 'Иван Иванов');
  });

  test(
    'creates a CRM next contact with required target and due date',
    () async {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        request = options;
        return {
          'success': true,
          'data': {'id': 'activity-1'},
        };
      });

      await FieldCatalogRepository(dio).createCrmActivity(
        kind: 'next_contact',
        targetType: 'deal',
        targetId: 'de2f4931-8092-4b2a-9521-e296d2f58c45',
        subject: 'Позвонить заказчику',
        body: 'Уточнить дату встречи',
        dueAt: DateTime(2026, 10, 3),
      );

      expect(request.method, 'POST');
      expect(request.path, '/catalog/crm/activities');
      expect(request.data, {
        'kind': 'next_contact',
        'target_type': 'deal',
        'target_id': 'de2f4931-8092-4b2a-9521-e296d2f58c45',
        'subject': 'Позвонить заказчику',
        'body': 'Уточнить дату встречи',
        'due_at': '2026-10-03',
      });
    },
  );

  test(
    'lists project users and binds selected user using scoped routes',
    () async {
      final calls = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        calls.add(options);
        if (options.method == 'PUT') {
          return {
            'success': true,
            'data': {'project_id': 9, 'user_id': 26, 'active': true},
          };
        }
        return {
          'success': true,
          'data': [
            {
              'id': 26,
              'name': 'Ирина',
              'email': 'irina@example.test',
              'already_assigned': false,
            },
          ],
          'meta': {'current_page': 1, 'last_page': 2, 'total': 21},
        };
      });
      final repository = ProjectParticipantsRepository(dio);

      final candidates = await repository.fetchPage(
        projectId: 9,
        availableUsers: true,
        query: 'Ирина',
      );
      await repository.bind(projectId: 9, userId: 26);

      expect(
        calls[0].path,
        '/field-admin/team/projects/9/participants/available-users',
      );
      expect(calls[0].queryParameters['q'], 'Ирина');
      expect(candidates.total, 21);
      expect(candidates.items.single.id, 26);
      expect(candidates.items.single.alreadyAssigned, isFalse);
      expect(calls[1].method, 'PUT');
      expect(calls[1].path, '/field-admin/team/projects/9/participants/26');
    },
  );

  test('searches project files and fetches a project-scoped detail', () async {
    final calls = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      calls.add(options);
      if (options.path.endsWith('/file-12')) {
        return {
          'success': true,
          'data': {
            'item': {
              'id': 'file-12',
              'name': 'Фото фасада',
              'project_id': 31,
              'download_url': 'https://files.example.test/file-12',
            },
          },
        };
      }
      return {
        'success': true,
        'data': [
          {
            'id': 'file-12',
            'name': 'Фото фасада',
            'project_id': 31,
            'file_type': 'photo',
          },
        ],
        'meta': {'current_page': 1, 'last_page': 1, 'total': 1},
      };
    });
    final repository = ProjectFilesRepository(dio);

    final page = await repository.fetchPage(projectId: 31, query: 'фасад');
    final detail = await repository.fetchDetail(
      projectId: 31,
      fileId: 'file-12',
    );

    expect(calls[0].path, '/files');
    expect(calls[0].queryParameters['project_id'], 31);
    expect(calls[0].queryParameters['q'], 'фасад');
    expect(page.items.single.title, 'Фото фасада');
    expect(calls[1].path, '/files/file-12');
    expect(calls[1].queryParameters['project_id'], 31);
    expect(detail.fields['download_url'], 'https://files.example.test/file-12');
  });

  test('loads project budgeting summary and paged execution cards', () async {
    final calls = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      calls.add(options);
      if (options.path.endsWith('/summary')) {
        return {
          'success': true,
          'data': {
            'project': {'id': 31, 'name': 'Объект A'},
            'snapshot': {'id': 'snap-1', 'is_stale': false, 'row_count': 1},
            'totals_by_currency': [
              {'currency': 'RUB', 'bac_minor': 250000, 'spi': '0.95'},
            ],
          },
        };
      }
      return {
        'success': true,
        'data': [
          {'row_key': 'row-1', 'currency': 'RUB', 'bac_minor': 250000},
        ],
        'meta': {'page': 2, 'per_page': 20, 'total': 21, 'last_page': 2},
      };
    });
    final repository = MobileBudgetingRepository(dio);

    final summary = await repository.fetchSummary(projectId: 31);
    final page = await repository.fetchExecutionCards(projectId: 31, page: 2);

    expect(calls[0].path, '/budgeting/projects/31/summary');
    expect(summary['project']['name'], 'Объект A');
    expect(calls[1].path, '/budgeting/projects/31/execution-cards');
    expect(calls[1].queryParameters['page'], 2);
    expect(page.currentPage, 2);
    expect(page.total, 21);
    expect(page.items.single['row_key'], 'row-1');
  });

  test(
    'uses team expansion search, invitation, and response action routes',
    () async {
      final calls = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        calls.add(options);
        return {
          'success': true,
          'data': [
            {'id': 4, 'display_name': 'Монтажная бригада'},
          ],
          'meta': {'current_page': 1, 'last_page': 1, 'total': 1},
        };
      });
      final repository = TeamExpansionRepository(dio);

      final page = await repository.fetchPage(
        path: '/team-expansion/contractors',
        filters: const {'search': 'монтаж'},
      );
      await repository.create(
        path: '/team-expansion/brigade-invitations',
        payload: const {'brigade_id': 4, 'project_id': 31},
      );
      await repository.action(
        path: '/team-expansion/brigade-requests/12/responses/8/approve',
        payload: const {},
      );

      expect(calls[0].path, '/team-expansion/contractors');
      expect(calls[0].queryParameters['search'], 'монтаж');
      expect(page.items.single.title, 'Монтажная бригада');
      expect(calls[1].method, 'POST');
      expect(calls[1].path, '/team-expansion/brigade-invitations');
      expect(
        calls[2].path,
        '/team-expansion/brigade-requests/12/responses/8/approve',
      );
    },
  );
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.handler);

  final Map<String, dynamic> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await requestStream?.drain<void>();
    return ResponseBody.fromString(
      jsonEncode(handler(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
