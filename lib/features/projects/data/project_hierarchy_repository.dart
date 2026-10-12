import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/mobile_api_response.dart';

final projectHierarchyRepositoryProvider = Provider<ProjectHierarchyRepository>(
  (ref) => ProjectHierarchyRepository(ref.read(dioProvider)),
);

class HierarchyParticipant {
  const HierarchyParticipant({
    required this.id,
    required this.name,
    this.parentId,
  });
  final int id;
  final String name;
  final int? parentId;
}

class ProjectHierarchy {
  const ProjectHierarchy({
    required this.configured,
    required this.canManage,
    required this.participants,
    this.rootId,
  });
  final bool configured;
  final bool canManage;
  final int? rootId;
  final List<HierarchyParticipant> participants;
  factory ProjectHierarchy.fromJson(Map<String, dynamic> json) =>
      ProjectHierarchy(
        configured: json['configured'] == true,
        canManage: json['can_manage'] == true,
        rootId: (json['root_organization_id'] as num?)?.toInt(),
        participants:
            (json['participants'] as List).map((value) {
              final row = Map<String, dynamic>.from(value as Map);
              return HierarchyParticipant(
                id: (row['organization_id'] as num).toInt(),
                name: row['organization_name'] as String,
                parentId: (row['parent_organization_id'] as num?)?.toInt(),
              );
            }).toList(),
      );
}

class ProjectHierarchyRepository {
  ProjectHierarchyRepository(this._dio);
  final Dio _dio;
  Future<ProjectHierarchy> load(int projectId) async {
    try {
      final response = await _dio.get(
        '/projects/$projectId/participants/hierarchy',
      );
      return ProjectHierarchy.fromJson(
        Map<String, dynamic>.from(
          MobileApiResponse.payload(response.data) as Map,
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить иерархию проекта.',
      );
    }
  }

  Future<ProjectHierarchy> save(
    int projectId,
    int rootId,
    Map<int, int> parents,
  ) async {
    try {
      final response = await _dio.put(
        '/projects/$projectId/participants/hierarchy',
        data: {
          'root_organization_id': rootId,
          'parents':
              parents.entries
                  .where((row) => row.key != rootId)
                  .map(
                    (row) => {
                      'organization_id': row.key,
                      'parent_organization_id': row.value,
                    },
                  )
                  .toList(),
        },
      );
      return ProjectHierarchy.fromJson(
        Map<String, dynamic>.from(
          MobileApiResponse.payload(response.data) as Map,
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось сохранить иерархию проекта.',
      );
    }
  }
}
