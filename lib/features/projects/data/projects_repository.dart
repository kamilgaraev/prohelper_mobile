import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import 'project_model.dart';

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  return ProjectsRepository(ref.read(dioProvider));
});

class ProjectsRepository {
  ProjectsRepository(this._dio);

  final Dio _dio;

  Future<List<Project>> fetchProjects() async {
    try {
      final response = await _dio.get('/projects');
      final list = MobileApiResponse.dataList(response.data);

      return list.map((e) => Project.fromJson(e)).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить список объектов.',
      );
    } catch (_) {
      throw const ApiException('Не удалось загрузить список объектов.');
    }
  }
}
