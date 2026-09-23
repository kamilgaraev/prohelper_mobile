import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

final projectParticipantsRepositoryProvider =
    Provider<ProjectParticipantsRepository>((ref) {
      return ProjectParticipantsRepository(ref.read(dioProvider));
    });

class ProjectParticipantsRepository {
  ProjectParticipantsRepository(this._dio);

  final Dio _dio;

  Future<ProjectParticipantsPage> fetchPage({
    required int projectId,
    String? query,
    bool availableUsers = false,
    int page = 1,
    int perPage = 20,
  }) async {
    final path =
        _basePath(projectId) + (availableUsers ? '/available-users' : '');
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: {
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          'page': page,
          'per_page': perPage,
        },
      );
      final body = _map(response.data);
      final rows = body['data'] is List ? body['data'] as List : const [];
      final meta = _map(body['meta']);
      return ProjectParticipantsPage(
        items:
            rows
                .whereType<Map>()
                .map((row) => ProjectParticipant.fromJson(row))
                .toList(),
        currentPage: _int(meta['current_page'], page),
        lastPage: _int(meta['last_page'], page),
        total: _int(meta['total'], rows.length),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> bind({required int projectId, required int userId}) async {
    try {
      await _dio.put<Map<String, dynamic>>(
        '${_basePath(projectId)}/${Uri.encodeComponent(userId.toString())}',
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  String _basePath(int projectId) =>
      '/field-admin/team/projects/${Uri.encodeComponent(projectId.toString())}/participants';
}

class ProjectParticipantsPage {
  const ProjectParticipantsPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<ProjectParticipant> items;
  final int currentPage;
  final int lastPage;
  final int total;
}

class ProjectParticipant {
  const ProjectParticipant({
    required this.id,
    required this.name,
    required this.email,
    this.projectRole = '',
    this.alreadyAssigned = false,
  });

  final int id;
  final String name;
  final String email;
  final String projectRole;
  final bool alreadyAssigned;

  factory ProjectParticipant.fromJson(dynamic source) {
    final json = _map(source);
    return ProjectParticipant(
      id: _int(json['id'], 0),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      projectRole: (json['project_role'] ?? '').toString(),
      alreadyAssigned: json['already_assigned'] == true,
    );
  }
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
