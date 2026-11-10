import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/storage/secure_storage_service.dart';

final quickUnlockServiceProvider = Provider<QuickUnlockService>(
  (ref) => QuickUnlockService(ref.read(secureStorageProvider)),
);

enum PinCheckStatus { success, wrong, exhausted, notConfigured }

class PinCheck {
  const PinCheck(this.status, {this.remainingAttempts = 0});

  final PinCheckStatus status;
  final int remainingAttempts;
}

class QuickUnlockService {
  QuickUnlockService(this._storage, {int iterations = 60000, Random? random})
    : _iterations = iterations,
      _random = random ?? Random.secure();

  static const pinLength = 4;
  static const maxAttempts = 5;

  final SecureStorageService _storage;
  final int _iterations;
  final Random _random;

  static bool isValidPin(String pin) =>
      pin.length == pinLength && RegExp(r'^\d+$').hasMatch(pin);

  Future<bool> isConfiguredFor(int userId) async =>
      _recordFor(await _storage.getQuickUnlock(), userId) != null;

  Future<bool> biometricEnabledFor(int userId) async {
    final record = _recordFor(await _storage.getQuickUnlock(), userId);
    return record?['biometric'] == true;
  }

  Future<void> setPin(int userId, String pin) async {
    if (!isValidPin(pin)) {
      throw ArgumentError.value(pin, 'pin', 'PIN must be $pinLength digits');
    }
    final salt = List<int>.generate(16, (_) => _random.nextInt(256));
    final hash = await _derive(pin, salt, _iterations);
    await _storage.saveQuickUnlock({
      'user_id': userId,
      'salt': base64Encode(salt),
      'hash': base64Encode(hash),
      'iterations': _iterations,
      'failed': 0,
      'biometric': false,
    });
  }

  Future<void> setBiometricEnabled(int userId, bool enabled) async {
    final record = _recordFor(await _storage.getQuickUnlock(), userId);
    if (record == null) return;
    await _storage.saveQuickUnlock({...record, 'biometric': enabled});
  }

  Future<PinCheck> verify(int userId, String pin) async {
    final record = _recordFor(await _storage.getQuickUnlock(), userId);
    if (record == null) return const PinCheck(PinCheckStatus.notConfigured);
    final failed = (record['failed'] as int?) ?? 0;
    if (failed >= maxAttempts) {
      await _storage.clearQuickUnlock();
      return const PinCheck(PinCheckStatus.exhausted);
    }
    await _storage.saveQuickUnlock({...record, 'failed': failed + 1});

    final salt = base64Decode(record['salt'] as String);
    final expected = base64Decode(record['hash'] as String);
    final iterations = (record['iterations'] as int?) ?? _iterations;
    final actual =
        isValidPin(pin) ? await _derive(pin, salt, iterations) : const <int>[];

    if (_constantTimeEquals(actual, expected)) {
      await _storage.saveQuickUnlock({...record, 'failed': 0});
      return const PinCheck(PinCheckStatus.success);
    }

    final remaining = maxAttempts - (failed + 1);
    if (remaining <= 0) {
      await _storage.clearQuickUnlock();
      return const PinCheck(PinCheckStatus.exhausted);
    }
    return PinCheck(PinCheckStatus.wrong, remainingAttempts: remaining);
  }

  Future<void> clear() => _storage.clearQuickUnlock();

  Future<bool> wasOffered(int userId) => _storage.wasQuickUnlockOffered(userId);

  Future<void> markOffered(int userId) =>
      _storage.markQuickUnlockOffered(userId);

  Map<String, dynamic>? _recordFor(Map<String, dynamic>? record, int userId) {
    if (record == null || record['user_id'] != userId) return null;
    if (record['salt'] is! String || record['hash'] is! String) return null;
    return record;
  }

  Future<List<int>> _derive(String pin, List<int> salt, int iterations) async {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final key = await algorithm.deriveKeyFromPassword(
      password: pin,
      nonce: salt,
    );
    return key.extractBytes();
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length || a.isEmpty) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
