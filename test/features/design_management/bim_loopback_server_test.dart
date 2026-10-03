import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/design_management/viewer/bim_loopback_server.dart';

void main() {
  late BimLoopbackServer server;
  late HttpClient client;

  setUp(() async {
    server = BimLoopbackServer();
    await server.start();
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.close();
  });

  test('receives a PNG through the one-time snapshot upload', () async {
    final url = server.registerSnapshot('capture');
    final png = [137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3];
    final request = await client.postUrl(url);
    request.add(png);
    final response = await request.close();
    expect(response.statusCode, 201);
    await response.drain<void>();
    expect(server.takeSnapshot(url), png);
    server.discardSnapshot(url);
    expect(() => server.takeSnapshot(url), throwsStateError);
  });

  test('failed captures revoke their unused upload URL', () async {
    final url = server.registerSnapshot('failed');
    server.discardSnapshot(url);
    final request = await client.postUrl(url);
    request.add([137, 80, 78, 71, 13, 10, 26, 10]);
    final response = await request.close();
    expect(response.statusCode, 405);
    await response.drain<void>();
    expect(() => server.takeSnapshot(url), throwsStateError);
    expect(
      () => server.discardSnapshot(
        Uri.parse('http://127.0.0.1:1/snapshots/failed.png'),
      ),
      throwsArgumentError,
    );
  });

  test(
    'serves only registered resources under the viewer capability',
    () async {
      final uri = server.registerBytes(
        'models/7.frag',
        Uint8List.fromList([1, 2, 3]),
        'application/octet-stream',
      );
      final request = await client.getUrl(uri);
      final response = await request.close();
      expect(response.statusCode, 200);
      expect(
        await response.fold<List<int>>(
          [],
          (previous, chunk) => previous..addAll(chunk),
        ),
        [1, 2, 3],
      );
      for (final path in [
        '/models/7.frag',
        '/wrong/models/7.frag',
        '${server.baseUri.path}unknown.frag',
      ]) {
        final invalid = await client.getUrl(uri.replace(path: path));
        final denied = await invalid.close();
        expect(denied.statusCode, 404);
        await denied.drain<void>();
      }
      expect(
        () => server.registerBytes('../secret', Uint8List(0), 'text/plain'),
        throwsArgumentError,
      );
    },
  );

  test('streams exact byte ranges and rejects invalid ranges', () async {
    int? readStart;
    int? readEnd;
    final uri = server.register(
      'model.frag',
      BimLoopbackResource(
        length: 10,
        mime: 'application/octet-stream',
        read: (start, end) {
          readStart = start;
          readEnd = end;
          return Stream.value(
            List.generate(end - start, (index) => start + index),
          );
        },
      ),
    );
    final request = await client.getUrl(uri);
    request.headers.set('Range', 'bytes=3-5');
    final response = await request.close();
    expect(response.statusCode, 206);
    expect(response.headers.value('Content-Range'), 'bytes 3-5/10');
    expect(
      await response.fold<List<int>>(
        [],
        (previous, chunk) => previous..addAll(chunk),
      ),
      [3, 4, 5],
    );
    expect(readStart, 3);
    expect(readEnd, 6);
    final invalid = await client.getUrl(uri);
    invalid.headers.set('Range', 'bytes=10-11');
    final denied = await invalid.close();
    expect(denied.statusCode, 416);
    await denied.drain<void>();
  });

  test(
    'PNG upload is binary, registered, one use, and released on take',
    () async {
      final uri = server.registerSnapshot('snapshot-1');
      final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]);
      final request = await client.postUrl(uri);
      request.add(png);
      final response = await request.close();
      expect(response.statusCode, 201);
      await response.drain<void>();
      expect(server.takeSnapshot(uri), png);
      expect(() => server.takeSnapshot(uri), throwsStateError);
      final repeat = await client.postUrl(uri);
      final denied = await repeat.close();
      expect(denied.statusCode, 405);
      await denied.drain<void>();
    },
  );
}
