import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import 'act_model.dart';

final actsRepositoryProvider = Provider<ActsRepository>(
  (ref) => ActsRepository(ref.read(dioProvider)),
);

class ActPage {
  const ActPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });
  final List<ActModel> items;
  final int currentPage;
  final int lastPage;
}

class ActsRepository {
  ActsRepository(this._dio);
  final Dio _dio;
  static const _base = '/acts';

  Future<ActPage> list({
    required int projectId,
    int page = 1,
    String? status,
  }) async {
    try {
      final response = await _dio.get(
        _base,
        queryParameters: {
          'project_id': projectId,
          'page': page,
          'per_page': 20,
          if (status != null) 'status': status,
        },
      );
      final data = MobileApiResponse.dataMap(response.data);
      final items =
          (data['items'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (value) => ActModel.fromJson(Map<String, dynamic>.from(value)),
              )
              .toList();
      final meta =
          data['meta'] is Map
              ? Map<String, dynamic>.from(data['meta'] as Map)
              : MobileApiResponse.map(response.data).meta;
      return ActPage(
        items: items,
        currentPage: _int(meta['current_page'], page),
        lastPage: _int(meta['last_page'], page),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ActModel> detail(int id) async {
    try {
      final response = await _dio.get('$_base/$id');
      return ActModel.fromJson(MobileApiResponse.dataMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> confirmField({
    required int id,
    required String signatureData,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dio.post(
        '$_base/$id/field-confirmations',
        data: {
          'signature_data': signatureData,
          'idempotency_key': idempotencyKey,
        },
      );
      return MobileApiResponse.dataMap(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

int _int(dynamic value, int fallback) =>
    value is int ? value : int.tryParse('$value') ?? fallback;
