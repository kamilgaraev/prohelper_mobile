import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_store.dart';
import 'package:prohelpers_mobile/features/machinery_operations/data/machinery_operations_repository.dart';
import 'package:prohelpers_mobile/features/machinery_operations/domain/machinery_action.dart';

void main() {
  test(
    'operator start shift sends the inspected start action to mobile API',
    () async {
      final adapter = _ContractAdapter(
        (request) => _jsonResponse({
          'success': true,
          'data': {
            'id': 81,
            'asset_id': 10,
            'project_id': 30,
            'assignment_id': 20,
            'report_date': '2026-09-28',
            'status': 'active',
            'status_label': 'Смена начата',
            'actual_hours': 0,
            'fuel_consumed': 0,
            'meter_start': 125.5,
            'available_actions': <String>[],
          },
        }, 201),
      );
      final repository = MachineryOperationsRepository(_dio(adapter));
      const key = 'operator-start-shift-00081';

      final result = await repository.executeAction(
        StartShiftAction(
          10,
          assignmentId: 20,
          projectId: 30,
          meterStart: 125.5,
          preShiftInspection: const {
            'result': 'restricted',
            'notes': 'Утечка устранена временно',
            'defects': <Map<String, dynamic>>[],
          },
          idempotencyKey: key,
        ),
      );

      expect(adapter.requests.single.method, 'POST');
      expect(
        adapter.requests.single.path,
        '/machinery-operations/shift-reports',
      );
      expect(adapter.requests.single.headers['Idempotency-Key'], key);
      final payload = adapter.requests.single.data as Map<String, dynamic>;
      expect(payload, containsPair('asset_id', 10));
      expect(payload, containsPair('project_id', 30));
      expect(payload, containsPair('assignment_id', 20));
      expect(payload, containsPair('actual_hours', 0));
      expect(payload, containsPair('fuel_consumed', 0));
      expect(payload, containsPair('meter_start', 125.5));
      expect(payload['report_date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(payload['pre_shift_inspection'], {
        'result': 'restricted',
        'notes': 'Утечка устранена временно',
        'defects': <Map<String, dynamic>>[],
      });
      expect(result, containsPair('id', 81));
      expect(result, containsPair('status', 'active'));
    },
  );

  test(
    'fuel issue and downtime send backend field names and parse server errors',
    () async {
      final adapter = _ContractAdapter(
        (request) => _jsonResponse({
          'success': true,
          'data': {'id': request.path.endsWith('fuel-issues') ? 92 : 93},
        }, 201),
      );
      final repository = MachineryOperationsRepository(_dio(adapter));

      await repository.createFuelIssue(
        assetId: 10,
        projectId: 30,
        shiftReportId: 81,
        warehouseId: 4,
        materialId: 17,
        issuedAt: '2026-09-28T11:15:00Z',
        fuelType: ' дизель ',
        quantity: 42.5,
        unit: ' л ',
        comment: '  Заправка смены  ',
      );
      await repository.executeAction(
        RecordDowntimeAction(
          10,
          projectId: 30,
          shiftId: 81,
          reasonCode: 'breakdown',
          startedAt: DateTime.utc(2026, 9, 28, 12),
          durationMinutes: 35,
          comment: '  Осмотр механиком  ',
        ),
      );

      expect(adapter.requests.map((request) => request.path), [
        '/machinery-operations/fuel-issues',
        '/machinery-operations/downtimes',
      ]);
      expect(adapter.requests.first.method, 'POST');
      expect(adapter.requests.first.headers['Idempotency-Key'], isNotEmpty);
      expect(adapter.requests.first.data, {
        'asset_id': 10,
        'project_id': 30,
        'shift_report_id': 81,
        'warehouse_id': 4,
        'material_id': 17,
        'issued_at': '2026-09-28T11:15:00.000Z',
        'fuel_type': 'дизель',
        'quantity': 42.5,
        'unit': 'л',
        'comment': 'Заправка смены',
        'idempotency_key': adapter.requests.first.data['idempotency_key'],
      });
      expect(adapter.requests.last.data, {
        'asset_id': 10,
        'project_id': 30,
        'shift_report_id': 81,
        'reason': 'breakdown',
        'started_at': '2026-09-28T12:00:00.000Z',
        'duration_minutes': 35,
        'comment': 'Осмотр механиком',
        'idempotency_key': adapter.requests.last.data['idempotency_key'],
      });

      final validation = _ContractAdapter(
        (_) => _errorResponse(422, {
          'quantity': ['Количество должно быть больше 0.'],
        }),
      );
      await expectLater(
        MachineryOperationsRepository(_dio(validation)).createFuelIssue(
          assetId: 10,
          projectId: 30,
          shiftReportId: 81,
          warehouseId: 4,
          materialId: 17,
          issuedAt: '2026-09-28T11:15:00Z',
          fuelType: 'дизель',
          quantity: 42.5,
          unit: 'л',
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            422,
          ),
        ),
      );

      final forbidden = _ContractAdapter((_) => _errorResponse(403, null));
      await expectLater(
        MachineryOperationsRepository(_dio(forbidden)).createDowntime(
          assetId: 10,
          projectId: 30,
          reason: 'breakdown',
          startedAt: '2026-09-28T12:00:00Z',
          durationMinutes: 35,
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            403,
          ),
        ),
      );
    },
  );

  test(
    'offline finish shift acceptance persists all entered inspection values',
    () async {
      final store = _MemorySyncQueueStore();
      final failed = <RequestOptions>[];
      final firstDio = Dio(
        BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
      )..httpClientAdapter = _OfflineAdapter(failed);
      const key = 'operator-finish-shift-replay-00045';
      final queue = SyncQueueService(
        store: store,
        dio: _successDio(<RequestOptions>[]),
        now: () => DateTime(2026, 9, 28),
      );
      final repository = MachineryOperationsRepository(
        firstDio,
        syncQueueServiceFuture: Future.value(queue),
      );
      final action = FinishShiftAction(
        10,
        shiftId: 45,
        actualHours: 7.5,
        fuelConsumed: 12.25,
        meterEnd: 142.75,
        postShiftInspection: const {
          'result': 'restricted',
          'notes': 'Небольшая утечка',
          'defects': <Map<String, dynamic>>[],
        },
        idempotencyKey: key,
      );

      await expectLater(
        repository.executeAction(action),
        throwsA(isA<SyncQueuedException>()),
      );

      final queued = (await store.all()).single;
      expect(queued.operationType, 'finish_shift');
      expect(queued.endpoint, '/machinery-operations/shift-reports/45/finish');
      expect(queued.payload, {
        'actual_hours': 7.5,
        'fuel_consumed': 12.25,
        'meter_end': 142.75,
        'post_shift_inspection': {
          'result': 'restricted',
          'notes': 'Небольшая утечка',
          'defects': <Map<String, dynamic>>[],
        },
        'idempotency_key': key,
      });
      expect(failed.single.headers['Idempotency-Key'], key);
    },
  );

  test(
    'queued operator shift keeps its idempotency key when replayed',
    () async {
      final store = _MemorySyncQueueStore();
      final failed = <RequestOptions>[];
      final firstDio = Dio(
        BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
      )..httpClientAdapter = _OfflineAdapter(failed);
      const key = 'operator-shift-replay-key-00081';
      final queue = SyncQueueService(
        store: store,
        dio: _successDio(<RequestOptions>[]),
        now: () => DateTime(2026, 9, 28),
      );
      final repository = MachineryOperationsRepository(
        firstDio,
        syncQueueServiceFuture: Future.value(queue),
      );

      await expectLater(
        repository.executeAction(
          StartShiftAction(
            10,
            assignmentId: 20,
            projectId: 30,
            meterStart: 125.5,
            preShiftInspection: const {'result': 'serviceable'},
            idempotencyKey: key,
          ),
        ),
        throwsA(isA<SyncQueuedException>()),
      );

      final queued = (await store.all()).single;
      expect(queued.payload['idempotency_key'], key);
      expect(failed.single.headers['Idempotency-Key'], key);

      final replayRequests = <RequestOptions>[];
      final result =
          await SyncQueueService(
            store: store,
            dio: _successDio(replayRequests),
            now: () => DateTime(2026, 9, 28, 0, 5),
          ).retryDueOperations();

      expect(result.successCount, 1);
      expect(replayRequests.single.path, '/machinery-operations/shift-reports');
      expect(replayRequests.single.headers['Idempotency-Key'], key);
      expect(
        (replayRequests.single.data as Map<String, dynamic>)['idempotency_key'],
        key,
      );
      expect(await store.all(), isEmpty);
    },
  );
}

Dio _dio(_ContractAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'))
      ..httpClientAdapter = adapter;

ResponseBody _jsonResponse(dynamic data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody _errorResponse(int status, dynamic errors) => _jsonResponse({
  'success': false,
  'message': 'Ошибка запроса',
  'errors': errors,
}, status);

class _ContractAdapter implements HttpClientAdapter {
  _ContractAdapter(this.respond);

  final ResponseBody Function(RequestOptions request) respond;
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
    return respond(options);
  }
}

class _OfflineAdapter implements HttpClientAdapter {
  _OfflineAdapter(this.requests);

  final List<RequestOptions> requests;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
  }
}

Dio _successDio(List<RequestOptions> requests) =>
    Dio(BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'))
      ..httpClientAdapter = _SuccessAdapter(requests);

class _SuccessAdapter implements HttpClientAdapter {
  _SuccessAdapter(this.requests);

  final List<RequestOptions> requests;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _jsonResponse({
      'success': true,
      'data': {'id': 81},
    }, 201);
  }
}

class _MemorySyncQueueStore implements SyncQueueStore {
  final Map<int, QueuedSyncOperation> _operations = {};
  var _nextId = 1;

  @override
  Future<QueuedSyncOperation> put(QueuedSyncOperation operation) async {
    if (operation.id == Isar.autoIncrement) operation.id = _nextId++;
    _operations[operation.id] = operation;
    return operation;
  }

  @override
  Future<List<QueuedSyncOperation>> all() async => _operations.values.toList();

  @override
  Future<List<QueuedSyncOperation>> due(DateTime now) async =>
      _operations.values
          .where(
            (operation) =>
                operation.status == SyncOperationStatuses.queued &&
                (operation.nextAttemptAt == null ||
                    !operation.nextAttemptAt!.isAfter(now)),
          )
          .toList();

  @override
  Future<QueuedSyncOperation?> get(int id) async => _operations[id];

  @override
  Future<void> delete(int id) async => _operations.remove(id);
}
