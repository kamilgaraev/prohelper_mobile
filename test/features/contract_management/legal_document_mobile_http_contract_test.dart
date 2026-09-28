import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/storage/encrypted_local_file_cache.dart';
import 'package:prohelpers_mobile/features/contract_management/data/legal_document_model.dart';
import 'package:prohelpers_mobile/features/contract_management/data/legal_document_repository.dart';

void main() {
  test(
    'workflow action sends the mobile command and parses the document resource',
    () async {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _ContractAdapter((options, _) async {
        request = options;
        return _jsonResponse({
          'success': true,
          'data': _mobileDocumentResource(),
        });
      });

      final document = await LegalDocumentRepository(dio).performAction(
        documentId: 44,
        action: const LegalDocumentAction(
          action: 'approve',
          label: 'Согласовать',
          enabled: true,
          blockers: [],
          targetStepId: 12,
          expectedInstanceLockVersion: 3,
          expectedStepLockVersion: 5,
        ),
        comment: '  Проверено  ',
        reason: '  Оснований для отказа нет  ',
      );

      expect(request.method, 'POST');
      expect(request.path, '/legal-archive/documents/44/actions/approve');
      final body = Map<String, dynamic>.from(request.data as Map);
      expect(body['target_step_id'], 12);
      expect(body['instance_lock_version'], 3);
      expect(body['step_lock_version'], 5);
      expect(body['comment'], 'Проверено');
      expect(body['reason'], 'Оснований для отказа нет');
      expect(body['idempotency_key'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      final keyHeader =
          request.headers.entries
              .firstWhere(
                (entry) => entry.key.toLowerCase() == 'idempotency-key',
              )
              .value;
      expect(keyHeader, body['idempotency_key']);
      expect(document.id, 44);
      expect(document.title, 'Договор поставки');
      expect(document.lockVersion, 7);
    },
  );

  test('paper original upload sends multipart fields and file bytes', () async {
    final root = await Directory.systemTemp.createTemp('most-legal-upload-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final source = File(
      '${root.path}${Platform.pathSeparator}signed-original.pdf',
    );
    const pdf = '%PDF-1.4\nlegal mobile contract fixture\n%%EOF';
    await source.writeAsBytes(utf8.encode(pdf));
    final cache = EncryptedLocalFileCache(
      keyStore: _MemoryFileKeyStore(),
      directoryProvider: () async => root,
      temporaryDirectoryProvider: () async => root,
    );
    String? multipartBody;
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _ContractAdapter((options, stream) async {
      request = options;
      final bytes = BytesBuilder(copy: false);
      if (stream != null) {
        await for (final chunk in stream) {
          bytes.add(chunk);
        }
      }
      multipartBody = latin1.decode(bytes.takeBytes(), allowInvalid: true);
      return _jsonResponse({'success': true, 'data': null}, statusCode: 201);
    });
    final repository = LegalDocumentRepository(
      dio,
      currentOwnerIdentity: () => '5:8:legal-contract-test',
      fileCache: cache,
    );

    await repository.uploadPaperOriginal(
      documentId: 44,
      signatureRequestId: 91,
      filePath: source.path,
      signedAt: DateTime.utc(2026, 9, 27, 10, 30),
      documentLockVersion: 7,
      idempotencyKey: '1f0a1220-05cc-4d21-ae62-8b75d546b8bd',
    );

    expect(request.method, 'POST');
    expect(
      request.path,
      '/legal-archive/signature-requests/91/upload-original',
    );
    expect(request.headers['content-type'], startsWith('multipart/form-data'));
    expect(multipartBody, contains('name="signed_at"'));
    expect(multipartBody, contains('2026-09-27T10:30:00.000Z'));
    expect(multipartBody, contains('name="lock_version"'));
    expect(multipartBody, contains('7'));
    expect(multipartBody, contains('name="idempotency_key"'));
    expect(multipartBody, contains('1f0a1220-05cc-4d21-ae62-8b75d546b8bd'));
    expect(
      multipartBody,
      contains('name="file"; filename="signed-original.pdf"'),
    );
    expect(multipartBody, contains(pdf));
  });
}

Map<String, dynamic> _mobileDocumentResource() => {
  'id': 44,
  'title': 'Договор поставки',
  'document_type': 'contract',
  'document_type_label': 'Договор',
  'status': 'in_progress',
  'status_label': 'На согласовании',
  'lock_version': 7,
  'counterparty_name': 'Поставщик',
  'current_version': {'id': 10, 'version_number': 1, 'content_hash': 'abc'},
  'versions': [
    {'id': 10, 'version_number': 1, 'content_hash': 'abc'},
  ],
  'signature_summary': {'status': 'not_signed'},
  'signature_requests': [],
  'workflow_summary': {
    'status': 'in_progress',
    'available_action_details': [],
    'problem_flags': [],
  },
  'obligations': [],
};

ResponseBody _jsonResponse(Map<String, dynamic> data, {int statusCode = 200}) =>
    ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _ContractAdapter implements HttpClientAdapter {
  _ContractAdapter(this.handler);

  final Future<ResponseBody> Function(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
  )
  handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options, requestStream);
}

class _MemoryFileKeyStore implements SecureFileKeyStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
