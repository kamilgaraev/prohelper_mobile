import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

final fieldCatalogRepositoryProvider = Provider<FieldCatalogRepository>((ref) {
  return FieldCatalogRepository(ref.read(dioProvider));
});

class FieldCatalogRepository {
  FieldCatalogRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> fetchPayload({
    required String path,
    required Map<String, Object?> queryParameters,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      return _map(_map(response.data)['data']);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> createCrmActivity({
    required String kind,
    required String targetType,
    required String targetId,
    required String subject,
    String? body,
    DateTime? dueAt,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/catalog/crm/activities',
        data: {
          'kind': kind,
          'target_type': targetType,
          'target_id': targetId,
          'subject': subject,
          if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
          if (dueAt != null) 'due_at': _date(dueAt),
        },
      );
      return _map(_map(response.data)['data']);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<FieldCatalogPage> fetchPage({
    required String catalog,
    String? apiPrefix,
    String? entity,
    String? query,
    String queryParameter = 'q',
    int? projectId,
    int page = 1,
    int perPage = 20,
    Map<String, Object?> extraQueryParameters = const {},
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _path(catalog, entity, apiPrefix),
        queryParameters: {
          ...extraQueryParameters,
          if (query != null && query.trim().isNotEmpty)
            queryParameter: query.trim(),
          if (projectId != null) 'project_id': projectId,
          'page': page,
          'per_page': perPage,
        },
      );
      final body = _map(response.data);
      final dataPayload = _map(body['data']);
      final rawData =
          body['data'] is List ? body['data'] : dataPayload['items'];
      final items =
          rawData is List
              ? rawData
                  .whereType<Map>()
                  .map(_map)
                  .map(FieldCatalogEntry.fromJson)
                  .toList(growable: false)
              : const <FieldCatalogEntry>[];
      final meta =
          _map(body['meta']).isNotEmpty
              ? _map(body['meta'])
              : _map(dataPayload['meta']);
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
    required String catalog,
    String? apiPrefix,
    String? entity,
    required String uuid,
    int? projectId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${_path(catalog, entity, apiPrefix)}/${Uri.encodeComponent(uuid)}',
        queryParameters: {if (projectId != null) 'project_id': projectId},
      );
      final body = _map(response.data);
      return FieldCatalogEntry.fromJson(_map(body['data'])['item']);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  String _path(String catalog, String? entity, String? apiPrefix) {
    if (apiPrefix != null) {
      final prefix =
          apiPrefix.endsWith('/')
              ? apiPrefix.substring(0, apiPrefix.length - 1)
              : apiPrefix;
      return entity == null ? prefix : '$prefix/${Uri.encodeComponent(entity)}';
    }
    final safeCatalog = Uri.encodeComponent(catalog);
    if (entity == null) return '/catalog/$safeCatalog';
    return '/catalog/$safeCatalog/${Uri.encodeComponent(entity)}';
  }
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

class FieldCatalogPage {
  const FieldCatalogPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<FieldCatalogEntry> items;
  final int currentPage;
  final int lastPage;
  final int total;
}

class FieldCatalogEntry {
  const FieldCatalogEntry({
    required this.uuid,
    required this.title,
    required this.fields,
  });

  final String uuid;
  final String title;
  final Map<String, dynamic> fields;

  factory FieldCatalogEntry.fromJson(dynamic value) {
    final json = _map(value);
    final uuid = _first(json, const ['uuid', 'id']);
    final title = _first(json, const [
      'name',
      'filename',
      'title',
      'full_name',
      'display_name',
      'employee_name',
      'employee_label',
      'person_name',
      'subject',
      'absence_type_label',
      'order_type',
      'order_number',
      'number',
      'personnel_number',
      'reason',
      'company_name',
      'contact_name',
      'deal_name',
      'lead_name',
    ]);
    return FieldCatalogEntry(
      uuid: uuid,
      title: title.isEmpty ? 'Запись' : title,
      fields: json,
    );
  }

  String? get subtitle {
    for (final key in const [
      'status_label',
      'status',
      'email',
      'phone',
      'company_name',
      'employee_label',
      'absence_type_label',
      'description',
      'short_description',
      'base_city',
    ]) {
      final value = fields[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

int _int(dynamic value, int fallback) =>
    value is num ? value.toInt() : fallback;

String _first(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  return '';
}
