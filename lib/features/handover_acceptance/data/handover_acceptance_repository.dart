import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'handover_acceptance_model.dart';

final handoverAcceptanceRepositoryProvider =
    Provider<HandoverAcceptanceRepository>((ref) {
      return HandoverAcceptanceRepository(ref.read(dioProvider));
    });

class HandoverAcceptanceRepository {
  HandoverAcceptanceRepository(this._dio);

  final Dio _dio;

  Future<List<AcceptanceScopeModel>> fetchScopes({int? projectId}) async {
    try {
      final response = await _dio.get(
        '/handover-acceptance/scopes',
        queryParameters: {if (projectId != null) 'project_id': projectId},
      );

      final payload = response.data['data'];
      final List<dynamic> list;
      if (payload is Map && payload['items'] is List) {
        list = payload['items'] as List;
      } else if (payload is Map && payload['data'] is List) {
        list = payload['data'] as List;
      } else if (payload is List) {
        list = payload;
      } else {
        list = [];
      }

      return list
          .whereType<Map>()
          .map(
            (item) => AcceptanceScopeModel.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить приемку зон.',
      );
    } catch (_) {
      throw const ApiException('Не удалось загрузить приемку зон.');
    }
  }

  Future<AcceptanceFindingModel> createFinding(
    int sessionId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post(
        '/handover-acceptance/sessions/$sessionId/findings',
        data: data,
      );
      return AcceptanceFindingModel.fromJson(response.data['data']);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось добавить замечание приемки.',
      );
    } catch (_) {
      throw const ApiException('Не удалось добавить замечание приемки.');
    }
  }

  Future<AcceptanceFindingModel> resolveFinding(
    int findingId, {
    required String resolutionComment,
  }) async {
    try {
      final response = await _dio.post(
        '/handover-acceptance/findings/$findingId/resolve',
        data: {'resolution_comment': resolutionComment},
      );
      return AcceptanceFindingModel.fromJson(response.data['data']);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось подтвердить устранение замечания.',
      );
    } catch (_) {
      throw const ApiException('Не удалось подтвердить устранение замечания.');
    }
  }

  Future<AcceptanceScopeModel> readyForReinspection(int scopeId) async {
    try {
      final response = await _dio.post(
        '/handover-acceptance/scopes/$scopeId/ready-for-reinspection',
      );
      return AcceptanceScopeModel.fromJson(response.data['data']);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось отправить зону на повторную проверку.',
      );
    } catch (_) {
      throw const ApiException(
        'Не удалось отправить зону на повторную проверку.',
      );
    }
  }
}
