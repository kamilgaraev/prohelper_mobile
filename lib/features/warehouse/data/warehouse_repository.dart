import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'warehouse_summary_model.dart';

final warehouseRepositoryProvider = Provider<WarehouseRepository>((ref) {
  return WarehouseRepository(ref.read(dioProvider));
});

class WarehouseRepository {
  WarehouseRepository(this._dio);

  final Dio _dio;

  Future<WarehouseSummaryModel> fetchWarehouseSummary() async {
    try {
      final response = await _dio.get('/warehouse');
      final data = response.data;
      final payload = data is Map<String, dynamic> ? data['data'] : null;

      if (payload is Map<String, dynamic>) {
        return WarehouseSummaryModel.fromJson(payload);
      }

      if (payload is Map) {
        return WarehouseSummaryModel.fromJson(
          payload.map((key, value) => MapEntry(key.toString(), value)),
        );
      }

      throw const ApiException('Сервер вернул пустой ответ по складу.');
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить данные по складу.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось загрузить данные по складу.');
    }
  }
}
