import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import 'budget_estimate_model.dart';

final budgetEstimatesRepositoryProvider = Provider<BudgetEstimatesRepository>((
  ref,
) {
  return BudgetEstimatesRepository(ref.read(dioProvider));
});

class BudgetEstimatesRepository {
  BudgetEstimatesRepository(this._dio);

  final Dio _dio;

  Future<BudgetEstimatePage> fetchEstimates({
    required int projectId,
    int page = 1,
    String? status,
    String? search,
  }) async {
    try {
      final response = await _dio.get(
        '/budget-estimates/estimates',
        queryParameters: {
          'project_id': projectId,
          'page': page,
          'per_page': 20,
          if (status != null) 'status': status,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      final data = MobileApiResponse.dataMap(response.data);
      final rows = data['items'];
      final meta = data['meta'];
      if (rows is! List || meta is! Map) {
        throw const FormatException('Некорректный список смет');
      }
      final details = Map<String, dynamic>.from(meta);
      return BudgetEstimatePage(
        items:
            rows
                .whereType<Map>()
                .map(
                  (row) => BudgetEstimateModel.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList(),
        currentPage: _pageNumber(details['current_page']),
        lastPage: _pageNumber(details['last_page']),
        total: _pageNumber(details['total'], fallback: 0),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<BudgetEstimateSummaryModel> fetchSummary({
    required int projectId,
  }) async {
    try {
      final response = await _dio.get(
        '/budget-estimates/summary',
        queryParameters: {'project_id': projectId},
      );

      return BudgetEstimateSummaryModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<BudgetEstimateDetailModel> fetchEstimate(int id) async {
    try {
      final response = await _dio.get('/budget-estimates/estimates/$id');

      return BudgetEstimateDetailModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<BudgetEstimateModel> approveEstimate({
    required int id,
    String? comment,
  }) async {
    try {
      final trimmedComment = comment?.trim();
      final response = await _dio.post(
        '/budget-estimates/estimates/$id/approve',
        data: {
          if (trimmedComment != null && trimmedComment.isNotEmpty)
            'comment': trimmedComment,
        },
      );

      return BudgetEstimateModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<BudgetEstimateModel> requestChanges({
    required int id,
    required String comment,
  }) async {
    final trimmedComment = comment.trim();
    if (trimmedComment.isEmpty) {
      throw ArgumentError.value(comment, 'comment');
    }

    try {
      final response = await _dio.post(
        '/budget-estimates/estimates/$id/request-changes',
        data: {'comment': trimmedComment},
      );

      return BudgetEstimateModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

class BudgetEstimatePage {
  const BudgetEstimatePage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<BudgetEstimateModel> items;
  final int currentPage;
  final int lastPage;
  final int total;
}

int _pageNumber(Object? value, {int fallback = 1}) =>
    value is int ? value : int.tryParse('$value') ?? fallback;
