import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import 'month_timekeeping_model.dart';

final monthTimekeepingRepositoryProvider = Provider<MonthTimekeepingRepository>(
  (ref) => MonthTimekeepingRepository(ref.read(dioProvider)),
);

class MonthTimekeepingRepository {
  MonthTimekeepingRepository(this._dio);
  final Dio _dio;
  static const base = '/workforce/timekeeping/periods';

  Future<T> _request<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<TimekeepingPage> periods(
    String month, {
    int? projectId,
    int page = 1,
  }) => _request(() async {
    final response = await _dio.get(
      base,
      queryParameters: {
        'month': month,
        'page': page,
        'per_page': 25,
        if (projectId != null)
          'project_id': projectId
        else
          'scope': 'organization',
      },
    );
    final result = MobileApiResponse.list(response.data);
    return TimekeepingPage(
      result.data.map(TimekeepingPeriod.fromJson).toList(),
      (result.meta['current_page'] as num).toInt(),
      (result.meta['last_page'] as num).toInt(),
    );
  });

  Future<TimekeepingPeriod> period(int id) => _request(
    () async => TimekeepingPeriod.fromJson(
      MobileApiResponse.dataMap((await _dio.get('$base/$id')).data),
    ),
  );

  Future<TimekeepingPeriod> _post(String path, Map<String, dynamic> data) =>
      _request(
        () async => TimekeepingPeriod.fromJson(
          MobileApiResponse.dataMap((await _dio.post(path, data: data)).data),
        ),
      );

  Future<TimekeepingPeriod> create(String month, int? projectId) => _post(
    base,
    {'month': month, if (projectId != null) 'project_id': projectId},
  );
  Future<TimekeepingPeriod> refresh(TimekeepingPeriod period) => _post(
    '$base/${period.id}/refresh',
    {'expected_revision': period.revision},
  );
  Future<TimekeepingPeriod> saveCell(
    TimekeepingPeriod period,
    Map<String, dynamic> data,
  ) => _post('$base/${period.id}/cells', {
    ...data,
    'expected_revision': period.revision,
  });
  Future<TimekeepingPeriod> action(
    TimekeepingPeriod period,
    String action,
    Map<String, dynamic> data,
  ) => _post('$base/${period.id}/actions', {
    ...data,
    'action': action,
    'expected_revision': period.revision,
  });

  Future<TimekeepingDocument> export(int periodId, String format) =>
      _request(() async {
        final response = await _dio.post(
          '$base/$periodId/documents',
          data: {'format': format},
        );
        return TimekeepingDocument.fromJson(
          MobileApiResponse.dataMap(response.data),
        );
      });

  Future<Uri> download(int documentId) => _request(() async {
    final response = await _dio.get(
      '/workforce/timekeeping/documents/$documentId/download',
    );
    final uri = Uri.parse(
      MobileApiResponse.dataMap(response.data)['url'] as String,
    );
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Неверный адрес документа.');
    }
    return uri;
  });

  Future<int> uploadSignedFile(
    TimekeepingPeriod period,
    int documentId,
    MultipartFile file,
  ) => _request(() async {
    final response = await _dio.post(
      '$base/${period.id}/signed-file',
      data: FormData.fromMap({
        'file': file,
        'document_id': documentId,
        'expected_revision': period.revision,
      }),
    );
    return (MobileApiResponse.dataMap(response.data)['file_id'] as num).toInt();
  });
}
