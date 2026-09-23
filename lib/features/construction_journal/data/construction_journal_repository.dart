import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import '../../../core/sync/sync_queue_draft.dart';
import '../../../core/sync/queued_sync_operation.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../../core/sync/sync_queue_repository.dart';
import '../../../core/sync/sync_queue_service.dart';
import 'construction_journal_models.dart';
import 'journal_entry_operation_recovery.dart';

final constructionJournalRepositoryProvider =
    Provider<ConstructionJournalRepository>((ref) {
      return ConstructionJournalRepository(
        ref.read(dioProvider),
        syncQueueServiceFuture: ref.read(syncQueueServiceProvider.future),
      );
    });

class ConstructionJournalRepository extends SyncQueueAwareRepository {
  ConstructionJournalRepository(
    this._dio, {
    Future<SyncQueueService>? syncQueueServiceFuture,
  }) : super(syncQueueServiceFuture);

  final Dio _dio;

  Future<ConstructionJournalListPayload> fetchJournals({
    required int projectId,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/construction-journals',
        queryParameters: {
          'project_id': projectId,
          'page': page,
          'per_page': perPage,
        },
      );

      final data = _extractMap(MobileApiResponse.payload(response.data));

      return ConstructionJournalListPayload(
        items:
            _extractList(
              data['items'],
            ).map(ConstructionJournalModel.fromJson).toList(),
        meta: JournalPaginationMeta.fromJson(_extractMap(data['meta'])),
        summary: ConstructionJournalSummary.fromJournalListJson(
          _extractMap(data['summary']),
        ),
        availableActions:
            _extractList(
              data['available_actions'],
            ).map(ConstructionJournalActionModel.fromJson).toList(),
        project: ConstructionJournalProjectRef.fromJson(
          _extractMap(data['project']),
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить журналы работ.',
      );
    } catch (error) {
      _rethrowKnown(error);
      throw const ApiException('Не удалось загрузить журналы работ.');
    }
  }

  Future<ConstructionJournalDetailPayload> fetchJournalDetail(
    int journalId,
  ) async {
    try {
      final journalResponse = await _dio.get(
        '/construction-journals/$journalId',
      );
      final entriesResponse = await _dio.get(
        '/construction-journals/$journalId/entries',
      );
      final journalData = _extractMap(
        MobileApiResponse.payload(journalResponse.data),
      );
      final entriesData = _extractMap(
        MobileApiResponse.payload(entriesResponse.data),
      );

      return ConstructionJournalDetailPayload(
        journal: ConstructionJournalModel.fromJson(journalData),
        entries:
            _extractList(
              entriesData['items'],
            ).map(ConstructionJournalEntryModel.fromJson).toList(),
        entriesMeta: JournalPaginationMeta.fromJson(
          _extractMap(entriesData['meta']),
        ),
        entriesSummary: ConstructionJournalSummary.fromEntriesJson(
          _extractMap(entriesData['summary']),
        ),
        availableActions:
            _extractList(
              entriesData['available_actions'],
            ).map(ConstructionJournalActionModel.fromJson).toList(),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить детали журнала.',
      );
    } catch (error) {
      _rethrowKnown(error);
      throw const ApiException('Не удалось загрузить детали журнала.');
    }
  }

  Future<ConstructionJournalEntryModel> fetchEntryDetail(int entryId) async {
    try {
      final response = await _dio.get('/journal-entries/$entryId');
      return ConstructionJournalEntryModel.fromJson(
        _extractMap(MobileApiResponse.payload(response.data)),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить запись журнала.',
      );
    } catch (error) {
      _rethrowKnown(error);
      throw const ApiException('Не удалось загрузить запись журнала.');
    }
  }

  Future<ConstructionJournalEntryFormOptions> fetchEntryFormOptions(
    int journalId,
  ) async {
    try {
      final response = await _dio.get(
        '/construction-journals/$journalId/entry-form-options',
      );

      return ConstructionJournalEntryFormOptions.fromJson(
        _extractMap(MobileApiResponse.payload(response.data)),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить данные для формы записи.',
      );
    } catch (error) {
      _rethrowKnown(error);
      throw const ApiException('Не удалось загрузить данные для формы записи.');
    }
  }

  Future<ConstructionJournalModel> createJournal({
    required int projectId,
    required int contractId,
    required String name,
    required String journalNumber,
    required String startDate,
  }) async {
    try {
      final response = await _dio.post(
        '/construction-journals',
        data: {
          'project_id': projectId,
          'contract_id': contractId,
          'name': name,
          'journal_number': journalNumber,
          'start_date': startDate,
        },
      );

      return ConstructionJournalModel.fromJson(
        _extractMap(MobileApiResponse.payload(response.data)),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось создать журнал.',
      );
    }
  }

  Future<ConstructionJournalModel> updateJournal({
    required int journalId,
    required int contractId,
    required String name,
    required String journalNumber,
    required String startDate,
  }) async {
    try {
      final response = await _dio.put(
        '/construction-journals/$journalId',
        data: {
          'name': name,
          'contract_id': contractId,
          'journal_number': journalNumber,
          'start_date': startDate,
        },
      );

      return ConstructionJournalModel.fromJson(
        _extractMap(MobileApiResponse.payload(response.data)),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось обновить журнал.',
      );
    }
  }

  Future<List<ConstructionJournalContractOption>> fetchJournalFormOptions({
    required int projectId,
  }) async {
    try {
      final response = await _dio.get(
        '/construction-journals/form-options',
        queryParameters: {'project_id': projectId},
      );
      final payload = _extractMap(MobileApiResponse.payload(response.data));

      return _extractList(
        payload['contracts'],
      ).map(ConstructionJournalContractOption.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить договоры проекта.',
      );
    }
  }

  Future<ConstructionJournalEntryModel> createEntry({
    required int journalId,
    required String entryDate,
    required String workDescription,
    int? scheduleTaskId,
    int? estimateId,
    String? problemsDescription,
    String? safetyNotes,
    String? visitorsNotes,
    String? qualityNotes,
    ConstructionJournalWeatherModel? weatherConditions,
    List<ConstructionJournalWorkVolumeModel> workVolumes = const [],
    List<ConstructionJournalWorkerModel> workers = const [],
    List<ConstructionJournalEquipmentModel> equipment = const [],
    List<ConstructionJournalMaterialUsageModel> materials = const [],
    bool submitAfterCreate = false,
    bool? submitIntent,
    String? idempotencyKey,
  }) async {
    idempotencyKey ??= _newIdempotencyKey();
    final shouldSubmit = submitIntent ?? submitAfterCreate;
    final payload = <String, dynamic>{
      'idempotency_key': idempotencyKey,
      'journal_id': journalId,
      'submit_after_create': submitAfterCreate,
      'submit_intent': shouldSubmit,
      if (scheduleTaskId != null) 'schedule_task_id': scheduleTaskId,
      if (estimateId != null) 'estimate_id': estimateId,
      'entry_date': entryDate,
      'work_description': workDescription,
      'problems_description': problemsDescription,
      'safety_notes': safetyNotes,
      'visitors_notes': visitorsNotes,
      'quality_notes': qualityNotes,
      'weather_conditions': weatherConditions?.toJson(),
      'work_volumes': workVolumes.map((volume) => volume.toJson()).toList(),
      'workers': workers.map((worker) => worker.toJson()).toList(),
      'equipment': equipment.map((item) => item.toJson()).toList(),
      'materials': materials.map((material) => material.toJson()).toList(),
    };

    final draft = SyncQueueDraft(
      moduleSlug: 'construction_journal',
      operationType:
          submitAfterCreate ? 'create_and_submit_entry' : 'create_entry',
      method: 'POST',
      endpoint: '/construction-journals/$journalId/entries',
      payload: payload,
    );
    final preparedOperation = await _prepareOperation(draft);
    try {
      final knownId = int.tryParse(
        preparedOperation?.payload['created_entry_id']?.toString() ?? '',
      );
      if (knownId != null) {
        return await fetchEntryDetail(knownId);
      }
      final response = await _dio.post(
        '/construction-journals/$journalId/entries',
        data: _wirePayload(preparedOperation?.payload ?? payload),
      );

      final result = ConstructionJournalEntryModel.fromJson(
        _extractMap(MobileApiResponse.payload(response.data)),
      );
      if (preparedOperation != null &&
          preparedOperation.payload['submit_intent'] == true) {
        await _persistCreatedStage(preparedOperation, result.id);
      } else {
        await _deletePreparedOperation(preparedOperation);
      }
      return result;
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        if (preparedOperation != null) {
          throw SyncQueuedException(queueId: preparedOperation.id);
        }
        await queueAndThrow(
          SyncQueueDraft(
            moduleSlug: 'construction_journal',
            operationType:
                submitAfterCreate ? 'create_and_submit_entry' : 'create_entry',
            method: 'POST',
            endpoint: '/construction-journals/$journalId/entries',
            payload: payload,
          ),
        );
      }

      await _deletePreparedOperation(preparedOperation);
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось создать запись.',
      );
    }
  }

  Future<ConstructionJournalEntryModel> retryPendingCreate(
    PendingJournalEntryOperation operation,
  ) async {
    final scope = operation.payload['queue_scope'];
    final queueService =
        syncQueueServiceFuture == null ? null : await syncQueueServiceFuture!;
    if (scope != null && scope != queueService?.currentScope) {
      throw const ApiException(
        'Сохранённая операция относится к другой сессии.',
        statusCode: 403,
      );
    }
    try {
      final response = await _dio.post(
        operation.operation.endpoint,
        data: _wirePayload(operation.payload),
      );
      final result = ConstructionJournalEntryModel.fromJson(
        _extractMap(MobileApiResponse.payload(response.data)),
      );
      final queue = syncQueueServiceFuture;
      if (queue != null && operation.payload['submit_intent'] == true) {
        await (await queue).replaceDraftPayload(
          operation.operation.id,
          payload: {
            ...operation.payload,
            'stage': 'created',
            'created_entry_id': result.id,
          },
          attachments: operation.operation.attachments,
        );
      } else {
        await clearPendingEntryOperation(operation);
      }
      return result;
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось повторить создание записи.',
      );
    }
  }

  Future<ConstructionJournalEntryModel> updateEntry({
    required int entryId,
    required String entryDate,
    required String workDescription,
    int? scheduleTaskId,
    int? estimateId,
    String? problemsDescription,
    String? safetyNotes,
    String? visitorsNotes,
    String? qualityNotes,
    ConstructionJournalWeatherModel? weatherConditions,
    List<ConstructionJournalWorkVolumeModel> workVolumes = const [],
    List<ConstructionJournalWorkerModel> workers = const [],
    List<ConstructionJournalEquipmentModel> equipment = const [],
    List<ConstructionJournalMaterialUsageModel> materials = const [],
  }) async {
    try {
      final response = await _dio.put(
        '/journal-entries/$entryId',
        data: {
          'schedule_task_id': scheduleTaskId,
          'estimate_id': estimateId,
          'entry_date': entryDate,
          'work_description': workDescription,
          'problems_description': problemsDescription,
          'safety_notes': safetyNotes,
          'visitors_notes': visitorsNotes,
          'quality_notes': qualityNotes,
          'weather_conditions': weatherConditions?.toJson(),
          'work_volumes': workVolumes.map((volume) => volume.toJson()).toList(),
          'workers': workers.map((worker) => worker.toJson()).toList(),
          'equipment': equipment.map((item) => item.toJson()).toList(),
          'materials': materials.map((material) => material.toJson()).toList(),
        },
      );

      return ConstructionJournalEntryModel.fromJson(
        _extractMap(MobileApiResponse.payload(response.data)),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось обновить запись.',
      );
    }
  }

  Future<void> deleteEntry(int entryId) async {
    try {
      await _dio.delete('/journal-entries/$entryId');
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось удалить запись.',
      );
    }
  }

  Future<ConstructionJournalModel> transitionJournal(
    int journalId,
    String action,
  ) async {
    try {
      final response = await _dio.post(
        '/construction-journals/$journalId/$action',
      );
      return ConstructionJournalModel.fromJson(
        _extractMap(MobileApiResponse.payload(response.data)),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось изменить состояние журнала.',
      );
    }
  }

  Future<ConstructionJournalEntryModel> submitEntry(
    int entryId, {
    String? idempotencyKey,
    int? journalId,
  }) async {
    final operationKey = idempotencyKey ?? _newIdempotencyKey();
    final draft = SyncQueueDraft(
      moduleSlug: 'construction_journal',
      operationType: 'submit_entry',
      method: 'POST',
      endpoint: '/journal-entries/$entryId/submit',
      payload: {
        'idempotency_key': operationKey,
        'entry_id': entryId,
        if (journalId != null) 'journal_id': journalId,
      },
    );
    final preparedOperation = await _prepareSubmitOperation(draft, entryId);
    try {
      final response = await _dio.post(
        '/journal-entries/$entryId/submit',
        data: {'idempotency_key': operationKey},
      );
      final result = ConstructionJournalEntryModel.fromJson(
        _extractMap(MobileApiResponse.payload(response.data)),
      );
      await _deletePreparedOperation(preparedOperation);
      return result;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 403 || statusCode == 422) {
        try {
          final current = await fetchEntryDetail(entryId);
          if (current.status == 'submitted' || current.status == 'approved') {
            await _deletePreparedOperation(preparedOperation);
            return current;
          }
        } catch (_) {}
      }

      if (SyncQueueService.shouldQueueDioException(error)) {
        if (preparedOperation != null) {
          throw SyncQueuedException(queueId: preparedOperation.id);
        }
        await queueAndThrow(
          SyncQueueDraft(
            moduleSlug: 'construction_journal',
            operationType: 'submit_entry',
            method: 'POST',
            endpoint: '/journal-entries/$entryId/submit',
            payload: {'idempotency_key': operationKey},
          ),
        );
      }

      if (preparedOperation?.payload['created_entry_id'] == null) {
        await _deletePreparedOperation(preparedOperation);
      } else {
        preparedOperation!
          ..status =
              statusCode == 403
                  ? SyncOperationStatuses.permissionDenied
                  : SyncOperationStatuses.needsEdit
          ..lastBusinessError = ApiException.fromDio(error).message
          ..nextAttemptAt = null;
        await (await syncQueueServiceFuture!).update(preparedOperation);
      }

      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось отправить запись на согласование.',
      );
    }
  }

  Future<PendingJournalEntryOperation?> findPendingEntryOperation(
    int journalId,
  ) async {
    final queue = syncQueueServiceFuture;
    if (queue == null) {
      return null;
    }

    final candidates =
        await JournalEntryOperationRecovery(await queue).findCandidates();
    final currentScope = (await queue).currentScope;
    for (final candidate in candidates) {
      final operationScope = candidate.payload['queue_scope']?.toString();
      if (((await queue).requiresScope && operationScope == null) ||
          (operationScope != null &&
              (currentScope == null || operationScope != currentScope))) {
        continue;
      }
      if (candidate.journalId == journalId && candidate.entryId == null) {
        return candidate;
      }
      final entryId = candidate.entryId;
      if (entryId == null) {
        continue;
      }
      if (candidate.journalId == journalId) {
        return candidate;
      }
      try {
        final entry = await fetchEntryDetail(entryId);
        if (entry.journalId == journalId) {
          return candidate;
        }
      } catch (_) {
        if (candidate.journalId == journalId) {
          return candidate;
        }
      }
    }
    return null;
  }

  Future<void> clearPendingEntryOperation(
    PendingJournalEntryOperation operation,
  ) async {
    final queue = syncQueueServiceFuture;
    if (queue != null) {
      await (await queue).delete(operation.operation.id);
    }
  }

  Future<QueuedSyncOperation?> _prepareOperation(SyncQueueDraft draft) async {
    final future = syncQueueServiceFuture;
    if (future == null) {
      return null;
    }
    final service = await future;
    final scope = service.currentScope;
    if (service.requiresScope && scope == null) {
      throw const ApiException(
        'Войдите в аккаунт перед сохранением записи.',
        statusCode: 401,
      );
    }
    if (scope != null) {
      draft.payload['queue_scope'] = scope;
    }
    final key = draft.payload['idempotency_key'];
    for (final existing in await service.all()) {
      final stored = existing.payload;
      if (existing.moduleSlug == draft.moduleSlug &&
          stored['queue_scope'] == scope &&
          (existing.endpoint == draft.endpoint ||
              (stored['journal_id'] == draft.payload['journal_id'] &&
                  stored['create_idempotency_key'] == key)) &&
          (stored['idempotency_key'] == key ||
              stored['create_idempotency_key'] == key)) {
        return existing;
      }
    }
    return service.enqueue(draft);
  }

  Future<QueuedSyncOperation?> _prepareSubmitOperation(
    SyncQueueDraft draft,
    int entryId,
  ) async {
    final future = syncQueueServiceFuture;
    if (future == null) {
      return null;
    }
    final service = await future;
    for (final operation in await service.all()) {
      if (operation.moduleSlug != 'construction_journal' ||
          operation.payload['created_entry_id']?.toString() !=
              entryId.toString()) {
        continue;
      }
      final operationScope = operation.payload['queue_scope']?.toString();
      if (operationScope != null &&
          (service.currentScope == null ||
              operationScope != service.currentScope)) {
        continue;
      }
      operation
        ..endpoint = draft.endpoint
        ..method = draft.method
        ..operationType = draft.operationType
        ..status = SyncOperationStatuses.queued
        ..nextAttemptAt = null
        ..lastBusinessError = null
        ..payloadJson = jsonEncode({
          ...operation.payload,
          ...draft.payload,
          'create_idempotency_key':
              operation.payload['create_idempotency_key'] ??
              operation.payload['idempotency_key'],
          'stage': 'submit',
        });
      await service.update(operation);
      return operation;
    }
    return _prepareOperation(draft);
  }

  Future<void> _deletePreparedOperation(QueuedSyncOperation? operation) async {
    if (operation == null || syncQueueServiceFuture == null) {
      return;
    }
    await (await syncQueueServiceFuture!).delete(operation.id);
  }

  Future<void> _persistCreatedStage(
    QueuedSyncOperation operation,
    int entryId,
  ) async {
    final queue = syncQueueServiceFuture;
    if (queue == null) {
      return;
    }
    await (await queue).replaceDraftPayload(
      operation.id,
      payload: {
        ...operation.payload,
        'stage': 'created',
        'created_entry_id': entryId,
      },
      attachments: operation.attachments,
    );
  }

  Future<ConstructionJournalEntryModel> approveEntry(int entryId) async {
    return _entryAction('/journal-entries/$entryId/approve', const {});
  }

  Future<ConstructionJournalEntryModel> rejectEntry(
    int entryId,
    String reason,
  ) async {
    return _entryAction('/journal-entries/$entryId/reject', {'reason': reason});
  }

  Future<String> exportJournal({
    required int journalId,
    required String dateFrom,
    required String dateTo,
  }) async {
    try {
      return await _requestExport(
        '/construction-journals/$journalId/export/ks6',
        {'format': 'pdf', 'date_from': dateFrom, 'date_to': dateTo},
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось сформировать экспорт журнала.',
      );
    }
  }

  Future<String> exportDailyReport(int entryId) async {
    try {
      return await _requestExport(
        '/journal-entries/$entryId/export/daily-report',
        const {},
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось сформировать дневной отчет.',
      );
    }
  }

  Future<String> _requestExport(
    String endpoint,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      endpoint,
      data: payload,
      options: Options(headers: {'Idempotency-Key': _newIdempotencyKey()}),
    );
    var state = _extractMap(MobileApiResponse.payload(response.data));
    final exportId = _requiredString(state, 'id');

    for (
      var attempt = 0;
      attempt < 150 &&
          state['status'] != 'completed' &&
          state['status'] != 'failed';
      attempt++
    ) {
      final statusResponse = await _dio.get(
        '/construction-journal-exports/$exportId',
      );
      state = _extractMap(MobileApiResponse.payload(statusResponse.data));
      if (state['status'] != 'completed' && state['status'] != 'failed') {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }

    if (state['status'] == 'completed') {
      return _requiredString(state, 'url');
    }
    if (state['status'] == 'failed') {
      throw ApiException(
        state['error_code'] == 'export_too_large'
            ? 'Для выбранного периода слишком много записей. Сократите период выгрузки.'
            : 'Не удалось подготовить файл.',
      );
    }
    throw const ApiException(
      'Подготовка файла заняла слишком много времени. Повторите проверку позже.',
    );
  }

  Future<ConstructionJournalEntryModel> _entryAction(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post(path, data: body);
      return ConstructionJournalEntryModel.fromJson(
        _extractMap(MobileApiResponse.payload(response.data)),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось выполнить действие по записи.',
      );
    }
  }

  Map<String, dynamic> _extractMap(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return payload;
    }

    if (payload is Map) {
      return payload.map((key, value) => MapEntry(key.toString(), value));
    }

    throw const FormatException(
      'Construction journal response must be an object.',
    );
  }

  List<Map<String, dynamic>> _extractList(dynamic payload) {
    if (payload is! List) {
      throw const FormatException(
        'Construction journal response must be a list.',
      );
    }

    return payload.map((item) {
      if (item is Map<String, dynamic>) {
        return item;
      }

      if (item is Map) {
        return item.map((key, value) => MapEntry(key.toString(), value));
      }

      throw const FormatException(
        'Construction journal response list must contain objects.',
      );
    }).toList();
  }

  String _requiredString(Map<String, dynamic> payload, String key) {
    final value = payload[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw FormatException(
        'Construction journal response field "$key" is required.',
      );
    }

    return value;
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    final entropy =
        List<int>.generate(
          4,
          (_) => random.nextInt(1 << 32),
        ).map((value) => value.toRadixString(16).padLeft(8, '0')).join();

    return 'journal-${DateTime.now().microsecondsSinceEpoch}-$entropy';
  }

  Map<String, dynamic> _wirePayload(Map<String, dynamic> payload) {
    final wire = Map<String, dynamic>.from(payload);
    for (final key in const [
      'queue_scope',
      'stage',
      'created_entry_id',
      'submit_intent',
      'journal_id',
      'entry_id',
      'create_idempotency_key',
      'confirm',
      'confirmed',
      'act',
      'acting',
      'force',
      'override',
      'skip_readiness',
      'skip_confirmation',
      'available_to_act',
    ]) {
      wire.remove(key);
    }
    return wire;
  }

  void _rethrowKnown(Object error) {
    if (error is ApiException || error is FormatException) {
      throw error;
    }
  }
}
