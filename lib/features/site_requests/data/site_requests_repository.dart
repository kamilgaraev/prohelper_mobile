import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'site_request_model.dart';

final siteRequestsRepositoryProvider = Provider<SiteRequestsRepository>((ref) {
  return SiteRequestsRepository(ref.read(dioProvider));
});

class SiteRequestsRepository {
  final Dio _dio;

  SiteRequestsRepository(this._dio);

  /// Получить список заявок с пагинацией и фильтрами
  Future<List<SiteRequestModel>> fetchSiteRequests({
    int page = 1,
    int perPage = 20,
    String? status,
    int? projectId,
  }) async {
    try {
      final queryParams = {
        'page': page,
        'per_page': perPage,
        if (status != null) 'status': status,
        if (projectId != null) 'project_id': projectId,
      };

      final response = await _dio.get('/site-requests', queryParameters: queryParams);

      final List<dynamic> list;
      // Обработка структуры MobileResponse: { success: true, data: { data: [...], current_page: ... } }
      if (response.data['data'] != null && response.data['data']['data'] is List) {
        list = response.data['data']['data'];
      } else if (response.data['data'] is List) {
        list = response.data['data'];
      } else {
        list = [];
      }

      return list.map((e) => SiteRequestModel.fromJson(e)).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить заявки.',
      );
    } catch (_) {
      throw const ApiException('Не удалось загрузить заявки.');
    }
  }

  /// Получить детали конкретной заявки
  Future<SiteRequestModel> fetchSiteRequestDetails(int id) async {
    try {
      final response = await _dio.get('/site-requests/$id');
      
      final Map<String, dynamic> data = response.data['data'];
      return SiteRequestModel.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить детали заявки.',
      );
    } catch (_) {
      throw const ApiException('Не удалось загрузить детали заявки.');
    }
  }

  /// Создать новую заявку
  Future<SiteRequestModel> createSiteRequest(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/site-requests', data: data);
      return SiteRequestModel.fromJson(response.data['data']);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось создать заявку.',
      );
    } catch (_) {
      throw const ApiException('Не удалось создать заявку.');
    }
  }

  /// Обновить заявку (черновик)
  Future<SiteRequestModel> updateSiteRequest(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/site-requests/$id', data: data);
      return SiteRequestModel.fromJson(response.data['data']);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось обновить заявку.',
      );
    } catch (_) {
      throw const ApiException('Не удалось обновить заявку.');
    }
  }

  /// Отправить заявку на согласование
  Future<SiteRequestModel> submitSiteRequest(int id) async {
    try {
      final response = await _dio.post('/site-requests/$id/submit');
      return SiteRequestModel.fromJson(response.data['data']);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось отправить заявку.',
      );
    } catch (_) {
      throw const ApiException('Не удалось отправить заявку.');
    }
  }

  /// Отменить заявку
  Future<SiteRequestModel> cancelSiteRequest(int id, {String? notes}) async {
    try {
      final response = await _dio.post('/site-requests/$id/cancel', data: {
        if (notes != null) 'notes': notes,
      });
      return SiteRequestModel.fromJson(response.data['data']);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось отменить заявку.',
      );
    } catch (_) {
      throw const ApiException('Не удалось отменить заявку.');
    }
  }

  /// Подтвердить выполнение (получение материалов)
  Future<SiteRequestModel> completeSiteRequest(int id, {String? notes}) async {
    try {
      final response = await _dio.post('/site-requests/$id/complete', data: {
        if (notes != null) 'notes': notes,
      });
      return SiteRequestModel.fromJson(response.data['data']);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось завершить заявку.',
      );
    } catch (_) {
      throw const ApiException('Не удалось завершить заявку.');
    }
  }

  /// Получить популярные шаблоны
  Future<List<Map<String, dynamic>>> fetchTemplates() async {
    try {
      final response = await _dio.get('/site-requests/templates');
      return List<Map<String, dynamic>>.from(response.data['data']);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить шаблоны.',
      );
    } catch (_) {
      throw const ApiException('Не удалось загрузить шаблоны.');
    }
  }

  /// Создать заявку из шаблона
  Future<SiteRequestModel> createFromTemplate(int templateId, int projectId) async {
    try {
      final response = await _dio.post('/site-requests/from-template/$templateId', data: {
        'project_id': projectId,
      });
      return SiteRequestModel.fromJson(response.data['data']);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось создать заявку из шаблона.',
      );
    } catch (_) {
      throw const ApiException('Не удалось создать заявку из шаблона.');
    }
  }

  /// Получить мета-данные (справочники)
  Future<Map<String, dynamic>> fetchMeta() async {
    try {
      final response = await _dio.get('/site-requests/meta');
      return response.data['data'];
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить справочники.',
      );
    } catch (_) {
      throw const ApiException('Не удалось загрузить справочники.');
    }
  }
}
