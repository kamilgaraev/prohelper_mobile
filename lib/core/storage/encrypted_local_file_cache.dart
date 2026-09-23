import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

final encryptedLocalFileCacheProvider = Provider<EncryptedLocalFileCache>(
  (ref) => EncryptedLocalFileCache(),
);

abstract interface class SecureFileKeyStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class _FlutterSecureFileKeyStore implements SecureFileKeyStore {
  _FlutterSecureFileKeyStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class EncryptedLocalFileCache {
  EncryptedLocalFileCache({
    FlutterSecureStorage? secureStorage,
    SecureFileKeyStore? keyStore,
    Future<Directory> Function()? directoryProvider,
    Future<Directory> Function()? temporaryDirectoryProvider,
    AesGcm? cipher,
  }) : _keyStore =
           keyStore ??
           _FlutterSecureFileKeyStore(
             secureStorage ?? const FlutterSecureStorage(),
           ),
       _directoryProvider = directoryProvider ?? getApplicationSupportDirectory,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ??
           directoryProvider ??
           getTemporaryDirectory,
       _cipher = cipher ?? AesGcm.with256bits();

  static const _chunkSize = 64 * 1024;
  static const _metadataSize = 12;
  static const _magic = [0x4d, 0x4f, 0x53, 0x54, 0x45, 0x4e, 0x43, 0x31];

  final SecureFileKeyStore _keyStore;
  final Future<Directory> Function() _directoryProvider;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final AesGcm _cipher;
  final Map<String, Future<List<int>>> _keyFutures = {};

  Future<String> saveForOffline({
    required String ownerIdentity,
    required int documentId,
    required int versionId,
    required String sourcePath,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('Исходный файл недоступен.');
    }
    final target = await _targetFile(
      ownerIdentity,
      'document-$documentId-version-$versionId.enc',
    );
    final temporary = File('${target.path}.tmp');
    await _encryptFile(
      source,
      temporary,
      ownerIdentity: ownerIdentity,
      context: 'document:$documentId:$versionId',
    );
    await _replaceEncryptedFile(temporary, target);
    return target.path;
  }

  Future<String> stageUpload({
    required String ownerIdentity,
    required int signatureRequestId,
    required String idempotencyKey,
    required String sourcePath,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('Исходный файл недоступен.');
    }
    final key = sha256.convert(utf8.encode(idempotencyKey)).toString();
    final target = await _targetFile(
      ownerIdentity,
      'upload-$signatureRequestId-$key.enc',
    );
    final temporary = File('${target.path}.tmp');
    await _encryptFile(
      source,
      temporary,
      ownerIdentity: ownerIdentity,
      context: 'upload:$signatureRequestId:$idempotencyKey',
    );
    await _replaceEncryptedFile(temporary, target);
    return target.path;
  }

  Future<bool> isSaved({
    required String ownerIdentity,
    required int documentId,
    required int versionId,
  }) async {
    final file = await _targetFile(
      ownerIdentity,
      'document-$documentId-version-$versionId.enc',
    );
    return file.exists();
  }

  Future<String> savedPath({
    required String ownerIdentity,
    required int documentId,
    required int versionId,
  }) async {
    return (await _targetFile(
      ownerIdentity,
      'document-$documentId-version-$versionId.enc',
    )).path;
  }

  Future<String> materialize({
    required String ownerIdentity,
    required String encryptedPath,
    required String context,
    String? fileName,
  }) async {
    final encrypted = File(encryptedPath);
    if (!await encrypted.exists()) {
      throw const FileSystemException('Сохранённый файл недоступен.');
    }
    final directory = await _temporaryDirectoryProvider();
    final extension = _extension(fileName);
    final temporary = File(
      '${directory.path}${Platform.pathSeparator}most-open-${_safeName(context)}-${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await _decryptFile(
      encrypted,
      temporary,
      ownerIdentity: ownerIdentity,
      context: context,
    );
    return temporary.path;
  }

  Future<void> clearIdentity(String ownerIdentity) async {
    _keyFutures.remove(_storageKey(ownerIdentity));
    final folder = await _identityDirectory(ownerIdentity);
    if (await folder.exists()) {
      await folder.delete(recursive: true);
    }
    await _keyStore.delete(_storageKey(ownerIdentity));
    await clearTemporaryPlaintext();
  }

  Future<void> clearTemporaryPlaintext() async {
    final directory = await _temporaryDirectoryProvider();
    if (!await directory.exists()) return;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File &&
          (_basename(entity.path).startsWith('most-open-') ||
              _basename(entity.path).startsWith('most-download-'))) {
        await entity.delete();
      }
    }
  }

  Future<void> deleteSavedVersion({
    required String ownerIdentity,
    required int documentId,
    required int versionId,
  }) async {
    final file = await _targetFile(
      ownerIdentity,
      'document-$documentId-version-$versionId.enc',
    );
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteStagedUpload(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _encryptFile(
    File source,
    File destination, {
    required String ownerIdentity,
    required String context,
  }) async {
    final key = await _getKey(ownerIdentity);
    final input = await source.open();
    final output = await destination.open(mode: FileMode.write);
    var outputClosed = false;
    try {
      final length = await input.length();
      await output.writeFrom(_magic);
      final header =
          ByteData(_metadataSize)
            ..setUint32(0, _chunkSize, Endian.big)
            ..setUint32(4, (length >> 32) & 0xffffffff, Endian.big)
            ..setUint32(8, length & 0xffffffff, Endian.big);
      await output.writeFrom(header.buffer.asUint8List());

      var index = 0;
      while (true) {
        final plaintext = await input.read(_chunkSize);
        if (plaintext.isEmpty) break;
        final box = await _cipher.encrypt(
          plaintext,
          secretKey: SecretKey(key),
          nonce: _cipher.newNonce(),
          aad: utf8.encode('$context:$length:$index'),
        );
        final size = ByteData(4)..setUint32(0, plaintext.length, Endian.big);
        await output.writeFrom(size.buffer.asUint8List());
        await output.writeFrom(box.nonce);
        await output.writeFrom(box.cipherText);
        await output.writeFrom(box.mac.bytes);
        index++;
      }
      await output.flush();
    } catch (_) {
      await output.close();
      outputClosed = true;
      if (await destination.exists()) await destination.delete();
      rethrow;
    } finally {
      await input.close();
      if (!outputClosed) await output.close();
    }
  }

  Future<void> _decryptFile(
    File source,
    File destination, {
    required String ownerIdentity,
    required String context,
  }) async {
    final key = await _getKey(ownerIdentity);
    final input = await source.open();
    final output = await destination.open(mode: FileMode.write);
    var outputClosed = false;
    try {
      final magic = await input.read(_magic.length);
      if (!_bytesEqual(magic, _magic)) {
        throw const FormatException('Неверный формат сохранённого файла.');
      }
      final header = await input.read(_metadataSize);
      if (header.length != _metadataSize) {
        throw const FormatException('Сохранённый файл повреждён.');
      }
      final metadata = ByteData.sublistView(Uint8List.fromList(header));
      final chunkSize = metadata.getUint32(0, Endian.big);
      final length =
          (metadata.getUint32(4, Endian.big) << 32) |
          metadata.getUint32(8, Endian.big);
      if (chunkSize != _chunkSize) {
        throw const FormatException('Неподдерживаемый формат файла.');
      }

      var index = 0;
      var written = 0;
      while (written < length) {
        final sizeBytes = await input.read(4);
        if (sizeBytes.length != 4) {
          throw const FormatException('Сохранённый файл повреждён.');
        }
        final size = ByteData.sublistView(
          Uint8List.fromList(sizeBytes),
        ).getUint32(0, Endian.big);
        if (size == 0 || size > _chunkSize || size > length - written) {
          throw const FormatException('Сохранённый файл повреждён.');
        }
        final nonce = await input.read(12);
        final ciphertext = await input.read(size);
        final mac = await input.read(16);
        if (nonce.length != 12 ||
            ciphertext.length != size ||
            mac.length != 16) {
          throw const FormatException('Сохранённый файл повреждён.');
        }
        final plaintext = await _cipher.decrypt(
          SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
          secretKey: SecretKey(key),
          aad: utf8.encode('$context:$length:$index'),
        );
        await output.writeFrom(plaintext);
        written += plaintext.length;
        index++;
      }
      if (await input.position() != await input.length()) {
        throw const FormatException('Сохранённый файл содержит лишние данные.');
      }
      await output.flush();
    } catch (_) {
      await output.close();
      outputClosed = true;
      if (await destination.exists()) await destination.delete();
      rethrow;
    } finally {
      await input.close();
      if (!outputClosed) await output.close();
    }
  }

  Future<List<int>> _getKey(String identity) async {
    final storageKey = _storageKey(identity);
    return _keyFutures.putIfAbsent(storageKey, () async {
      try {
        return await _readOrCreateKey(storageKey);
      } catch (_) {
        _keyFutures.remove(storageKey);
        rethrow;
      }
    });
  }

  Future<List<int>> _readOrCreateKey(String storageKey) async {
    final existing = await _keyStore.read(storageKey);
    if (existing != null) {
      final decoded = base64Url.decode(existing);
      if (decoded.length != 32) {
        throw const FormatException('Ключ сохранённого файла повреждён.');
      }
      return decoded;
    }
    final random = Random.secure();
    final key = List<int>.generate(32, (_) => random.nextInt(256));
    await _keyStore.write(storageKey, base64UrlEncode(key));
    return key;
  }

  Future<void> _replaceEncryptedFile(File temporary, File destination) async {
    final backup = File('${destination.path}.bak');
    final hadDestination = await destination.exists();
    if (hadDestination) await destination.rename(backup.path);
    try {
      await temporary.rename(destination.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (await destination.exists()) await destination.delete();
      if (hadDestination && await backup.exists()) {
        await backup.rename(destination.path);
      }
      rethrow;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  String _storageKey(String identity) =>
      'legal_archive_key_${sha256.convert(utf8.encode(identity))}';

  Future<File> _targetFile(String identity, String filename) async {
    final folder = await _identityDirectory(identity);
    if (!await folder.exists()) await folder.create(recursive: true);
    return File('${folder.path}${Platform.pathSeparator}$filename');
  }

  Future<Directory> _identityDirectory(String identity) async {
    final root = await _directoryProvider();
    final identityHash = sha256.convert(utf8.encode(identity));
    return Directory(
      '${root.path}${Platform.pathSeparator}legal_archive${Platform.pathSeparator}$identityHash',
    );
  }

  String _safeName(String value) =>
      sha256.convert(utf8.encode(value)).toString().substring(0, 20);

  String _basename(String path) => path.replaceAll('\\', '/').split('/').last;

  String _extension(String? fileName) {
    if (fileName == null) return '';
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return '';
    final extension = fileName.substring(dot);
    return RegExp(r'^\.[a-zA-Z0-9]{1,12}$').hasMatch(extension)
        ? extension
        : '';
  }

  bool _bytesEqual(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
