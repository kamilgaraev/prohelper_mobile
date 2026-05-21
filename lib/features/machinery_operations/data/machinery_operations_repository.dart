import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import 'machinery_operations_model.dart';

final machineryOperationsRepositoryProvider =
    Provider<MachineryOperationsRepository>((ref) {
      return MachineryOperationsRepository(ref.read(dioProvider));
    });

class MachineryOperationsRepository {
  MachineryOperationsRepository(this._dio);

  final Dio _dio;

  Future<List<MachineryAssetModel>> fetchAssets({int? projectId}) async {
    try {
      final response = await _dio.get(
        '/machinery-operations/assets',
        queryParameters: {if (projectId != null) 'project_id': projectId},
      );

      return _list(response.data).map(MachineryAssetModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить технику.',
      );
    } catch (_) {
      throw const ApiException('Не удалось загрузить технику.');
    }
  }

  Future<List<MachineryShiftReportModel>> fetchShiftReports({
    int? projectId,
  }) async {
    try {
      final response = await _dio.get(
        '/machinery-operations/shift-reports',
        queryParameters: {if (projectId != null) 'project_id': projectId},
      );

      return _list(
        response.data,
      ).map(MachineryShiftReportModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить сменные рапорты.',
      );
    } catch (_) {
      throw const ApiException('Не удалось загрузить сменные рапорты.');
    }
  }

  Future<MachineryShiftReportModel> createShiftReport({
    required int assetId,
    required int projectId,
    required String reportDate,
    required double actualHours,
    required double fuelConsumed,
  }) async {
    try {
      final response = await _dio.post(
        '/machinery-operations/shift-reports',
        data: {
          'asset_id': assetId,
          'project_id': projectId,
          'report_date': reportDate,
          'planned_hours': actualHours,
          'actual_hours': actualHours,
          'fuel_consumed': fuelConsumed,
          'work_description': 'Сменный рапорт техники',
        },
      );

      return MachineryShiftReportModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось создать сменный рапорт.',
      );
    } catch (_) {
      throw const ApiException('Не удалось создать сменный рапорт.');
    }
  }

  Future<void> createDowntime({
    required int assetId,
    required int projectId,
    required int durationMinutes,
  }) async {
    try {
      await _dio.post(
        '/machinery-operations/downtimes',
        data: {
          'asset_id': assetId,
          'project_id': projectId,
          'reason': 'waiting_material',
          'started_at': DateTime.now().toIso8601String(),
          'duration_minutes': durationMinutes,
        },
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось зафиксировать простой.',
      );
    } catch (_) {
      throw const ApiException('Не удалось зафиксировать простой.');
    }
  }

  Future<void> createFuelIssue({
    required int assetId,
    required int projectId,
    required double quantity,
  }) async {
    try {
      await _dio.post(
        '/machinery-operations/fuel-issues',
        data: {
          'asset_id': assetId,
          'project_id': projectId,
          'issued_at': DateTime.now().toIso8601String(),
          'fuel_type': 'diesel',
          'quantity': quantity,
        },
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось зафиксировать ГСМ.',
      );
    } catch (_) {
      throw const ApiException('Не удалось зафиксировать ГСМ.');
    }
  }

  List<Map<String, dynamic>> _list(dynamic responseData) {
    return machineryMapList(MobileApiResponse.dataList(responseData));
  }

  Map<String, dynamic> _object(dynamic responseData) {
    return MobileApiResponse.dataMap(responseData);
  }
}
