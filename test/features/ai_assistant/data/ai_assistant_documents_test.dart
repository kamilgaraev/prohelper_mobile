import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_models.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_repository.dart';

void main() {
  test(
    'loads actor coverage and confirms exact owner OCR budget contract',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio(
        BaseOptions(baseUrl: 'https://api.example.test/api/v1/mobile'),
      );
      dio.httpClientAdapter = _Adapter((request) {
        requests.add(request);
        final data =
            request.path.endsWith('/status')
                ? {
                  'document_coverage': {
                    'total': 4,
                    'ready': 2,
                    'ocr_required': 1,
                    'pending': 1,
                    'total_pages': 10,
                    'ocr_completed_pages': 3,
                  },
                  'archive_scan': {
                    'expected_file_count': 12,
                    'scanned_file_count': 8,
                    'processing': true,
                  },
                  'can_manage_document_settings': true,
                }
                : {
                  'enabled': true,
                  'scope': 'archive',
                  'limit_minor': 2550,
                  'reserved_minor': 100,
                  'spent_minor': 50,
                  'available_minor': 2400,
                };
        return _json(data);
      });
      final repository = AiAssistantRepository(dio);
      final status = await repository.fetchDocumentProcessing();
      final budget = await repository.fetchDocumentBudget();
      await repository.approveDocumentBudget(
        enabled: true,
        scope: 'archive',
        limitMinor: 2550,
      );
      expect(status.documentCoverage['ocr_completed_pages'], 3);
      expect(status.archiveScan.scanned, 8);
      expect(status.canManageSettings, true);
      expect(budget.availableMinor, 2400);
      expect(requests[1].method, 'GET');
      expect(requests[2].method, 'PUT');
      expect(requests[2].data, {
        'enabled': true,
        'scope': 'archive',
        'limit_minor': 2550,
        'confirmed': true,
      });
      await expectLater(
        repository.approveDocumentBudget(
          enabled: true,
          scope: 'organization',
          limitMinor: 10,
        ),
        throwsException,
      );
      expect(requests, hasLength(3));
    },
  );
  test(
    'downloads reports with authorization and cleans temporary file',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'most-assistant-test-',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://api.example.test/api/v1/mobile',
          headers: {'Authorization': 'Bearer test-secret'},
        ),
      );
      dio.httpClientAdapter = _Adapter((request) {
        expect(request.headers['Authorization'], 'Bearer test-secret');
        expect(request.uri.toString(), isNot(contains('test-secret')));
        expect(request.followRedirects, false);
        return ResponseBody.fromBytes(
          [37, 80, 68, 70],
          200,
          headers: {
            Headers.contentTypeHeader: ['application/pdf'],
          },
        );
      });
      final report = await AiAssistantRepository(dio).downloadReport(
        const AiAssistantArtifact(
          filename: 'report.pdf',
          downloadUrl: 'https://api.example.test/api/reports/12/download',
        ),
        temporaryDirectory: root,
      );
      expect(await File(report.path).readAsBytes(), [37, 80, 68, 70]);
      await report.dispose();
      expect(await Directory(report.directory.path).exists(), false);
    },
  );
  test(
    'does not send authorization to external report hosts or redirects',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'most-assistant-test-',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      var calls = 0;
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://api.example.test/api/v1/mobile',
          headers: {'Authorization': 'Bearer test-secret'},
        ),
      );
      dio.httpClientAdapter = _Adapter((request) {
        calls++;
        return ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': ['https://evil.example.test/report.pdf'],
          },
        );
      });
      final repository = AiAssistantRepository(dio);
      await expectLater(
        repository.downloadReport(
          const AiAssistantArtifact(
            filename: 'report.pdf',
            downloadUrl: 'https://evil.example.test/report.pdf',
          ),
          temporaryDirectory: root,
        ),
        throwsException,
      );
      expect(calls, 0);
      await expectLater(
        repository.downloadReport(
          const AiAssistantArtifact(
            filename: 'report.pdf',
            downloadUrl: 'https://api.example.test/report.pdf',
          ),
          temporaryDirectory: root,
        ),
        throwsException,
      );
      expect(calls, 1);
      expect(await root.list().toList(), isEmpty);
    },
  );
}

ResponseBody _json(Map<String, dynamic> data) => ResponseBody.fromString(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final ResponseBody Function(RequestOptions) handler;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);
}
