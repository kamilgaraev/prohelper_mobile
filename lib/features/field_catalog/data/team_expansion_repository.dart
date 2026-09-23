import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'field_catalog_repository.dart';

final teamExpansionRepositoryProvider = Provider<TeamExpansionRepository>(
  (ref) => TeamExpansionRepository(ref.read(dioProvider)),
);

class TeamExpansionRepository {
  TeamExpansionRepository(this._dio);

  final Dio _dio;

  Future<FieldCatalogPage> fetchPage({
    required String path,
    Map<String, Object?> filters = const {},
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: {...filters, 'page': page, 'per_page': perPage}
          ..removeWhere((_, value) => value == null),
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
    required String path,
    required String id,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$path/${Uri.encodeComponent(id)}',
      );
      return FieldCatalogEntry.fromJson(
        _map(_map(response.data)['data'])['item'],
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> create({
    required String path,
    required Map<String, Object?> payload,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: payload,
      );
      return _map(_map(response.data)['data']);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> action({
    required String path,
    required Map<String, Object?> payload,
  }) async => create(path: path, payload: payload);
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
