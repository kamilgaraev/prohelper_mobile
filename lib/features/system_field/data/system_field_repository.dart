import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';

final systemFieldRepositoryProvider = Provider<SystemFieldRepository>(
  (ref) => SystemFieldRepository(ref.read(dioProvider)),
);

class SystemFieldPage {
  const SystemFieldPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });

  final List<Map<String, dynamic>> items;
  final int currentPage;
  final int lastPage;
}

class SystemFieldRepository {
  SystemFieldRepository(this._dio);
  final Dio _dio;
  static const _base = '/system';

  Future<Map<String, dynamic>> oneCStatus() =>
      _getMap('$_base/one-c-exchange/status');

  Future<SystemFieldPage> oneCHistory({int page = 1, String? search}) =>
      _getPage('$_base/one-c-exchange/history', page: page, search: search);

  Future<SystemFieldPage> campaigns({int page = 1, String? search}) => _getPage(
    '$_base/access-recertification/campaigns',
    page: page,
    search: search,
  );

  Future<SystemFieldPage> myReviews({int page = 1, String? search}) => _getPage(
    '$_base/access-recertification/reviews/my',
    page: page,
    search: search,
  );

  Future<Map<String, dynamic>> decide({
    required String uuid,
    required String decision,
    required String reason,
    bool confirmation = false,
    String? validUntil,
    int? revokeExecutorUserId,
    List<String> compensatingControls = const [],
  }) async {
    try {
      final response = await _dio.post(
        '$_base/access-recertification/items/$uuid/decisions',
        data: {
          'decision': decision,
          'reason': reason,
          if (confirmation) 'confirmation': true,
          if (validUntil != null) 'valid_until': validUntil,
          if (revokeExecutorUserId != null)
            'revoke_executor_user_id': revokeExecutorUserId,
          if (compensatingControls.isNotEmpty)
            'compensating_controls': compensatingControls,
        },
      );
      return MobileApiResponse.dataMap(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> retryOneC(String operationId) async {
    try {
      final response = await _dio.post(
        '$_base/one-c-exchange/journal/$operationId/retry',
      );
      return MobileApiResponse.dataMap(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<SystemFieldPage> currentCoefficients({
    int page = 1,
    String? search,
    required String appliesTo,
  }) => _getPage(
    '$_base/rate-coefficients/current',
    page: page,
    search: search,
    extra: {'applies_to': appliesTo},
  );

  Future<SystemFieldPage> events({int page = 1, String? search}) =>
      _getPage('$_base/events', page: page, search: search);

  Future<Map<String, dynamic>> _getMap(String path) async {
    try {
      final response = await _dio.get(path);
      return MobileApiResponse.dataMap(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<SystemFieldPage> _getPage(
    String path, {
    required int page,
    String? search,
    Map<String, dynamic> extra = const {},
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: {
          'page': page,
          'per_page': 20,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          ...extra,
        },
      );
      final payload = response.data;
      final list = MobileApiResponse.dataList(payload);
      final meta = MobileApiResponse.list(payload).meta;
      return SystemFieldPage(
        items: list,
        currentPage: _int(meta['current_page'] ?? meta['page'], page),
        lastPage: _int(meta['last_page'], page),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

int _int(dynamic value, int fallback) =>
    value is int ? value : int.tryParse('$value') ?? fallback;
