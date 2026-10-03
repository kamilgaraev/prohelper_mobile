import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Usage: dart serve_bim_fixture.dart <real-fixture.frag>');
    exitCode = 64;
    return;
  }
  final file = File(args.single).absolute;
  final length = await file.length();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  stdout.writeln(
    'BIM_FIXTURE_URL=http://127.0.0.1:${server.port}/ifc-express-ids.frag bytes=$length',
  );
  await for (final request in server) {
    if (request.uri.path != '/ifc-express-ids.frag' ||
        request.uri.hasQuery ||
        !['GET', 'HEAD'].contains(request.method)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }
    request.response.headers.contentType = ContentType.binary;
    request.response.contentLength = length;
    if (request.method == 'GET') {
      await request.response.addStream(file.openRead());
    }
    await request.response.close();
  }
}
