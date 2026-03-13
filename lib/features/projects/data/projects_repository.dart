import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
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

      final List<dynamic> list;
      if (response.data is List) {
        list = response.data;
      } else if (response.data is Map &&
          response.data['data'] is Map &&
          response.data['data']['data'] is List) {
        list = response.data['data']['data'];
      } else if (response.data is Map && response.data['data'] is List) {
        list = response.data['data'];
      } else {
        list = [];
      }

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
