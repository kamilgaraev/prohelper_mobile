import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'incoming_control_repository.dart';
import '../../auth/domain/auth_provider.dart';

final incomingControlFileServiceProvider =
    Provider.autoDispose<IncomingControlFileService>((ref) {
      ref.watch(
        authProvider.select(
          (state) => state is AuthAuthenticated ? state.sessionIdentity : null,
        ),
      );
      final service = IncomingControlFileService(ref.read(dioProvider));
      ref.onDispose(service.dispose);
      return service;
    });

class IncomingControlFileService {
  IncomingControlFileService(
    this._dio, {
    Future<Directory> Function()? temporaryDirectory,
    Future<bool> Function(String)? openFile,
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _openFile =
           openFile ??
           ((path) async =>
               (await OpenFilex.open(path)).type == ResultType.done);
  final Dio _dio;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<bool> Function(String) _openFile;
  final _files = <File>[];
  final _downloads = <CancelToken>{};
  bool _disposed = false;

  Future<void> export({required int projectId, required String format}) async {
    if (format != 'pdf' && format != 'xlsx') throw ArgumentError.value(format);
    await _download(
      '${IncomingControlRepository.endpoint}/export',
      'journal.$format',
      query: {'project_id': projectId, 'format': format},
      accept:
          format == 'pdf'
              ? 'application/pdf'
              : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<void> openAttachment(
    int controlId,
    Map<String, dynamic> attachment,
  ) async {
    final base = Uri.parse(_dio.options.baseUrl);
    final target = base.resolve(attachment['url']?.toString() ?? '');
    final prefix =
        '${base.path.replaceFirst(RegExp(r'/$'), '')}/quality-control/incoming-controls/$controlId/';
    if (target.origin != base.origin ||
        target.userInfo.isNotEmpty ||
        !(target.path.startsWith('${prefix}attachments/') ||
            target.path.startsWith('${prefix}evidence/'))) {
      throw const ApiException(
        'Ссылка на файл проверки недоступна. Обновите карточку.',
      );
    }
    final mime = attachment['mime']?.toString().split(';').first;
    final extension = switch (mime) {
      'application/pdf' => 'pdf',
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => null,
    };
    if (extension == null) {
      throw const ApiException(
        'Этот формат файла нельзя открыть в приложении.',
      );
    }
    final name = (attachment['name']?.toString() ?? 'document')
        .split(RegExp(r'[/\\]'))
        .last
        .replaceAll(RegExp(r'[^\p{L}\p{N}._ -]', unicode: true), '_');
    final stem = name.replaceFirst(RegExp(r'\.[^.]*$'), '');
    await _download(
      target.toString(),
      '${stem.isEmpty ? 'document' : stem}.$extension',
      accept: mime!,
    );
  }

  Future<void> _download(
    String url,
    String filename, {
    Map<String, dynamic>? query,
    required String accept,
  }) async {
    if (_disposed) return;
    final directory = await _temporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}most-incoming-control-${DateTime.now().microsecondsSinceEpoch}-$filename',
    );
    _files.add(file);
    final cancel = CancelToken();
    _downloads.add(cancel);
    try {
      await _dio.download(
        url,
        file.path,
        queryParameters: query,
        cancelToken: cancel,
        options: Options(headers: {'Accept': accept}, followRedirects: false),
      );
      if (_disposed) return;
      final opened = await _openFile(file.path);
      if (!opened) {
        throw const ApiException(
          'Установите приложение для просмотра выгрузки.',
        );
      }
    } on DioException catch (error) {
      await _delete(file);
      throw ApiException.fromDio(error);
    } finally {
      _downloads.remove(cancel);
      Future<void>.delayed(const Duration(minutes: 2), () => _delete(file));
    }
  }

  Future<void> _delete(File file) async {
    _files.remove(file);
    if (await file.exists()) await file.delete();
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final cancel in _downloads) {
      cancel.cancel();
    }
    await Future.wait(_files.toList().map(_delete));
  }
}
