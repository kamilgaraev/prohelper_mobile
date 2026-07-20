import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import 'legal_document_model.dart';

final legalDocumentRepositoryProvider = Provider<LegalDocumentRepository>((ref) {
  return LegalDocumentRepository(ref.read(dioProvider));
});

class LegalDocumentRepository {
  LegalDocumentRepository(this._dio);

  final Dio _dio;

  Future<List<LegalDocumentModel>> fetchDocuments({required int projectId}) async {
    try {
      final response = await _dio.get(
        '/legal-archive/documents',
        queryParameters: {'project_id': projectId, 'per_page': 50},
      );
      final data = MobileApiResponse.dataMap(response.data);
      final records = data['data'] is List ? data['data'] as List : data['documents'] as List? ?? const [];
      return records
          .whereType<Map>()
          .map((item) => LegalDocumentModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<LegalDocumentModel> fetchDocument(int id) async {
    try {
      final response = await _dio.get('/legal-archive/documents/$id');
      return LegalDocumentModel.fromJson(MobileApiResponse.dataMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<LegalDocumentModel> performAction({
    required int documentId,
    required String action,
    String? comment,
    String? reason,
  }) async {
    try {
      final response = await _dio.post(
        '/legal-archive/documents/$documentId/actions/$action',
        data: {
          if (comment?.trim().isNotEmpty == true) 'comment': comment!.trim(),
          if (reason?.trim().isNotEmpty == true) 'reason': reason!.trim(),
        },
      );
      return LegalDocumentModel.fromJson(MobileApiResponse.dataMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
