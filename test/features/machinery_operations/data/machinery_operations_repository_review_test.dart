import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/machinery_operations/data/machinery_operations_repository.dart';

void main() {
  test(
    'review mutations use dedicated POST endpoints without replay headers',
    () async {
      final adapter = _CaptureAdapter();
      final repository = MachineryOperationsRepository(
        Dio()..httpClientAdapter = adapter,
      );

      await repository.approveShiftReport(71);
      await repository.rejectShiftReport(72, '  Нет показаний  ');

      expect(adapter.requests, hasLength(2));
      expect(
        adapter.requests[0].path,
        '/machinery-operations/shift-reports/71/approve',
      );
      expect(adapter.requests[0].method, 'POST');
      expect(
        adapter.requests[0].headers.containsKey('Idempotency-Key'),
        isFalse,
      );
      expect(adapter.requests[0].data, isNull);
      expect(
        adapter.requests[1].path,
        '/machinery-operations/shift-reports/72/reject',
      );
      expect(adapter.requests[1].data, {'reason': 'Нет показаний'});
      expect(
        adapter.requests[1].headers.containsKey('Idempotency-Key'),
        isFalse,
      );
    },
  );

  test('reject refuses empty reason before sending request', () async {
    final adapter = _CaptureAdapter();
    final repository = MachineryOperationsRepository(
      Dio()..httpClientAdapter = adapter,
    );

    await expectLater(
      repository.rejectShiftReport(72, '  '),
      throwsA(isA<FormatException>()),
    );
    expect(adapter.requests, isEmpty);
  });
}

class _CaptureAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString('{"success":true}', 200);
  }
}
