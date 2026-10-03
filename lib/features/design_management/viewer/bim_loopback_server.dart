import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

class BimLoopbackResource {
  const BimLoopbackResource({
    required this.length,
    required this.mime,
    required this.read,
  });

  final int length;
  final String mime;
  final Stream<List<int>> Function(int start, int end) read;
}

class BimLoopbackServer {
  BimLoopbackServer()
    : capability = base64Url
          .encode(List.generate(32, (_) => Random.secure().nextInt(256)))
          .replaceAll('=', '');

  final String capability;
  final _resources = <String, BimLoopbackResource>{};
  final _uploads = <String>{};
  final _snapshots = <String, Uint8List>{};
  HttpServer? _server;
  bool _closed = false;

  Uri get baseUri =>
      Uri.parse('http://127.0.0.1:${_server!.port}/$capability/');

  Future<void> start() async {
    if (_server != null) return;
    if (_closed) throw StateError('Viewer closed');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    if (_closed) {
      await server.close(force: true);
      throw StateError('Viewer closed');
    }
    _server = server;
    _server!.listen(_handle);
  }

  Uri register(String path, BimLoopbackResource resource) {
    if (_closed || !_validPath(path)) throw ArgumentError('Invalid resource');
    _resources[path] = resource;
    return baseUri.resolve(path);
  }

  Uri registerBytes(String path, Uint8List bytes, String mime) => register(
    path,
    BimLoopbackResource(
      length: bytes.length,
      mime: mime,
      read: (start, end) => Stream.value(bytes.sublist(start, end)),
    ),
  );

  Uri registerSnapshot(String id) {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw ArgumentError('Invalid snapshot');
    }
    final path = 'snapshots/$id.png';
    _uploads.add(path);
    return baseUri.resolve(path);
  }

  Uint8List takeSnapshot(Uri uri) {
    if (uri.origin != baseUri.origin || !uri.path.startsWith(baseUri.path)) {
      throw ArgumentError('Invalid snapshot URL');
    }
    final path = uri.path.substring(baseUri.path.length);
    final bytes = _snapshots.remove(path);
    if (bytes == null) throw StateError('Snapshot not received');
    return bytes;
  }

  bool _validPath(String path) =>
      path.isNotEmpty &&
      !path.startsWith('/') &&
      path
          .split('/')
          .every(
            (part) =>
                part != '.' &&
                part != '..' &&
                RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(part),
          );

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      response.headers.set('X-Content-Type-Options', 'nosniff');
      response.headers.set('Cache-Control', 'no-store');
      response.headers.set(
        'Content-Security-Policy',
        "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; "
            "worker-src 'self' blob:; connect-src 'self' wss: "
            "ws://127.0.0.1:* ws://localhost:*; "
            "img-src 'self' blob: data:; object-src 'none'; frame-src 'none'",
      );
      final prefix = '/$capability/';
      final path = request.uri.path;
      if (_closed || !path.startsWith(prefix)) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      final resourcePath = path.substring(prefix.length);
      if (!_validPath(resourcePath)) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      if (request.method == 'POST' && _uploads.remove(resourcePath)) {
        await _receiveSnapshot(request, resourcePath);
        return;
      }
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      final resource = _resources[resourcePath];
      if (resource == null) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      var start = 0;
      var end = resource.length;
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null) {
        final match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range);
        if (match == null) {
          response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          return;
        }
        start = int.parse(match.group(1)!);
        if (match.group(2)!.isNotEmpty) end = int.parse(match.group(2)!) + 1;
        if (start >= resource.length || start >= end || end > resource.length) {
          response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          response.headers.set('Content-Range', 'bytes */${resource.length}');
          return;
        }
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(
          'Content-Range',
          'bytes $start-${end - 1}/${resource.length}',
        );
      }
      response.headers.set('Accept-Ranges', 'bytes');
      response.headers.set(HttpHeaders.contentTypeHeader, resource.mime);
      response.contentLength = end - start;
      if (request.method == 'GET') {
        await response.addStream(resource.read(start, end));
      }
    } catch (_) {
      try {
        response.statusCode = HttpStatus.internalServerError;
      } catch (_) {}
    } finally {
      try {
        await response.close();
      } catch (_) {}
    }
  }

  Future<void> _receiveSnapshot(HttpRequest request, String path) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      if (builder.length + chunk.length > 10 * 1024 * 1024) {
        request.response.statusCode = HttpStatus.requestEntityTooLarge;
        return;
      }
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    const png = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < png.length ||
        List.generate(png.length, (i) => bytes[i] == png[i]).contains(false)) {
      request.response.statusCode = HttpStatus.unsupportedMediaType;
      return;
    }
    if (_closed) return;
    _snapshots[path] = bytes;
    request.response.statusCode = HttpStatus.created;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({'url': baseUri.resolve(path).toString()}),
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _resources.clear();
    _uploads.clear();
    _snapshots.clear();
    await _server?.close(force: true);
    _server = null;
  }
}
