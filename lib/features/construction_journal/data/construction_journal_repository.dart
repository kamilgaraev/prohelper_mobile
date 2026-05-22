import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import '../../../core/sync/sync_queue_draft.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../../core/sync/sync_queue_repository.dart';
import '../../../core/sync/sync_queue_service.dart';
import 'construction_journal_models.dart';

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
    required String name,
    required String journalNumber,
    required String startDate,
  }) async {
    try {
      final response = await _dio.post(
        '/construction-journals',
        data: {
          'project_id': projectId,
          'name': name,
          'journal_number': journalNumber,
          'start_date': startDate,
          'status': 'active',
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
    required String name,
    required String journalNumber,
    required String startDate,
  }) async {
    try {
      final response = await _dio.put(
        '/construction-journals/$journalId',
        data: {
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
        fallbackMessage: 'Не удалось обновить журнал.',
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
    List<ConstructionJournalWorkVolumeModel> workVolumes = const [],
    List<ConstructionJournalMaterialUsageModel> materials = const [],
  }) async {
    final payload = <String, dynamic>{
      if (scheduleTaskId != null) 'schedule_task_id': scheduleTaskId,
      if (estimateId != null) 'estimate_id': estimateId,
      'entry_date': entryDate,
      'work_description': workDescription,
      'status': 'draft',
      'problems_description': problemsDescription,
      'safety_notes': safetyNotes,
      'visitors_notes': visitorsNotes,
      'quality_notes': qualityNotes,
      'work_volumes': workVolumes.map((volume) => volume.toJson()).toList(),
      'materials': materials.map((material) => material.toJson()).toList(),
    };

    try {
      final response = await _dio.post(
        '/construction-journals/$journalId/entries',
        data: payload,
      );

      return ConstructionJournalEntryModel.fromJson(
        _extractMap(MobileApiResponse.payload(response.data)),
      );
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        await queueAndThrow(
          SyncQueueDraft(
            moduleSlug: 'construction_journal',
            operationType: 'create_entry',
            method: 'POST',
            endpoint: '/construction-journals/$journalId/entries',
            payload: payload,
          ),
        );
      }

      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось создать запись.',
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
    List<ConstructionJournalWorkVolumeModel> workVolumes = const [],
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
          'work_volumes': workVolumes.map((volume) => volume.toJson()).toList(),
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

  Future<ConstructionJournalEntryModel> submitEntry(int entryId) async {
    return _entryAction('/journal-entries/$entryId/submit', const {});
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
      final response = await _dio.post(
        '/construction-journals/$journalId/export/ks6',
        data: {'format': 'pdf', 'date_from': dateFrom, 'date_to': dateTo},
      );

      final data = _extractMap(MobileApiResponse.payload(response.data));
      return _requiredString(data, 'url');
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось сформировать экспорт журнала.',
      );
    }
  }

  Future<String> exportDailyReport(int entryId) async {
    try {
      final response = await _dio.post(
        '/journal-entries/$entryId/export/daily-report',
      );
      final data = _extractMap(MobileApiResponse.payload(response.data));
      return _requiredString(data, 'url');
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось сформировать дневной отчет.',
      );
    }
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

  void _rethrowKnown(Object error) {
    if (error is ApiException || error is FormatException) {
      throw error;
    }
  }
}
