import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import 'my_action.dart';

final myActionsRepositoryProvider = Provider<MyActionsRepository>((ref) {
  return MyActionsRepository(ref.read(dioProvider));
});

class MyActionsRepository {
  const MyActionsRepository(this._dio);

  final Dio _dio;

  Future<MyActionsPage> fetch({
    int? projectId,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final response = await _dio.get(
        '/my-actions',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (projectId != null) 'project_id': projectId,
        },
      );
      final payload = response.data;
      final items = MobileApiResponse.dataList(
        payload,
      ).map(MyAction.fromJson).toList(growable: false);
      final meta = payload is Map ? payload['meta'] : null;
      final metaMap = meta is Map ? meta : const {};
      int readInt(String key, int fallback) {
        final raw = metaMap[key];
        return raw is num ? raw.toInt() : int.tryParse('$raw') ?? fallback;
      }

      return MyActionsPage(
        items: items,
        currentPage: readInt('current_page', page),
        lastPage: readInt('last_page', page),
        total: readInt('total', items.length),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить ваши действия.',
      );
    }
  }
}
