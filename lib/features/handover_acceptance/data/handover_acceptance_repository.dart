import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
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

      return MobileApiResponse.dataList(
        response.data,
      ).map(AcceptanceScopeModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
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
      return AcceptanceFindingModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
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
      return AcceptanceFindingModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } catch (_) {
      throw const ApiException('Не удалось подтвердить устранение замечания.');
    }
  }

  Future<AcceptanceScopeModel> readyForReinspection(int scopeId) async {
    try {
      final response = await _dio.post(
        '/handover-acceptance/scopes/$scopeId/ready-for-reinspection',
      );
      return AcceptanceScopeModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } catch (_) {
      throw const ApiException(
        'Не удалось отправить зону на повторную проверку.',
      );
    }
  }
}
