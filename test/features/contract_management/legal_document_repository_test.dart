import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/contract_management/data/legal_document_model.dart';
import 'package:prohelpers_mobile/features/contract_management/data/legal_document_repository.dart';
import 'package:prohelpers_mobile/features/contract_management/data/legal_document_snapshot.dart';

void main() {
  test('offline fallback excludes authorization and not-found responses', () {
    expect(shouldUseOfflineVersionAfterStatus(null), isTrue);
    expect(shouldUseOfflineVersionAfterStatus(408), isTrue);
    expect(shouldUseOfflineVersionAfterStatus(503), isTrue);
    expect(shouldUseOfflineVersionAfterStatus(401), isFalse);
    expect(shouldUseOfflineVersionAfterStatus(403), isFalse);
    expect(shouldUseOfflineVersionAfterStatus(404), isFalse);
  });

  test('normalizes workflow actions and optional legal document fields', () {
    final document = LegalDocumentModel.fromJson({
      'id': 44,
      'title': 'Договор подряда',
      'document_type_label': 'Договор',
      'status': 'active',
      'workflow_summary': {
        'status': 'in_progress',
        'available_action_details': [
          {
            'action': 'approve',
            'label': 'Согласовать',
            'enabled': true,
            'blockers': [],
          },
        ],
        'problem_flags': ['workflow_overdue'],
      },
      'current_version': {'id': 10, 'version_number': 2, 'content_hash': 'abc'},
      'versions': [
        {
          'id': 10,
          'version_number': 2,
          'content_hash': 'abc',
          'processing_status': 'ready',
          'preview_available': true,
          'mime_type': 'application/pdf',
          'size_bytes': 2048,
        },
      ],
      'signature_requests': [
        {'id': 19, 'method': 'paper'},
      ],
      'lock_version': 4,
    });

    expect(document.workflow.actions.single.action, 'approve');
    expect(document.currentVersion?.contentHash, 'abc');
    expect(document.workflow.problemFlags, ['workflow_overdue']);
    expect(document.currentVersion?.previewAvailable, isTrue);
    expect(document.currentVersion?.sizeBytes, 2048);
    expect(document.signatureRequests.single.supportsPaperOriginal, isTrue);
    expect(document.lockVersion, 4);
  });

  test(
    'uses exact protected version route and rejects insecure response URL',
    () async {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _LegalDocumentJsonAdapter((options) {
        request = options;
        return {
          'success': true,
          'data': {'url': 'https://storage.example.test/file'},
        };
      });

      final url = await LegalDocumentRepository(
        dio,
      ).fetchVersionUrl(documentId: 44, versionId: 10, purpose: 'preview');

      expect(request.method, 'GET');
      expect(request.path, '/legal-archive/documents/44/versions/10/preview');
      expect(url.scheme, 'https');

      dio.httpClientAdapter = _LegalDocumentJsonAdapter(
        (_) => {
          'success': true,
          'data': {'url': 'http://unsafe.test/file'},
        },
      );
      await expectLater(
        LegalDocumentRepository(
          dio,
        ).fetchVersionUrl(documentId: 44, versionId: 10, purpose: 'download'),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'follows the stable cursor until the final page and retains data.data shape',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _LegalDocumentJsonAdapter((options) {
        requests.add(options);
        final query = options.queryParameters;
        if (query['sync_after_id'] == 0) {
          return {
            'success': true,
            'data': {
              'data': List.generate(50, (index) => _document(index + 1)),
            },
            'meta': {
              'next_cursor': 50,
              'has_more': true,
              'sync_max_id': 51,
              'per_page': 50,
            },
          };
        }
        return {
          'success': true,
          'data': {
            'data': [_document(51)],
          },
          'meta': {
            'next_cursor': null,
            'has_more': false,
            'sync_max_id': 51,
            'per_page': 50,
          },
        };
      });

      final result = await LegalDocumentRepository(
        dio,
      ).fetchDocumentList(projectId: 7);

      expect(result.documents, hasLength(51));
      expect(result.isPartial, isFalse);
      expect(requests, hasLength(2));
      expect(requests[0].queryParameters['per_page'], 50);
      expect(requests[0].queryParameters['sync_after_id'], 0);
      expect(requests[1].queryParameters['sync_after_id'], 50);
      expect(requests[1].queryParameters['sync_max_id'], 51);
    },
  );

  test('returns a partial result after an interrupted cursor page', () async {
    var call = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _LegalDocumentJsonAdapter((options) {
      call++;
      if (call == 1) {
        return {
          'success': true,
          'data': {
            'data': [_document(1)],
          },
          'meta': {
            'next_cursor': 1,
            'has_more': true,
            'sync_max_id': 2,
            'per_page': 50,
          },
        };
      }
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'offline',
      );
    });

    final result = await LegalDocumentRepository(
      dio,
    ).fetchDocumentList(projectId: 7);

    expect(result.documents, hasLength(1));
    expect(result.isPartial, isTrue);
    expect(result.error, isNotEmpty);
  });

  test(
    'full scans replace changed and deleted documents with cursor zero',
    () async {
      const identity = LegalDocumentCacheIdentity(
        userId: 3,
        organizationId: 8,
        sessionId: 'session-a',
      );
      final snapshots = <String, LegalDocumentListSnapshotData>{};
      final requests = <RequestOptions>[];
      var scan = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _LegalDocumentJsonAdapter((options) {
        requests.add(options);
        scan++;
        final records = switch (scan) {
          1 => [_document(1, title: 'Старое название'), _document(2)],
          2 => [_document(1, title: 'Новое название')],
          _ => <Map<String, dynamic>>[],
        };
        return {
          'success': true,
          'data': {'data': records},
          'meta': {
            'next_cursor': null,
            'has_more': false,
            'sync_max_id': 2,
            'per_page': 50,
          },
        };
      });
      final repository = LegalDocumentRepository(
        dio,
        listSnapshotReader: (_, _, kind) async => snapshots[kind],
        listSnapshotWriter: (
          _,
          _,
          kind,
          documents,
          maxId,
          nextCursor,
          isComplete,
          clearPartial,
        ) async {
          snapshots[kind] = LegalDocumentListSnapshotData(
            rawDocuments: List<Map<String, dynamic>>.from(documents),
            syncMaxId: maxId,
            nextCursor: nextCursor,
            isComplete: isComplete,
          );
          if (clearPartial) snapshots.remove('partial');
        },
      );

      await repository.fetchDocumentList(projectId: 7, identity: identity);
      final secondScan = await repository.fetchDocumentList(
        projectId: 7,
        identity: identity,
      );

      expect(requests[0].queryParameters['sync_after_id'], 0);
      expect(requests[1].queryParameters['sync_after_id'], 0);
      expect(secondScan.documents, hasLength(1));
      expect(secondScan.documents.single.title, 'Новое название');
      expect(snapshots['list']!.rawDocuments, hasLength(1));

      final emptyScan = await repository.fetchDocumentList(
        projectId: 7,
        identity: identity,
      );
      expect(requests[2].queryParameters['sync_after_id'], 0);
      expect(emptyScan.documents, isEmpty);
      expect(snapshots['list']!.rawDocuments, isEmpty);
      expect(snapshots['list']!.isComplete, isTrue);
    },
  );

  test(
    'does not fall back to a cached detail after access is denied',
    () async {
      const identity = LegalDocumentCacheIdentity(
        userId: 3,
        organizationId: 8,
        sessionId: 'session-a',
      );
      final cached = <int, LegalDocumentModel>{};
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _LegalDocumentJsonAdapter((options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: 403,
            data: {'message': 'forbidden'},
          ),
        );
      });
      final repository = LegalDocumentRepository(
        dio,
        snapshotReader: (_, documentId, _) async => cached[documentId],
        snapshotWriter: (_, documentId, _, payload) async {
          cached[documentId] = LegalDocumentModel.fromJson(payload);
        },
        snapshotDeleter: (_, documentId, _) async {
          cached.remove(documentId);
        },
      );
      await repository.saveDocumentSnapshot(
        projectId: 7,
        documentId: 44,
        identity: identity,
        payload: _document(44),
      );

      await expectLater(
        repository.fetchDocument(44, projectId: 7, identity: identity),
        throwsA(isA<ApiException>()),
      );
      expect(cached, isEmpty);
    },
  );
}

Map<String, dynamic> _document(int id, {String? title}) => {
  'id': id,
  'title': title ?? 'Документ $id',
  'document_type_label': 'Договор',
  'status': 'active',
};

class _LegalDocumentJsonAdapter implements HttpClientAdapter {
  _LegalDocumentJsonAdapter(this.handler);

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
