import 'dart:async';
import 'package:dio/dio.dart';
import '../../../core/network/mobile_api_response.dart';
import 'bim_offline_models.dart';

abstract interface class BimOfflineTransport {
  Future<BimPackageManifest> manifest(int versionId, CancelToken token);
  Future<Stream<List<int>>> download(
    BimPackageAsset asset,
    int offset,
    CancelToken token,
  );
  Future<BimIssueReceipt> createIssue(
    Map<String, dynamic> payload,
    String key,
    CancelToken token,
  );
  Future<int> attach(
    int issueId,
    int expectedRevision,
    Map<String, dynamic> attachment,
    Stream<List<int>> Function() bytes,
    String key,
    CancelToken token,
  );
}

class DioBimOfflineTransport implements BimOfflineTransport {
  DioBimOfflineTransport(this.api, {Dio? downloads})
    : downloads =
          downloads ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(minutes: 2),
            ),
          );
  final Dio api;
  final Dio downloads;
  @override
  Future<BimPackageManifest> manifest(int versionId, CancelToken token) async {
    final response = await api.get(
      '/design-management/model-versions/$versionId/offline-package',
      cancelToken: token,
    );
    final result = BimPackageManifest(MobileApiResponse.dataMap(response.data));
    if (result.versionId != versionId) {
      throw const FormatException('Версия пакета не совпадает.');
    }
    return result;
  }

  @override
  Future<Stream<List<int>>> download(
    BimPackageAsset asset,
    int offset,
    CancelToken token,
  ) async {
    final response = await downloads.get<ResponseBody>(
      asset.url,
      options: Options(
        responseType: ResponseType.stream,
        headers: offset == 0 ? {} : {'Range': 'bytes=$offset-'},
      ),
      cancelToken: token,
    );
    if (offset > 0 &&
        (response.statusCode != 206 ||
            !(response.headers.value('content-range') ?? '').startsWith(
              'bytes $offset-',
            ))) {
      throw const FormatException(
        'Сервер не поддерживает продолжение загрузки.',
      );
    }
    final contentLength = int.tryParse(
      response.headers.value('content-length') ?? '',
    );
    if (contentLength != null && contentLength != asset.size - offset) {
      throw const FormatException('Размер пакета изменился.');
    }
    return response.data!.stream;
  }

  @override
  Future<BimIssueReceipt> createIssue(
    Map<String, dynamic> payload,
    String key,
    CancelToken token,
  ) async {
    final response = await api.post(
      '/design-management/project-issues',
      data: payload,
      options: Options(headers: {'Idempotency-Key': key}),
      cancelToken: token,
    );
    final result = MobileApiResponse.dataMap(response.data);
    final id = result['id'];
    if (id is! int || id <= 0) {
      throw const FormatException('Сервер не подтвердил создание замечания.');
    }
    final revision = result['revision'];
    if (revision is! int) {
      throw const FormatException('Сервер не подтвердил версию замечания.');
    }
    return BimIssueReceipt(id, revision);
  }

  @override
  Future<int> attach(
    int issueId,
    int expectedRevision,
    Map<String, dynamic> attachment,
    Stream<List<int>> Function() bytes,
    String key,
    CancelToken token,
  ) async {
    final action = attachment['kind'] == 'snapshot' ? 'snapshot' : 'photos';
    final response = await api.post(
      '/design-management/project-issues/$issueId/$action',
      data: FormData.fromMap({
        'expected_revision': expectedRevision,
        'file': MultipartFile.fromStream(
          bytes,
          attachment['size'] as int,
          filename: attachment['filename'] as String,
        ),
      }),
      options: Options(headers: {'Idempotency-Key': key}),
      cancelToken: token,
    );
    final revision = MobileApiResponse.dataMap(response.data)['revision'];
    if (revision is! int) {
      throw const FormatException('Сервер не подтвердил вложение.');
    }
    return revision;
  }
}
