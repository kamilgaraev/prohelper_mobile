import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/design_management/data/design_package_model.dart';
import 'package:prohelpers_mobile/features/design_management/data/design_package_repository.dart';

void main() {
  test(
    'parses package result, files, comments, history, and allowed actions',
    () {
      final package = DesignPackageModel.fromJson({
        'id': 42,
        'project_id': 9,
        'title': 'Рабочая документация',
        'stage': 'РД',
        'discipline': 'ОВ',
        'status': 'review',
        'result': {'title': 'Результат проверки', 'value': 'Замечаний нет'},
        'files': [
          {
            'id': 5,
            'name': 'ОВ.pdf',
            'mime_type': 'application/pdf',
            'preview_url': 'https://files.example.test/preview',
            'download_url': 'https://files.example.test/download',
          },
        ],
        'comments': [
          {
            'id': 3,
            'author': 'Инженер',
            'body': 'Проверено',
            'created_at': '2026-09-23T08:00:00Z',
          },
        ],
        'workflow_history': [
          {
            'title': 'Передано на проверку',
            'created_at': '2026-09-22T08:00:00Z',
          },
        ],
        'available_actions': [
          {'key': 'approve', 'title': 'Согласовать', 'requires_comment': true},
        ],
      });

      expect(package.result.single.value, 'Замечаний нет');
      expect(
        package.files.single.downloadUrl,
        'https://files.example.test/download',
      );
      expect(package.comments.single.body, 'Проверено');
      expect(package.workflowHistory.single.title, 'Передано на проверку');
      expect(package.availableActions.single.requiresComment, isTrue);
    },
  );

  test(
    'uses selected-project pagination and confirmed package routes',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        requests.add(options);
        if (options.method == 'GET' &&
            options.path.endsWith('/design-packages')) {
          return {
            'success': true,
            'data': [
              {'id': 42, 'project_id': 9, 'title': 'Рабочая документация'},
            ],
            'meta': {
              'current_page': 2,
              'last_page': 3,
              'per_page': 20,
              'total': 50,
            },
          };
        }
        return {
          'success': true,
          'data': {
            'id': 42,
            'project_id': 9,
            'title': 'Рабочая документация',
            'available_actions': [
              {
                'key': 'approve',
                'title': 'Согласовать',
                'requires_comment': true,
              },
            ],
          },
        };
      });

      final repository = DesignPackageRepository(dio);
      final page = await repository.fetchList(projectId: 9, page: 2);
      final detail = await repository.fetchDetail(42);
      final action = await repository.executeAction(
        id: 42,
        action: 'approve',
        comment: 'Проверено',
      );

      expect(requests[0].path, '/pto/design-packages');
      expect(requests[0].queryParameters, containsPair('project_id', 9));
      expect(requests[0].queryParameters, containsPair('page', 2));
      expect(page.items.single.id, 42);
      expect(page.lastPage, 3);
      expect(requests[1].path, '/pto/design-packages/42');
      expect(requests[2].path, '/pto/design-packages/42/actions/approve');
      expect(requests[2].data, containsPair('comment', 'Проверено'));
      expect(action.id, 42);
      expect(detail.id, 42);
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
    return ResponseBody.fromString(
      jsonEncode(handler(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
