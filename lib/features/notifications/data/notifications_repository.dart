import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'notification_model.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(ref.read(dioProvider));
});

class NotificationsRepository {
  NotificationsRepository(this._dio);

  final Dio _dio;

  Future<NotificationsPageResult> fetchNotifications({
    int page = 1,
    int perPage = 20,
    NotificationFilter filter = NotificationFilter.all,
  }) async {
    try {
      final response = await _dio.get(
        '/notifications',
        queryParameters: <String, dynamic>{
          'page': page,
          'per_page': perPage,
          if (filter.queryValue != null) 'filter': filter.queryValue,
        },
      );

      return _parsePage(response.data, page: page, perPage: perPage);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить уведомления.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось загрузить уведомления.');
    }
  }

  Future<NotificationModel> fetchNotification(String id) async {
    try {
      final response = await _dio.get('/notifications/$id');
      return NotificationModel.fromJson(_extractData(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить уведомление.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось загрузить уведомление.');
    }
  }

  Future<NotificationModel> markAsRead(String id) async {
    try {
      final response = await _dio.post('/notifications/$id/mark-read');
      return NotificationModel.fromJson(_extractData(response.data));
    } on DioException catch (error) {
      if (error.response?.statusCode == 404 ||
          error.response?.statusCode == 405) {
        try {
          final response = await _dio.patch('/notifications/$id/read');
          return NotificationModel.fromJson(_extractData(response.data));
        } on DioException catch (fallbackError) {
          throw ApiException.fromDio(
            fallbackError,
            fallbackMessage: 'Не удалось отметить уведомление прочитанным.',
          );
        }
      }

      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось отметить уведомление прочитанным.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось отметить уведомление прочитанным.');
    }
  }

  Future<int> markAllAsRead() async {
    try {
      final response = await _dio.post('/notifications/mark-all-read');
      final data = _extractData(response.data);
      return notificationAsInt(data['count']);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось отметить уведомления прочитанными.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось отметить уведомления прочитанными.');
    }
  }

  Future<int> fetchUnreadCount() async {
    try {
      final response = await _dio.get('/notifications/unread-count');
      final data = _extractData(response.data);
      return notificationAsInt(data['count']);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить счетчик уведомлений.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось загрузить счетчик уведомлений.');
    }
  }

  NotificationsPageResult _parsePage(
    dynamic responseData, {
    required int page,
    required int perPage,
  }) {
    final root = notificationAsMap(responseData);
    final rootData = root['data'];
    final dataMap = notificationAsMap(rootData);
    final itemsPayload = dataMap['data'] is List ? dataMap['data'] : rootData;
    final items = notificationAsList(
      itemsPayload,
    ).map(NotificationModel.fromJson).toList(growable: false);
    final rootMeta = notificationAsMap(root['meta']);
    final meta = rootMeta.isNotEmpty ? rootMeta : dataMap;
    final currentPage = notificationAsInt(meta['current_page']);
    final lastPage = notificationAsInt(meta['last_page']);
    final resolvedPerPage = notificationAsInt(meta['per_page']);
    final total = notificationAsInt(meta['total']);

    return NotificationsPageResult(
      items: items,
      currentPage: currentPage == 0 ? page : currentPage,
      lastPage: lastPage == 0 ? page : lastPage,
      perPage: resolvedPerPage == 0 ? perPage : resolvedPerPage,
      total: total == 0 ? items.length : total,
    );
  }

  Map<String, dynamic> _extractData(dynamic responseData) {
    final root = notificationAsMap(responseData);
    final data = root['data'];
    final dataMap = notificationAsMap(data);

    if (dataMap.isNotEmpty) {
      return dataMap;
    }

    return root;
  }
}
