import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'mobile_module_model.dart';

final modulesRepositoryProvider = Provider<ModulesRepository>((ref) {
  return ModulesRepository(ref.read(dioProvider));
});

class ModulesRepository {
  ModulesRepository(this._dio);

  final Dio _dio;

  Future<List<MobileModuleModel>> fetchModules() async {
    try {
      final response = await _dio.get('/modules');
      final data = response.data;
      final payload = data is Map<String, dynamic> ? data['data'] : null;
      final modules = payload is Map<String, dynamic> ? payload['modules'] : null;

      if (modules is! List) {
        return const [];
      }

      return modules
          .whereType<Map>()
          .map(
            (module) => MobileModuleModel.fromJson(
              module.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList()
        ..sort((left, right) => left.order.compareTo(right.order));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить список модулей.',
      );
    } catch (_) {
      throw const ApiException('Не удалось загрузить список модулей.');
    }
  }
}
