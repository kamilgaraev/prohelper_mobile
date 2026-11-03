import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import '../../../core/sync/sync_queue_draft.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../../core/sync/sync_queue_repository.dart';
import '../../../core/sync/sync_queue_service.dart';
import 'incoming_control_model.dart';
import 'incoming_control_upload.dart';

final incomingControlRepositoryProvider = Provider<IncomingControlRepository>((
  ref,
) {
  return IncomingControlRepository(
    ref.read(dioProvider),
    syncQueueServiceFuture: ref.read(syncQueueServiceProvider.future),
  );
});

class IncomingControlRepository extends SyncQueueAwareRepository {
  IncomingControlRepository(
    this._dio, {
    Future<SyncQueueService>? syncQueueServiceFuture,
  }) : super(syncQueueServiceFuture);
  final Dio _dio;
  static const endpoint = '/quality-control/incoming-controls';

  Future<IncomingControlPage> fetchPage({
    required int projectId,
    int page = 1,
    String? status,
    String? search,
    String? sourceType,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'project_id': projectId,
          'page': page,
          'per_page': 30,
          if (status != null) 'status': status,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          if (sourceType != null) 'source_type': sourceType,
          if (dateFrom != null) 'date_from': dateFrom,
          if (dateTo != null) 'date_to': dateTo,
        },
      );
      final result = MobileApiResponse.list(response.data);
      return IncomingControlPage(
        result.data.map(IncomingControlModel.fromJson).toList(growable: false),
        page: page,
        lastPage:
            int.tryParse(result.meta['last_page']?.toString() ?? '') ?? page,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<IncomingControlReferences> fetchReferences(int projectId) async {
    try {
      final response = await _dio.get(
        '$endpoint/references',
        queryParameters: {'project_id': projectId},
      );
      return IncomingControlReferences(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<IncomingControlReferences> fetchReceivingReferences(
    int projectId,
  ) async {
    try {
      final response = await _dio.get(
        '$endpoint/readiness',
        queryParameters: {'project_id': projectId},
      );
      final readiness = MobileApiResponse.dataMap(response.data);
      if (readiness['required'] == true && readiness['ready'] != true) {
        final issues = (readiness['issues'] as List? ?? [])
            .whereType<String>()
            .join(' ');
        throw ApiException(
          issues.isEmpty
              ? 'Входной контроль обязателен, но объект ещё не готов к приёмке.'
              : issues,
        );
      }
      if (readiness['required'] == false) {
        return IncomingControlReferences({
          'policy': {'enabled': false},
          'permissions': const {},
          'readiness': readiness,
        });
      }
      if (readiness['required'] != true) {
        throw const FormatException(
          'Сервер не подтвердил правила приёмки объекта.',
        );
      }
      return fetchReferences(projectId);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> updatePolicy(
    int projectId, {
    required bool enabled,
    required bool mandatoryDocuments,
    required bool requireBatchNumber,
  }) async {
    try {
      await _dio.put(
        '$endpoint/policy',
        data: {
          'project_id': projectId,
          'enabled': enabled,
          'mandatory_documents': mandatoryDocuments,
          'require_batch_number': requireBatchNumber,
        },
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<IncomingControlModel> fetch(int id) async {
    try {
      final response = await _dio.get('$endpoint/$id');
      return IncomingControlModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<Map<String, dynamic>>> fetchHistory(int id) async {
    try {
      final response = await _dio.get('$endpoint/$id/history');
      return MobileApiResponse.dataList(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> fetchDependencies(int id) async {
    try {
      final response = await _dio.get('$endpoint/$id/dependencies');
      return MobileApiResponse.dataMap(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<IncomingControlModel> returnMaterials(
    IncomingControlModel record, {
    required double quantity,
    required String reason,
    required String idempotencyKey,
  }) => _save('$endpoint/${record.id}/return', 'return_incoming_control', {
    'project_id': record.projectId,
    'expected_version': record.version,
    'idempotency_key': idempotencyKey,
    'quantity': quantity,
    'reason': reason.trim(),
  });

  Future<IncomingControlModel> create(
    Map<String, dynamic> values, {
    required String idempotencyKey,
    List<IncomingControlUpload> files = const [],
  }) => _save(endpoint, 'create_incoming_control', {
    ...values,
    'idempotency_key': idempotencyKey,
  }, files: files);

  Future<Map<String, dynamic>> createExecutiveDocument(
    IncomingControlModel record, {
    required int documentSetId,
    required String idempotencyKey,
  }) async {
    final target = '$endpoint/${record.id}/executive-document';
    final payload = {
      'project_id': record.projectId,
      'document_set_id': documentSetId,
      'expected_version': record.version,
      'idempotency_key': idempotencyKey,
    };
    final scope = (await syncQueueServiceFuture)?.currentScope;
    final response = await executeOrQueue(
      request:
          () => _dio.post(
            target,
            data: payload,
            options: Options(headers: {'Idempotency-Key': idempotencyKey}),
          ),
      draft: SyncQueueDraft(
        moduleSlug: 'quality_control',
        operationType: 'executive_incoming_control',
        method: 'POST',
        endpoint: target,
        payload: {...payload, if (scope != null) 'queue_scope': scope},
      ),
      businessMessage:
          'Не удалось передать журнал в исполнительную документацию.',
    );
    return MobileApiResponse.dataMap(response.data);
  }

  Future<IncomingControlModel> decide(
    IncomingControlModel record,
    Map<String, dynamic> values, {
    required String idempotencyKey,
    List<IncomingControlUpload> files = const [],
  }) => _save('$endpoint/${record.id}/decision', 'decide_incoming_control', {
    ...values,
    'project_id': record.projectId,
    'expected_version': record.version,
    'idempotency_key': idempotencyKey,
  }, files: files);

  Future<IncomingControlModel> revoke(
    IncomingControlModel record, {
    required String reason,
    required String idempotencyKey,
  }) {
    return _save('$endpoint/${record.id}/revoke', 'revoke_incoming_control', {
      'project_id': record.projectId,
      'expected_version': record.version,
      'reason': reason.trim(),
      'idempotency_key': idempotencyKey,
    });
  }

  Future<IncomingControlModel> revise(
    IncomingControlModel record,
    Map<String, dynamic> values, {
    required String idempotencyKey,
    List<IncomingControlUpload> files = const [],
  }) => _save('$endpoint/${record.id}/revise', 'revise_incoming_control', {
    ...values,
    'project_id': record.projectId,
    'expected_version': record.version,
    'idempotency_key': idempotencyKey,
  }, files: files);

  Future<IncomingControlModel> _save(
    String path,
    String operation,
    Map<String, dynamic> payload, {
    List<IncomingControlUpload> files = const [],
  }) async {
    final key = payload['idempotency_key'].toString();
    final scope = (await syncQueueServiceFuture)?.currentScope;
    final wirePayload =
        files.isEmpty ? payload : flattenIncomingControlFields(payload);
    final attachments = <SyncAttachmentRef>[];
    for (var index = 0; index < files.length; index++) {
      final prefix = 'files[$index]';
      wirePayload.addAll(files[index].fields(prefix));
      attachments.add(files[index].attachment(prefix));
    }
    final response = await executeOrQueue(
      request:
          () async => _dio.post(
            path,
            data:
                files.isEmpty
                    ? wirePayload
                    : await incomingControlMultipart(wirePayload, attachments),
            options: Options(headers: {'Idempotency-Key': key}),
          ),
      draft: SyncQueueDraft(
        moduleSlug: 'quality_control',
        operationType: operation,
        method: 'POST',
        endpoint: path,
        payload: {...wirePayload, if (scope != null) 'queue_scope': scope},
        attachments: attachments,
      ),
      businessMessage: 'Не удалось сохранить входной контроль.',
    );
    return IncomingControlModel.fromJson(
      MobileApiResponse.dataMap(response.data),
    );
  }

  Future<void> attach(
    IncomingControlModel record,
    String path, {
    required String idempotencyKey,
    String kind = 'inspection_photo',
    Map<String, String> metadata = const {},
  }) async {
    final target = '$endpoint/${record.id}/attachments';
    final filename = path.replaceAll('\\', '/').split('/').last;
    final payload = <String, dynamic>{
      'project_id': record.projectId,
      'idempotency_key': idempotencyKey,
      'kind': kind,
      ...metadata,
    };
    final scope = (await syncQueueServiceFuture)?.currentScope;
    await executeOrQueue(
      request:
          () async => _dio.post(
            target,
            data: FormData.fromMap({
              ...payload,
              'file': await MultipartFile.fromFile(path, filename: filename),
            }),
            options: Options(headers: {'Idempotency-Key': idempotencyKey}),
          ),
      draft: SyncQueueDraft(
        moduleSlug: 'quality_control',
        operationType: 'attach_incoming_control',
        method: 'POST',
        endpoint: target,
        payload: {...payload, if (scope != null) 'queue_scope': scope},
        attachments: [
          SyncAttachmentRef(field: 'file', path: path, filename: filename),
        ],
      ),
      businessMessage: 'Не удалось сохранить фотографию контроля.',
    );
  }
}
