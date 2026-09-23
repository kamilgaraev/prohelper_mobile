import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'field_catalog_repository.dart';

final projectFilesRepositoryProvider = Provider<ProjectFilesRepository>((ref) {
  return ProjectFilesRepository(ref.read(dioProvider));
});

class ProjectFilesRepository {
  ProjectFilesRepository(this._dio);

  final Dio _dio;

  Future<FieldCatalogPage> fetchPage({
    required int projectId,
    String? query,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/files',
        queryParameters: {
          'project_id': projectId,
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          'page': page,
          'per_page': perPage,
        },
      );
      final body = _map(response.data);
      final rows = body['data'] is List ? body['data'] as List : const [];
      final meta = _map(body['meta']);
      final items = rows
          .whereType<Map>()
          .map(FieldCatalogEntry.fromJson)
          .toList(growable: false);
      return FieldCatalogPage(
        items: items,
        currentPage: _int(meta['current_page'], page),
        lastPage: _int(meta['last_page'], page),
        total: _int(meta['total'], items.length),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<FieldCatalogEntry> fetchDetail({
    required int projectId,
    required String fileId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/files/${Uri.encodeComponent(fileId)}',
        queryParameters: {'project_id': projectId},
      );
      return FieldCatalogEntry.fromJson(
        _map(_map(response.data)['data'])['item'],
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<FieldCatalogEntry> uploadProjectFile({
    required int projectId,
    required String recordType,
    required int recordId,
    required String path,
    required String fileType,
    String? description,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/files',
        data: FormData.fromMap({
          'project_id': projectId,
          'record_type': recordType,
          'record_id': recordId,
          'file_type': fileType,
          'file': await MultipartFile.fromFile(path),
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        }),
      );
      return FieldCatalogEntry.fromJson(
        _map(_map(response.data)['data'])['item'],
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

int _int(dynamic value, int fallback) =>
    value is num ? value.toInt() : fallback;
