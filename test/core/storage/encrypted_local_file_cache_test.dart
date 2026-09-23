import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/storage/encrypted_local_file_cache.dart';

void main() {
  late Directory directory;
  late _MemoryKeyStore keyStore;
  late EncryptedLocalFileCache cache;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('most-file-cache-test-');
    keyStore = _MemoryKeyStore();
    cache = EncryptedLocalFileCache(
      keyStore: keyStore,
      directoryProvider: () async => directory,
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('encrypts and restores multiple authenticated chunks', () async {
    final content = List<int>.generate(200000, (index) => index % 251);
    final source = File('${directory.path}${Platform.pathSeparator}source.pdf');
    await source.writeAsBytes(content);

    final encryptedPath = await cache.saveForOffline(
      ownerIdentity: '27:4:session-a',
      documentId: 8,
      versionId: 9,
      sourcePath: source.path,
    );
    final encryptedBytes = await File(encryptedPath).readAsBytes();
    expect(encryptedBytes, isNot(equals(content)));

    final restoredPath = await cache.materialize(
      ownerIdentity: '27:4:session-a',
      encryptedPath: encryptedPath,
      context: 'document:8:9',
      fileName: 'agreement.pdf',
    );
    expect(await File(restoredPath).readAsBytes(), content);
    expect(restoredPath, endsWith('.pdf'));
  });

  test('rejects ciphertext tampering and removes partial plaintext', () async {
    final source = File('${directory.path}${Platform.pathSeparator}source.bin');
    await source.writeAsBytes(
      List<int>.generate(90000, (index) => index % 239),
    );
    final encryptedPath = await cache.saveForOffline(
      ownerIdentity: '27:4:session-a',
      documentId: 8,
      versionId: 9,
      sourcePath: source.path,
    );
    final encryptedFile = File(encryptedPath);
    final bytes = await encryptedFile.readAsBytes();
    bytes[55] ^= 1;
    await encryptedFile.writeAsBytes(bytes);

    await expectLater(
      cache.materialize(
        ownerIdentity: '27:4:session-a',
        encryptedPath: encryptedPath,
        context: 'document:8:9',
      ),
      throwsA(anything),
    );
    expect(
      directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.contains('most-open-')),
      isEmpty,
    );
  });

  test(
    'uses a different key for each owner identity and can purge it',
    () async {
      final source = File(
        '${directory.path}${Platform.pathSeparator}source.bin',
      );
      await source.writeAsBytes([1, 2, 3]);
      final encryptedPath = await cache.saveForOffline(
        ownerIdentity: '27:4:session-a',
        documentId: 8,
        versionId: 9,
        sourcePath: source.path,
      );

      await expectLater(
        cache.materialize(
          ownerIdentity: '27:4:session-b',
          encryptedPath: encryptedPath,
          context: 'document:8:9',
        ),
        throwsA(anything),
      );
      await cache.clearIdentity('27:4:session-a');
      expect(keyStore.values, hasLength(1));
      expect(await File(encryptedPath).exists(), isFalse);
    },
  );

  test(
    'clears leftover decrypted temporary files at startup cleanup',
    () async {
      final leftover = File(
        '${directory.path}${Platform.pathSeparator}most-open-stale.pdf',
      );
      final unrelated = File(
        '${directory.path}${Platform.pathSeparator}unrelated.tmp',
      );
      final partialDownload = File(
        '${directory.path}${Platform.pathSeparator}most-download-stale.pdf',
      );
      await leftover.writeAsBytes([1, 2, 3]);
      await unrelated.writeAsBytes([4, 5, 6]);
      await partialDownload.writeAsBytes([7, 8, 9]);

      await cache.clearTemporaryPlaintext();

      expect(await leftover.exists(), isFalse);
      expect(await partialDownload.exists(), isFalse);
      expect(await unrelated.exists(), isTrue);
    },
  );
}

class _MemoryKeyStore implements SecureFileKeyStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
