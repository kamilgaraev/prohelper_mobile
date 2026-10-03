import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import 'bim_models.dart';

final bimRepositoryProvider = Provider<BimRepository>(
  (ref) => BimRepository(ref.read(dioProvider)),
);

class BimRepository {
  BimRepository(this.dio);
  final Dio dio;
  static const prefix = '/design-management';

  Future<dynamic> _request(
    String method,
    String path, {
    dynamic data,
    BimJson? query,
    String? idempotencyKey,
  }) async {
    try {
      final response = await dio.request(
        '$prefix$path',
        data: data,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {
            if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
          },
        ),
      );
      return response.data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<BimPage<T>> _list<T>(
    String path,
    T Function(BimJson) parse, {
    required int projectId,
    int page = 1,
    BimJson filters = const {},
  }) async {
    final response = await _request(
      'GET',
      path,
      query: {
        'project_id': projectId,
        'page': page,
        'per_page': 25,
        ...filters,
      },
    );
    final envelope = MobileApiResponse.list(response);
    return BimPage.fromJson(envelope.data, envelope.meta, parse);
  }

  Future<BimPage<BimJson>> packages(int projectId, {int page = 1}) =>
      _list('/packages', (json) => json, projectId: projectId, page: page);
  Future<BimPage<BimModelVersion>> versions(
    int projectId, {
    int page = 1,
    String query = '',
    String? status,
  }) => _list(
    '/project-model-versions',
    BimModelVersion.fromJson,
    projectId: projectId,
    page: page,
    filters: {
      if (query.trim().isNotEmpty) 'search': query.trim(),
      if (status != null) 'status': status,
    },
  );
  Future<BimPreparedViewer> viewer(int id) async => BimPreparedViewer.fromJson(
    id,
    MobileApiResponse.dataMap(
      await _request('GET', '/model-versions/$id/viewer'),
    ),
  );
  Future<BimPreparedViewer> prepare(int id) async => BimPreparedViewer.fromJson(
    id,
    MobileApiResponse.dataMap(
      await _request('POST', '/model-versions/$id/viewer/preparation'),
    ),
  );
  Future<BimPreparedViewer> viewerForOpening(
    int id, {
    bool Function()? isActive,
  }) async {
    final prepared = await viewer(id);
    if (prepared.needsUpdate &&
        prepared.canPrepare &&
        (isActive?.call() ?? true)) {
      return prepare(id);
    }
    return prepared;
  }

  Future<BimJson> element(int id, int expressId) async =>
      MobileApiResponse.dataMap(
        await _request('GET', '/model-versions/$id/elements/$expressId'),
      );
  Future<BimPage<BimJson>> elements(int id, {int page = 1}) async {
    final envelope = MobileApiResponse.list(
      await _request(
        'GET',
        '/model-versions/$id/elements',
        query: {'page': page},
      ),
    );
    return BimPage.fromJson(envelope.data, envelope.meta, (json) => json);
  }

  Future<BimJson> offlinePackage(int id) async => MobileApiResponse.dataMap(
    await _request('GET', '/model-versions/$id/offline-package'),
  );
  Future<BimPage<BimModelSet>> sets(int projectId, {int page = 1}) => _list(
    '/model-sets',
    BimModelSet.fromJson,
    projectId: projectId,
    page: page,
  );
  Future<BimModelSet> saveSet({
    required int projectId,
    required String title,
    required Map<int, BimTransform> composition,
    BimModelSet? existing,
  }) async {
    final json = {
      'project_id': projectId,
      'title': title.trim(),
      'version_ids': composition.keys.toList(),
      'transforms': composition.map(
        (id, transform) => MapEntry('$id', transform.toJson()),
      ),
      if (existing != null) 'expected_revision': existing.revision,
    };
    return BimModelSet.fromJson(
      MobileApiResponse.dataMap(
        await _request(
          existing == null ? 'POST' : 'PATCH',
          '/model-sets${existing == null ? '' : '/${existing.id}'}',
          data: json,
        ),
      ),
    );
  }

  Future<BimJson> openSet(int id, int revision) async =>
      MobileApiResponse.dataMap(
        await _request('GET', '/model-sets/$id/revisions/$revision/open'),
      );
  Future<void> deleteSet(BimModelSet set) async => _request(
    'DELETE',
    '/model-sets/${set.id}',
    data: {'expected_revision': set.revision},
  );
  Future<BimPage<BimIssue>> issues(
    int projectId, {
    int page = 1,
    String? status,
    int? versionId,
  }) => _list(
    '/project-issues',
    BimIssue.fromJson,
    projectId: projectId,
    page: page,
    filters: {
      if (status != null) 'status': status,
      if (versionId != null) 'version_id': versionId,
    },
  );
  Future<BimIssue> issue(int id) async => BimIssue.fromJson(
    MobileApiResponse.dataMap(await _request('GET', '/project-issues/$id')),
  );
  Future<BimIssue> createIssue(
    int projectId,
    BimJson payload, {
    String? idempotencyKey,
  }) async => BimIssue.fromJson(
    MobileApiResponse.dataMap(
      await _request(
        'POST',
        '/project-issues',
        data: {'project_id': projectId, ...payload},
        idempotencyKey: idempotencyKey,
      ),
    ),
  );
  Future<BimIssue> issueAction(
    BimIssue issue,
    String action,
    BimJson payload, {
    String? idempotencyKey,
  }) async => BimIssue.fromJson(
    MobileApiResponse.dataMap(
      await _request(
        'POST',
        '/project-issues/${issue.id}/actions/$action',
        data: {'expected_revision': issue.revision, ...payload},
        idempotencyKey: idempotencyKey,
      ),
    ),
  );
  Future<BimIssue> attachSnapshot(
    BimIssue issue,
    Uint8List bytes, {
    String? idempotencyKey,
  }) async => BimIssue.fromJson(
    MobileApiResponse.dataMap(
      await _request(
        'POST',
        '/project-issues/${issue.id}/snapshot',
        data: FormData.fromMap({
          'expected_revision': issue.revision,
          'file': MultipartFile.fromBytes(
            bytes,
            filename: 'snapshot.png',
            contentType: DioMediaType('image', 'png'),
          ),
        }),
        idempotencyKey: idempotencyKey,
      ),
    ),
  );
  Future<BimIssue> attachPhoto(
    BimIssue issue,
    String path, {
    String? idempotencyKey,
  }) async => BimIssue.fromJson(
    MobileApiResponse.dataMap(
      await _request(
        'POST',
        '/project-issues/${issue.id}/photos',
        data: FormData.fromMap({
          'expected_revision': issue.revision,
          'file': await MultipartFile.fromFile(path),
        }),
        idempotencyKey: idempotencyKey,
      ),
    ),
  );
  Future<BimPage<BimJson>> assignees(
    int projectId, {
    int page = 1,
    String query = '',
  }) => _list(
    '/project-issues/assignees',
    (json) => json,
    projectId: projectId,
    page: page,
    filters: {if (query.trim().isNotEmpty) 'search': query.trim()},
  );
  Future<BimJson> issueContext(int id) async => MobileApiResponse.dataMap(
    await _request('GET', '/project-issues/$id/bim-context'),
  );
}
