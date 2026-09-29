import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';

final designPackageFileServiceProvider = Provider<DesignPackageFileService>(
  (ref) => DesignPackageFileService(),
);

class DesignPackageFileService {
  DesignPackageFileService({
    Dio? client,
    Future<Directory> Function()? temporaryDirectory,
    Future<bool> Function(Uri uri)? launchPreview,
    Future<bool> Function(String path)? openLocalFile,
  }) : _client = client,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _launchPreview =
           launchPreview ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)),
       _openLocalFile =
           openLocalFile ??
           ((path) async =>
               (await OpenFilex.open(path)).type == ResultType.done);

  final Dio? _client;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<bool> Function(Uri uri) _launchPreview;
  final Future<bool> Function(String path) _openLocalFile;
  final Set<String> _downloadDirectories = {};

  Future<bool> openPreview(Uri uri) => _launchPreview(uri);

  Future<String> download(Uri uri, String fileName) async {
    final root = await _temporaryDirectory();
    final directory = await root.createTemp('most-pir-');
    _downloadDirectories.add(directory.path);
    final path =
        '${directory.path}${Platform.pathSeparator}${_safeName(fileName)}';
    final client =
        _client ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(minutes: 2),
            headers: const {'Accept': '*/*'},
          ),
        );
    try {
      await client.download(uri.toString(), path);
      return path;
    } on DioException catch (error) {
      await deleteDownloaded(path);
      throw ApiException.fromDio(error);
    } catch (_) {
      await deleteDownloaded(path);
      rethrow;
    } finally {
      if (_client == null) client.close(force: true);
    }
  }

  Future<bool> openLocalFile(String path) => _openLocalFile(path);

  Future<void> deleteDownloaded(String path) async {
    final file = File(path);
    final parent = file.parent;
    if (!_downloadDirectories.contains(parent.path)) return;
    if (await parent.exists()) await parent.delete(recursive: true);
    _downloadDirectories.remove(parent.path);
  }

  void scheduleCleanup(String path) {
    Future<void>.delayed(const Duration(minutes: 2), () async {
      try {
        await deleteDownloaded(path);
      } catch (_) {}
    });
  }

  String _safeName(String fileName) {
    final leaf = fileName.split(RegExp(r'[/\\]')).last.trim();
    final safe = leaf.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (safe.isEmpty || safe == '.' || safe == '..') return 'file';
    return safe;
  }
}
