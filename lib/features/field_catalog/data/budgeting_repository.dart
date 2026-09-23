import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

final mobileBudgetingRepositoryProvider = Provider<MobileBudgetingRepository>(
  (ref) => MobileBudgetingRepository(ref.read(dioProvider)),
);

class MobileBudgetingRepository {
  MobileBudgetingRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> fetchSummary({required int projectId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/budgeting/projects/${Uri.encodeComponent(projectId.toString())}/summary',
      );
      return _map(_map(response.data)['data']);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<BudgetExecutionPage> fetchExecutionCards({
    required int projectId,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/budgeting/projects/${Uri.encodeComponent(projectId.toString())}/execution-cards',
        queryParameters: {'page': page, 'per_page': perPage},
      );
      final body = _map(response.data);
      final rows = body['data'] is List ? body['data'] as List : const [];
      final meta = _map(body['meta']);
      final items = rows.map(_map).toList(growable: false);
      return BudgetExecutionPage(
        items: items,
        currentPage: _int(meta['current_page'] ?? meta['page'], page),
        lastPage: _int(meta['last_page'], page),
        total: _int(meta['total'], items.length),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

class BudgetExecutionPage {
  const BudgetExecutionPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<Map<String, dynamic>> items;
  final int currentPage;
  final int lastPage;
  final int total;
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
