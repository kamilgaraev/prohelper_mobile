import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/network/dio_client.dart';
import 'package:prohelpers_mobile/core/network/mobile_api_response.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_widget_model.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.read(dioProvider));
});

class DashboardRepository {
  DashboardRepository(this._dio);

  final Dio _dio;

  Future<List<DashboardWidgetModel>> fetchWidgets() async {
    try {
      final response = await _dio.get('/dashboard');
      final payload = MobileApiResponse.dataMap(response.data);
      final widgets = payload['widgets'];

      if (widgets is! List) {
        return const [];
      }

      return widgets
          .whereType<Map>()
          .map(
            (widget) => DashboardWidgetModel.fromJson(
              widget.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where((widget) => widget.type != DashboardWidgetType.unknown)
          .toList()
        ..sort((left, right) => left.order.compareTo(right.order));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить дашборд.',
      );
    } catch (_) {
      throw const ApiException('Не удалось загрузить дашборд.');
    }
  }
}
