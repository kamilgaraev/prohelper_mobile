import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_models.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_repository.dart';

void main() {
  test('photo metadata keeps string identity and uploading organization', () {
    final photo = ConstructionJournalAttachment.fromJson({
      'id': 'photo-uuid',
      'file_name': 'Участок.png',
      'mime_type': 'image/png',
      'size': 8,
      'uploaded_by': {'id': 7, 'name': 'Инженер', 'organization_id': 9},
    });
    expect(photo.id, 'photo-uuid');
    expect(photo.fileName, 'Участок.png');
    expect(photo.uploadedByName, 'Инженер');
    expect(photo.uploadedByOrganizationId, 9);
  });

  test(
    'private download grant accepts https and rejects a public file scheme',
    () {
      final grant = ConstructionJournalAttachmentDownload.fromJson({
        'url': 'https://storage.example.test/photo?signature=temporary',
        'expires_at': '2026-10-11T12:00:00Z',
      });
      expect(grant.url.scheme, 'https');
      expect(grant.expiresAt, isNotNull);
      expect(
        () => ConstructionJournalAttachmentDownload.fromJson({
          'url': 'file:///private/photo.png',
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'online photo upload uses scoped multipart file and never prepares a sync operation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'most-photo-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final photo = File('${directory.path}/site.png');
      await photo.writeAsBytes([137, 80, 78, 71]);
      RequestOptions? request;
      final dio =
          Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  request = options;
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      statusCode: 201,
                      data: {'data': {}},
                    ),
                  );
                },
              ),
            );
      final unusedQueue = Completer<SyncQueueService>();
      await ConstructionJournalRepository(
        dio,
        syncQueueServiceFuture: unusedQueue.future,
      ).uploadAttachment(84, photo.path);
      expect(request!.path, '/journal-entries/84/attachments');
      expect(request!.method, 'POST');
      final body = request!.data as FormData;
      expect(body.files.single.key, 'file');
      expect(body.files.single.value.filename, 'site.png');
      expect(body.fields, isEmpty);
    },
  );

  test('offline upload reports error instead of enqueueing a file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'most-photo-offline-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final photo = File('${directory.path}/site.jpg');
    await photo.writeAsBytes([1, 2]);
    final dio =
        Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest:
                  (options, handler) => handler.reject(
                    DioException(
                      requestOptions: options,
                      type: DioExceptionType.connectionError,
                    ),
                  ),
            ),
          );
    final unusedQueue = Completer<SyncQueueService>();
    await expectLater(
      ConstructionJournalRepository(
        dio,
        syncQueueServiceFuture: unusedQueue.future,
      ).uploadAttachment(84, photo.path),
      throwsA(isA<ApiException>()),
    );
  });

  test('download request uses the entry and attachment identity', () async {
    late RequestOptions request;
    final dio =
        Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                request = options;
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: {
                      'data': {
                        'url':
                            'https://storage.example.test/private-photo?signature=temporary',
                        'expires_at': '2026-10-11T12:00:00Z',
                      },
                    },
                  ),
                );
              },
            ),
          );
    final grant = await ConstructionJournalRepository(
      dio,
    ).attachmentDownload(84, 'photo-uuid');
    expect(request.path, '/journal-entries/84/attachments/photo-uuid/download');
    expect(grant.url.queryParameters['signature'], 'temporary');
  });
}
