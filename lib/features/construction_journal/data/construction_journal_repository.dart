import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'construction_journal_models.dart';

final constructionJournalRepositoryProvider = Provider<ConstructionJournalRepository>((ref) {
  return ConstructionJournalRepository(ref.read(dioProvider));
});

class ConstructionJournalRepository {
  ConstructionJournalRepository(this._dio);

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

      final data = _extractMap(response.data['data']);
      final items = _extractList(data['items']).map(ConstructionJournalModel.fromJson).toList();
      final projectData = data['project'];

      return ConstructionJournalListPayload(
        items: items,
        meta: JournalPaginationMeta.fromJson(_extractMap(data['meta'])),
        summary: ConstructionJournalSummary.fromJson(_extractMap(data['summary'])),
        availableActions: _extractStringList(data['available_actions']),
        project: projectData is Map<String, dynamic>
            ? ConstructionJournalProjectRef.fromJson(projectData)
            : projectData is Map
                ? ConstructionJournalProjectRef.fromJson(
                    projectData.map((key, value) => MapEntry(key.toString(), value)),
                  )
                : null,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить журналы работ.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось загрузить журналы работ.');
    }
  }

  Future<ConstructionJournalDetailPayload> fetchJournalDetail(int journalId) async {
    try {
      final journalResponse = await _dio.get('/construction-journals/$journalId');
      final entriesResponse = await _dio.get('/construction-journals/$journalId/entries');
      final journalData = _extractMap(journalResponse.data['data']);
      final entriesData = _extractMap(entriesResponse.data['data']);

      final availableActions = _extractStringList(entriesData['available_actions']);

      return ConstructionJournalDetailPayload(
        journal: ConstructionJournalModel.fromJson(journalData),
        entries: _extractList(entriesData['items'])
            .map(ConstructionJournalEntryModel.fromJson)
            .toList(),
        entriesMeta: JournalPaginationMeta.fromJson(_extractMap(entriesData['meta'])),
        entriesSummary: ConstructionJournalSummary.fromJson(_extractMap(entriesData['summary'])),
        availableActions: availableActions.isNotEmpty
            ? availableActions
            : _extractStringList(journalData['available_actions']),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить детали журнала.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось загрузить детали журнала.');
    }
  }

  Future<ConstructionJournalEntryModel> fetchEntryDetail(int entryId) async {
    try {
      final response = await _dio.get('/journal-entries/$entryId');
      return ConstructionJournalEntryModel.fromJson(_extractMap(response.data['data']));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить запись журнала.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось загрузить запись журнала.');
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
        },
      );

      return ConstructionJournalModel.fromJson(_extractMap(response.data['data']));
    } on DioException catch (error) {
      throw ApiException.fromDio(error, fallbackMessage: 'Не удалось создать журнал.');
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

      return ConstructionJournalModel.fromJson(_extractMap(response.data['data']));
    } on DioException catch (error) {
      throw ApiException.fromDio(error, fallbackMessage: 'Не удалось обновить журнал.');
    }
  }

  Future<ConstructionJournalEntryModel> createEntry({
    required int journalId,
    required String entryDate,
    required String workDescription,
    String? problemsDescription,
    String? safetyNotes,
    String? visitorsNotes,
    String? qualityNotes,
  }) async {
    try {
      final response = await _dio.post(
        '/construction-journals/$journalId/entries',
        data: {
          'entry_date': entryDate,
          'work_description': workDescription,
          'problems_description': problemsDescription,
          'safety_notes': safetyNotes,
          'visitors_notes': visitorsNotes,
          'quality_notes': qualityNotes,
        },
      );

      return ConstructionJournalEntryModel.fromJson(_extractMap(response.data['data']));
    } on DioException catch (error) {
      throw ApiException.fromDio(error, fallbackMessage: 'Не удалось создать запись.');
    }
  }

  Future<ConstructionJournalEntryModel> updateEntry({
    required int entryId,
    required String entryDate,
    required String workDescription,
    String? problemsDescription,
    String? safetyNotes,
    String? visitorsNotes,
    String? qualityNotes,
  }) async {
    try {
      final response = await _dio.put(
        '/journal-entries/$entryId',
        data: {
          'entry_date': entryDate,
          'work_description': workDescription,
          'problems_description': problemsDescription,
          'safety_notes': safetyNotes,
          'visitors_notes': visitorsNotes,
          'quality_notes': qualityNotes,
        },
      );

      return ConstructionJournalEntryModel.fromJson(_extractMap(response.data['data']));
    } on DioException catch (error) {
      throw ApiException.fromDio(error, fallbackMessage: 'Не удалось обновить запись.');
    }
  }

  Future<void> deleteEntry(int entryId) async {
    try {
      await _dio.delete('/journal-entries/$entryId');
    } on DioException catch (error) {
      throw ApiException.fromDio(error, fallbackMessage: 'Не удалось удалить запись.');
    }
  }

  Future<ConstructionJournalEntryModel> submitEntry(int entryId) async {
    return _entryAction('/journal-entries/$entryId/submit', const {});
  }

  Future<ConstructionJournalEntryModel> approveEntry(int entryId) async {
    return _entryAction('/journal-entries/$entryId/approve', const {});
  }

  Future<ConstructionJournalEntryModel> rejectEntry(int entryId, String reason) async {
    return _entryAction('/journal-entries/$entryId/reject', {'reason': reason});
  }

  Future<String> exportJournal(int journalId) async {
    try {
      final response = await _dio.post(
        '/construction-journals/$journalId/export/ks6',
        data: {
          'format': 'pdf',
          'date_from': DateTime.now()
              .subtract(const Duration(days: 30))
              .toIso8601String()
              .split('T')
              .first,
          'date_to': DateTime.now().toIso8601String().split('T').first,
        },
      );

      final data = _extractMap(response.data['data']);
      return data['url'] as String? ?? '';
    } on DioException catch (error) {
      throw ApiException.fromDio(error, fallbackMessage: 'Не удалось сформировать экспорт журнала.');
    }
  }

  Future<String> exportDailyReport(int entryId) async {
    try {
      final response = await _dio.post('/journal-entries/$entryId/export/daily-report');
      final data = _extractMap(response.data['data']);
      return data['url'] as String? ?? '';
    } on DioException catch (error) {
      throw ApiException.fromDio(error, fallbackMessage: 'Не удалось сформировать дневной отчет.');
    }
  }

  Future<ConstructionJournalEntryModel> _entryAction(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post(path, data: body);
      return ConstructionJournalEntryModel.fromJson(_extractMap(response.data['data']));
    } on DioException catch (error) {
      throw ApiException.fromDio(error, fallbackMessage: 'Не удалось выполнить действие по записи.');
    }
  }

  Map<String, dynamic> _extractMap(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return payload;
    }

    if (payload is Map) {
      return payload.map((key, value) => MapEntry(key.toString(), value));
    }

    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _extractList(dynamic payload) {
    if (payload is! List) {
      return const [];
    }

    return payload
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
  }

  List<String> _extractStringList(dynamic payload) {
    if (payload is! List) {
      return const [];
    }

    return payload.whereType<String>().toList();
  }
}
