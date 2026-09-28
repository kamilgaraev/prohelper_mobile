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
          {
            'row_key': 'row-1',
            'wbs_code': '1.2.3',
            'task_id': 42,
            'currency': 'RUB',
            'bac_minor': 250000,
            'pv_minor': 125000,
            'ev_minor': 118750,
            'sv_minor': -6250,
            'spi': '0.95',
          },
        ],
        'meta': {
          'current_page': 2,
          'per_page': 20,
          'total': 21,
          'last_page': 2,
        },
      };
    });
    final repository = MobileBudgetingRepository(dio);

    final summary = await repository.fetchSummary(projectId: 31);
    final page = await repository.fetchExecutionCards(projectId: 31, page: 2);

    expect(calls[0].path, '/budgeting/projects/31/summary');
    expect(summary['project']['name'], 'Объект A');
    expect(calls[1].path, '/budgeting/projects/31/execution-cards');
    expect(calls[1].queryParameters['page'], 2);
    expect(calls[1].queryParameters['per_page'], 20);
    expect(page.currentPage, 2);
    expect(page.total, 21);
    expect(page.items.single['row_key'], 'row-1');
    expect(page.items.single['wbs_code'], '1.2.3');
    expect(page.items.single['task_id'], 42);
    expect(page.items.single['pv_minor'], 125000);
    expect(page.items.single['ev_minor'], 118750);
    expect(page.items.single['sv_minor'], -6250);
    expect(page.items.single['spi'], '0.95');
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
      expect(page.currentPage, 1);
      expect(page.lastPage, 1);
      expect(page.total, 1);
      expect(calls[1].method, 'POST');
      expect(calls[1].path, '/team-expansion/brigade-invitations');
      expect(
        calls[2].path,
        '/team-expansion/brigade-requests/12/responses/8/approve',
      );
    },
  );

  test('loads nonempty brigades from their paginated marketplace projection', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      return {
        'success': true,
        'data': [
          {
            'id': 8,
            'name': 'Бригада бетонщиков',
            'team_size': 6,
            'specializations': ['Бетонные работы'],
            'regions': ['Москва'],
            'availability_status': 'available',
            'verification_status': 'approved',
            'rating': 4.8,
            'completed_projects_count': 3,
          },
        ],
        'meta': {'current_page': 2, 'last_page': 4, 'total': 71},
      };
    });

    final page = await TeamExpansionRepository(dio).fetchPage(
      path: '/team-expansion/brigades',
      filters: const {'search': 'бетон'},
      page: 2,
      perPage: 20,
    );

    expect(request.path, '/team-expansion/brigades');
    expect(request.queryParameters, {
      'search': 'бетон',
      'page': 2,
      'per_page': 20,
    });
    expect(page.items.single.title, 'Бригада бетонщиков');
    expect(page.currentPage, 2);
    expect(page.lastPage, 4);
    expect(page.total, 71);
  });

  test('reads project participants and available users with project scope', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      requests.add(options);
      return {
        'success': true,
        'data': [
          {
            'id': 14,
            'name': 'Иван Иванов',
            'email': 'ivan@example.test',
            if (options.path.endsWith('/available-users'))
              'already_assigned': false
            else
              'project_role': 'engineer',
          },
        ],
        'meta': {'current_page': 2, 'last_page': 3, 'total': 41},
      };
    });
    final repository = ProjectParticipantsRepository(dio);

    final members = await repository.fetchPage(
      projectId: 52,
      query: ' Иван ',
      page: 2,
    );
    final available = await repository.fetchPage(
      projectId: 52,
      query: 'Иван',
      availableUsers: true,
      page: 2,
    );

    expect(requests[0].path, '/field-admin/team/projects/52/participants');
    expect(requests[0].queryParameters, {'q': 'Иван', 'page': 2, 'per_page': 20});
    expect(members.items.single.projectRole, 'engineer');
    expect(members.currentPage, 2);
    expect(members.lastPage, 3);
    expect(requests[1].path, '/field-admin/team/projects/52/participants/available-users');
    expect(available.items.single.alreadyAssigned, isFalse);
    expect(available.total, 41);
  });

  test('loads nonempty tender and template catalogs with server pagination', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      requests.add(options);
      if (options.path == '/catalog/tenders') {
        return {
          'success': true,
          'data': [
            {'id': 51, 'number': 'T-51', 'title': 'Ремонт кровли', 'status': 'published'},
          ],
          'meta': {'current_page': 2, 'last_page': 5, 'total': 88},
        };
      }
      return {
        'success': true,
        'data': [
          {'id': 27, 'name': 'Ежедневный отчёт', 'report_type': 'daily', 'is_default': true},
        ],
        'meta': {'current_page': 2, 'last_page': 2, 'total': 22},
      };
    });
    final repository = FieldCatalogRepository(dio);

    final tenders = await repository.fetchPage(catalog: 'tenders', query: 'кровли', page: 2);
    final templates = await repository.fetchPage(catalog: 'templates', query: 'ежедневный', page: 2);

    expect(requests[0].path, '/catalog/tenders');
    expect(requests[0].queryParameters, {'q': 'кровли', 'page': 2, 'per_page': 20});
    expect(tenders.items.single.title, 'Ремонт кровли');
    expect(tenders.lastPage, 5);
    expect(requests[1].path, '/catalog/templates');
    expect(templates.items.single.title, 'Ежедневный отчёт');
    expect(templates.total, 22);
  });

  test('parses nonempty CRM contact, lead, deal and activity resources', () async {
    const cases = <({
      String entity,
      String id,
      int? projectId,
      Map<String, dynamic> item,
      String expectedTitle,
    })>[
      (
        entity: 'contacts',
        id: 'contact-52',
        projectId: null,
        item: {
          'id': 'contact-52',
          'organization_id': 38,
          'company_id': 'company-5',
          'company': {'id': 'company-5', 'name': 'ООО Мост', 'status': 'active'},
          'full_name': 'Анна Петрова',
          'position': 'Снабженец',
          'phone': '+79990000000',
          'email': 'anna@example.test',
          'messengers': [],
          'is_primary': true,
          'status': 'active',
          'is_archived': false,
          'is_merged': false,
          'contact_points': [],
          'identities': [],
        },
        expectedTitle: 'Анна Петрова',
      ),
      (
        entity: 'leads',
        id: 'lead-52',
        projectId: null,
        item: {
          'id': 'lead-52',
          'organization_id': 38,
          'company_id': 'company-5',
          'contact_id': 'contact-52',
          'company': {'id': 'company-5', 'name': 'ООО Мост', 'status': 'active'},
          'contact': {'id': 'contact-52', 'full_name': 'Анна Петрова'},
          'title': 'Поставка арматуры',
          'status': 'new',
          'priority': 'high',
          'amount_visible': false,
          'estimated_amount': null,
          'utm': {},
          'is_archived': false,
          'activities': [],
        },
        expectedTitle: 'Поставка арматуры',
      ),
      (
        entity: 'deals',
        id: 'deal-52',
        projectId: 52,
        item: {
          'id': 'deal-52',
          'organization_id': 38,
          'project_id': 52,
          'company': {'id': 'company-5', 'name': 'ООО Мост', 'status': 'active'},
          'primary_contact': {'id': 'contact-52', 'full_name': 'Анна Петрова'},
          'title': 'Арматура для объекта',
          'status': 'in_progress',
          'amount': null,
          'currency': 'RUB',
          'amount_visible': false,
          'probability': 0.6,
          'custom_fields': {},
          'is_archived': false,
          'activities': [],
        },
        expectedTitle: 'Арматура для объекта',
      ),
      (
        entity: 'activities',
        id: 'activity-52',
        projectId: null,
        item: {
          'id': 'activity-52',
          'organization_id': 38,
          'company_id': 'company-5',
          'contact_id': 'contact-52',
          'company': {'id': 'company-5', 'name': 'ООО Мост'},
          'contact': {'id': 'contact-52', 'full_name': 'Анна Петрова'},
          'type': 'call',
          'direction': 'outbound',
          'status': 'planned',
          'subject': 'Согласовать сроки поставки',
          'body': 'Позвонить до конца недели',
          'is_archived': false,
        },
        expectedTitle: 'Согласовать сроки поставки',
      ),
    ];

    for (final testCase in cases) {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        request = options;
        return {
          'success': true,
          'data': [testCase.item],
          'meta': {'current_page': 2, 'last_page': 4, 'total': 61},
        };
      });

      final page = await FieldCatalogRepository(dio).fetchPage(
        catalog: 'crm',
        entity: testCase.entity,
        query: ' Acme ',
        projectId: testCase.projectId,
        page: 2,
      );

      expect(request.path, '/catalog/crm/${testCase.entity}');
      expect(request.queryParameters['q'], 'Acme');
      expect(request.queryParameters['page'], 2);
      expect(request.queryParameters['per_page'], 20);
      if (testCase.projectId case final projectId?) {
        expect(request.queryParameters['project_id'], projectId);
      }
      expect(page.items.single.uuid, testCase.id);
      expect(page.items.single.title, testCase.expectedTitle);
      expect(page.currentPage, 2);
      expect(page.lastPage, 4);
      expect(page.total, 61);
      if (testCase.entity == 'activities') {
        expect(page.items.single.fields['subject'], 'Согласовать сроки поставки');
      }
    }
  });
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
