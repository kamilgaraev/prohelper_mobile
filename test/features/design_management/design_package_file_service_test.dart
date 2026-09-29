import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/design_management/data/design_package_file_service.dart';

class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.bytes) : headersSeen = {};

  final List<int> bytes;
  final Map<String, List<String>> headersSeen;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    options.headers.forEach((key, value) {
      headersSeen[key.toString().toLowerCase()] = [value.toString()];
    });
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/pdf'],
      },
    );
  }
}

void main() {
  late Directory root;
  late Dio client;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('most-pir-test-');
    client = Dio();
  });

  tearDown(() async {
    client.close(force: true);
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('downloads actual bytes to a private safe temporary path', () async {
    final adapter = _BytesAdapter([37, 80, 68, 70, 45, 49]);
    client.httpClientAdapter = adapter;
    final service = DesignPackageFileService(
      client: client,
      temporaryDirectory: () async => root,
    );

    final path = await service.download(
      Uri.parse('https://storage.example.test/presigned'),
      r'folder\unsafe name.pdf',
    );
    final file = File(path);

    expect(await file.readAsBytes(), [37, 80, 68, 70, 45, 49]);
    expect(file.parent.parent.path, root.path);
    expect(file.path, endsWith('unsafe_name.pdf'));
    expect(adapter.headersSeen['authorization'], isNull);

    await service.deleteDownloaded(path);
    expect(await file.parent.exists(), isFalse);
  });

  test('converts download connection failures to Russian API errors', () async {
    final adapter = _ConnectionErrorAdapter();
    client.httpClientAdapter = adapter;
    final service = DesignPackageFileService(
      client: client,
      temporaryDirectory: () async => root,
    );

    await expectLater(
      service.download(
        Uri.parse('https://storage.example.test/presigned'),
        'file.pdf',
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Нет соединения с сервером. Проверьте интернет.',
        ),
      ),
    );
    expect(await root.list().toList(), isEmpty);
  });

  test(
    'cleanup preserves files outside directories owned by the download',
    () async {
      final unrelated = File(
        '${root.path}${Platform.pathSeparator}existing.pdf',
      );
      await unrelated.writeAsString('existing file');
      final service = DesignPackageFileService(
        client: client,
        temporaryDirectory: () async => root,
      );

      await service.deleteDownloaded(unrelated.path);

      expect(await unrelated.readAsString(), 'existing file');
      expect(await root.exists(), isTrue);
    },
  );

  test('removes partial download after an HTTP error response', () async {
    client.httpClientAdapter = _HttpErrorAdapter();
    final service = DesignPackageFileService(
      client: client,
      temporaryDirectory: () async => root,
    );

    await expectLater(
      service.download(
        Uri.parse('https://storage.example.test/presigned'),
        'file.pdf',
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          503,
        ),
      ),
    );
    expect(await root.list().toList(), isEmpty);
  });
}

class _ConnectionErrorAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
  }
}

class _HttpErrorAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('', 503);
}
