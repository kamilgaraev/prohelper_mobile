import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:prohelpers_mobile/features/contract_management/data/legal_document_repository.dart';
import 'package:prohelpers_mobile/features/contract_management/data/legal_document_snapshot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'сохраняет полный архив, продолжает прерванную синхронизацию и изолирует владельцев',
    (tester) async {
      final root = await getTemporaryDirectory();
      final directory = await Directory(
        '${root.path}/legal-archive-offline-test',
      ).create(recursive: true);
      const identity = LegalDocumentCacheIdentity(
        userId: 10,
        organizationId: 20,
        sessionId: 'session-one',
      );
      const otherIdentity = LegalDocumentCacheIdentity(
        userId: 11,
        organizationId: 20,
        sessionId: 'session-two',
      );

      var isar = await _openIsar(directory.path);
      try {
        final initialAdapter = _LegalArchiveAdapter((options) {
          final afterId = _queryInt(options, 'sync_after_id');
          if (afterId == 0) {
            return _page(
              List.generate(50, (index) => _document(index + 1)),
              nextCursor: 50,
              hasMore: true,
              syncMaxId: 51,
            );
          }
          if (afterId == 50) {
            return _page(
              [_document(51)],
              nextCursor: null,
              hasMore: false,
              syncMaxId: 51,
            );
          }
          throw StateError('unexpected_initial_cursor_$afterId');
        });
        final initialRepository = _repository(isar, initialAdapter);
        final initialResult = await initialRepository.fetchDocumentList(
          projectId: 7,
          identity: identity,
        );
        expect(initialResult.documents, hasLength(51));
        expect(initialResult.isPartial, isFalse);

        await isar.close();
        isar = await _openIsar(directory.path);
        final reopenedRepository = _repository(
          isar,
          _LegalArchiveAdapter(
            (_) => throw StateError('network_should_not_be_used'),
          ),
        );
        final reopened = await reopenedRepository.readListSnapshot(
          projectId: 7,
          identity: identity,
        );
        expect(reopened.documents, hasLength(51));
        expect(reopened.documents.last.id, 51);
        expect(
          (await reopenedRepository.readListSnapshot(
            projectId: 7,
            identity: otherIdentity,
          )).documents,
          isEmpty,
        );

        var interruptedRequests = 0;
        final interruptedAdapter = _LegalArchiveAdapter((options) {
          interruptedRequests++;
          final afterId = _queryInt(options, 'sync_after_id');
          if (afterId == 0) {
            return _page(
              List.generate(
                50,
                (index) =>
                    _document(index + 1, title: 'Обновлённый ${index + 1}'),
              ),
              nextCursor: 50,
              hasMore: true,
              syncMaxId: 52,
            );
          }
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            message: 'connection interrupted',
          );
        });
        final interruptedRepository = _repository(isar, interruptedAdapter);
        final partial = await interruptedRepository.fetchDocumentList(
          projectId: 7,
          identity: identity,
        );
        expect(interruptedRequests, 2);
        expect(partial.isPartial, isTrue);
        expect(partial.documents, hasLength(51));
        expect(partial.documents.first.title, 'Обновлённый 1');

        await isar.close();
        isar = await _openIsar(directory.path);
        final afterInterruptRepository = _repository(
          isar,
          _LegalArchiveAdapter((options) {
            expect(_queryInt(options, 'sync_after_id'), 50);
            expect(_queryInt(options, 'sync_max_id'), 52);
            return _page(
              [_document(51), _document(52)],
              nextCursor: null,
              hasMore: false,
              syncMaxId: 52,
            );
          }),
        );
        final preservedComplete = await afterInterruptRepository
            .readListSnapshot(projectId: 7, identity: identity);
        expect(preservedComplete.documents, hasLength(51));
        expect(preservedComplete.documents.first.title, 'Документ 1');

        final resumed = await afterInterruptRepository.fetchDocumentList(
          projectId: 7,
          identity: identity,
        );
        expect(resumed.isPartial, isFalse);
        expect(resumed.documents, hasLength(52));
        expect(resumed.documents.first.title, 'Обновлённый 1');
        expect(
          (await afterInterruptRepository.readListSnapshot(
            projectId: 7,
            identity: otherIdentity,
          )).documents,
          isEmpty,
        );
      } finally {
        await isar.close(deleteFromDisk: true);
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    },
  );
}

Future<Isar> _openIsar(String directory) => Isar.open(
  [LegalDocumentSnapshotSchema],
  directory: directory,
  name: 'legal-archive-offline-integration',
);

LegalDocumentRepository _repository(Isar isar, HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
    ..httpClientAdapter = adapter;
  return LegalDocumentRepository(dio, isar: Future.value(isar));
}

int _queryInt(RequestOptions options, String key) =>
    int.parse(options.queryParameters[key].toString());

Map<String, dynamic> _page(
  List<Map<String, dynamic>> documents, {
  required int? nextCursor,
  required bool hasMore,
  required int syncMaxId,
}) => {
  'success': true,
  'data': {'data': documents},
  'meta': {
    'next_cursor': nextCursor,
    'has_more': hasMore,
    'sync_max_id': syncMaxId,
    'per_page': 50,
  },
};

Map<String, dynamic> _document(int id, {String? title}) => {
  'id': id,
  'title': title ?? 'Документ $id',
  'document_type_label': 'Договор',
  'status': 'active',
};

class _LegalArchiveAdapter implements HttpClientAdapter {
  _LegalArchiveAdapter(this.handler);

  final Map<String, dynamic> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = handler(options);
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
