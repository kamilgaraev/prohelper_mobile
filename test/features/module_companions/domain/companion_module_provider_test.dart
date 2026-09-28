import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/module_companions/data/companion_module_model.dart';
import 'package:prohelpers_mobile/features/module_companions/data/companion_module_repository.dart';
import 'package:prohelpers_mobile/features/module_companions/domain/companion_module_provider.dart';

import '../companion_module_test_data.dart';

class _RecordingCompanionRepository extends CompanionModuleRepository {
  _RecordingCompanionRepository({this.error}) : super(Dio());

  final Object? error;
  final List<Object> nextErrors = [];
  Completer<CompanionModuleListModel>? pendingList;
  String? loadedSlug;
  int? loadedProjectId;
  String? loadedStatus;
  String? loadedQuery;
  int? loadedPage;
  int? detailId;
  String? actionKey;
  String? actionComment;
  int refreshCount = 0;

  @override
  Future<CompanionModuleListModel> fetchList({
    required String moduleSlug,
    int? projectId,
    String? status,
    String? query,
    int page = 1,
    int perPage = 20,
  }) async {
    if (nextErrors.isNotEmpty) {
      throw nextErrors.removeAt(0);
    }
    final currentError = error;
    if (currentError != null) {
      throw currentError;
    }

    loadedSlug = moduleSlug;
    loadedProjectId = projectId;
    loadedStatus = status;
    loadedQuery = query;
    loadedPage = page;
    refreshCount++;

    final pending = pendingList;
    if (pending != null) {
      pendingList = null;
      return pending.future;
    }

    return CompanionModuleListModel.fromJson(
      companionListJson(slug: moduleSlug, page: page, lastPage: 2),
    );
  }

  @override
  Future<CompanionModuleDetailModel> fetchDetail({
    required String moduleSlug,
    required int id,
  }) async {
    detailId = id;
    return CompanionModuleDetailModel.fromJson(
      companionDetailJson(slug: moduleSlug),
    );
  }

  @override
  Future<CompanionModuleDetailModel> executeAction({
    required String moduleSlug,
    required int id,
    required String action,
    String? comment,
  }) async {
    actionKey = action;
    actionComment = comment;
    return CompanionModuleDetailModel.fromJson(
      companionDetailJson(slug: moduleSlug),
    );
  }
}

void main() {
  test('loads companion list with project status and query', () async {
    final repository = _RecordingCompanionRepository();
    final notifier = CompanionModuleNotifier(repository, 'contract-management')
      ..syncProject(9);

    await notifier.setStatus('active');
    await notifier.setQuery('Tower');

    expect(repository.loadedSlug, 'contract-management');
    expect(repository.loadedProjectId, 9);
    expect(repository.loadedStatus, 'active');
    expect(repository.loadedQuery, 'Tower');
    expect(notifier.state.list?.items.single.id, 42);
    expect(notifier.state.error, isNull);
  });

  test('loads detail and action then refreshes list', () async {
    final repository = _RecordingCompanionRepository();
    final notifier = CompanionModuleNotifier(repository, 'change-management');

    final detail = await notifier.fetchDetail(42);
    await notifier.executeAction(id: 42, action: 'submit', comment: 'Done');

    expect(repository.detailId, 42);
    expect(repository.actionKey, 'submit');
    expect(repository.actionComment, 'Done');
    expect(repository.refreshCount, 1);
    expect(detail.sections.single.title, 'Основное');
  });

  test('accepts PTO document response and reloads companion list', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      requests.add(options);
      if (options.method == 'POST') {
        return {
          'success': true,
          'message': 'Документ обновлён',
          'data': {
            'id': 7,
            'document_set_id': 42,
            'title': 'Исполнительная схема',
            'status': 'remarks',
            'result': {
              'document_date': null,
              'approved_at': null,
              'submitted_at': null,
            },
            'files': [],
            'comments': [],
            'available_actions': [],
          },
        };
      }
      return {
        'success': true,
        'data': companionListJson(slug: 'executive-documentation'),
      };
    });
    final notifier = CompanionModuleNotifier(
      CompanionModuleRepository(dio),
      'executive-documentation',
    )..syncProject(9);

    await notifier.executeExecutiveDocumentAction(
      documentId: 7,
      action: 'add_remark',
      comment: 'Нужно исправить',
    );

    expect(requests.map((request) => request.method), ['POST', 'GET']);
    expect(
      requests.first.path,
      '/pto/executive-documents/7/actions/add_remark',
    );
    expect(requests.last.path, '/companions/executive-documentation');
    expect(requests.last.queryParameters['project_id'], 9);
    expect(notifier.state.list?.items.single.id, 42);
    expect(notifier.state.error, isNull);
  });

  test('loads next server page and appends unique items', () async {
    final repository = _RecordingCompanionRepository();
    final notifier = CompanionModuleNotifier(repository, 'contract-management');
    await notifier.load();
    await notifier.loadMore();

    expect(repository.loadedPage, 2);
    expect(notifier.state.list?.items.map((item) => item.id), [42]);
  });

  test(
    'retains last list after offline search and marks its query stale',
    () async {
      final repository = _RecordingCompanionRepository();
      final notifier = CompanionModuleNotifier(
        repository,
        'contract-management',
      )..syncProject(9);
      await notifier.load();

      repository.nextErrors.add(const ApiException('Нет соединения'));
      await notifier.setQuery('new query');

      expect(notifier.state.list?.items.single.id, 42);
      expect(notifier.state.listQuery, isNull);
      expect(notifier.state.query, 'new query');
      expect(notifier.state.showingStaleList, isTrue);
      expect(notifier.state.error, 'Нет соединения');
    },
  );

  test('clears stale companion list after permission denial', () async {
    final repository = _RecordingCompanionRepository();
    final notifier = CompanionModuleNotifier(repository, 'contract-management')
      ..syncProject(9);
    await notifier.load();

    repository.nextErrors.add(
      const ApiException('Нет доступа', statusCode: 403),
    );
    await notifier.setQuery('restricted');

    expect(notifier.state.list, isNull);
    expect(notifier.state.showingStaleList, isFalse);
    expect(notifier.state.permissionDenied, isTrue);
  });

  test(
    'does not append a page from a stale query after offline fallback',
    () async {
      final repository = _RecordingCompanionRepository();
      final notifier = CompanionModuleNotifier(
        repository,
        'contract-management',
      )..syncProject(9);
      await notifier.load();
      final pendingAppend = Completer<CompanionModuleListModel>();
      repository.pendingList = pendingAppend;
      final append = notifier.loadMore();

      repository.nextErrors.add(const ApiException('Нет соединения'));
      await notifier.setQuery('new query');
      final nextJson = companionListJson(
        slug: 'contract-management',
        page: 2,
        lastPage: 2,
      );
      (nextJson['items'] as List).single['id'] = 43;
      pendingAppend.complete(CompanionModuleListModel.fromJson(nextJson));
      await append;

      expect(notifier.state.showingStaleList, isTrue);
      expect(notifier.state.query, 'new query');
      expect(notifier.state.list?.items.map((item) => item.id), [42]);
    },
  );

  test('clears companion rows after hard failure loading next page', () async {
    final repository = _RecordingCompanionRepository();
    final notifier = CompanionModuleNotifier(repository, 'contract-management')
      ..syncProject(9);
    await notifier.load();
    repository.nextErrors.add(
      const ApiException('Нет доступа', statusCode: 403),
    );

    await notifier.loadMore();

    expect(notifier.state.list, isNull);
    expect(notifier.state.permissionDenied, isTrue);
  });

  test('marks permission and malformed states', () async {
    final denied = CompanionModuleNotifier(
      _RecordingCompanionRepository(
        error: const ApiException('Нет доступа', statusCode: 403),
      ),
      'contract-management',
    );
    await denied.load();

    expect(denied.state.permissionDenied, isTrue);

    final malformed = CompanionModuleNotifier(
      _RecordingCompanionRepository(
        error: const FormatException('bad contract'),
      ),
      'contract-management',
    );
    await malformed.load();

    expect(malformed.state.malformedContract, isTrue);
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
  ) async => ResponseBody.fromString(
    jsonEncode(handler(options)),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
