import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/contract_management/data/legal_document_model.dart';
import 'package:prohelpers_mobile/features/contract_management/data/legal_document_repository.dart';

void main() {
  test('normalizes workflow actions and optional legal document fields', () {
    final document = LegalDocumentModel.fromJson({
      'id': 44,
      'title': 'Договор подряда',
      'document_type_label': 'Договор',
      'status': 'active',
      'workflow_summary': {
        'status': 'in_progress',
        'available_action_details': [
          {'action': 'approve', 'label': 'Согласовать', 'enabled': true, 'blockers': []},
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

  test('uses exact protected version route and rejects insecure response URL', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _LegalDocumentJsonAdapter((options) {
      request = options;
      return {'success': true, 'data': {'url': 'https://storage.example.test/file'}};
    });

    final url = await LegalDocumentRepository(dio).fetchVersionUrl(
      documentId: 44,
      versionId: 10,
      purpose: 'preview',
    );

    expect(request.method, 'GET');
    expect(request.path, '/legal-archive/documents/44/versions/10/preview');
    expect(url.scheme, 'https');

    dio.httpClientAdapter = _LegalDocumentJsonAdapter((_) => {'success': true, 'data': {'url': 'http://unsafe.test/file'}});
    await expectLater(
      LegalDocumentRepository(dio).fetchVersionUrl(documentId: 44, versionId: 10, purpose: 'download'),
      throwsA(isA<FormatException>()),
    );
  });
}

class _LegalDocumentJsonAdapter implements HttpClientAdapter {
  _LegalDocumentJsonAdapter(this.handler);

  final Map<String, dynamic> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString(jsonEncode(handler(options)), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
}
