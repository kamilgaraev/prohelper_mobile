import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/network/dio_client.dart';
import 'project_model.dart';

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  return ProjectsRepository(ref.read(dioProvider));
});

class ProjectsRepository {
  final Dio _dio;

  ProjectsRepository(this._dio);

  Future<List<Project>> fetchProjects() async {
    try {
      final response = await _dio.get('/projects');
      
      // Log response for debugging
      // import 'dart:developer'; // make sure to import this
      // log('GET /projects payload: ${response.data}'); 

      final List<dynamic> list;
      if (response.data is List) {
        list = response.data;
      } else if (response.data is Map && response.data['data'] is Map && response.data['data']['data'] is List) {
         // Handle nested: { data: { data: [...] } }
        list = response.data['data']['data'];
      } else if (response.data is Map && response.data['data'] is List) {
        // Handle standard: { data: [...] }
        list = response.data['data'];
      } else {
        // Fallback or empty
        list = [];
      }

      return list.map((e) => Project.fromJson(e)).toList();
    } catch (e) {
      throw e;
    }
  }
}
