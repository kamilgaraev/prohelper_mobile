import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rustore_push/flutter_rustore_push.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'push_device_operation_queue.dart';
import 'push_device_registration.dart';
import 'push_message.dart';

final mobilePushServiceProvider = Provider<MobilePushService>((ref) {
  return MobilePushService(
    ref.read(dioProvider),
    ref.read(secureStorageProvider),
  );
});

class MobilePushService {
  MobilePushService(this._dio, this._storage);

  final Dio _dio;
  final SecureStorageService _storage;
  final _foregroundMessages = StreamController<PushMessage>.broadcast();
  final _openedMessages = StreamController<PushMessage>.broadcast();
  final _deviceOperations = PushDeviceOperationQueue();
  static const _permissionChannel = MethodChannel('most.android.push');

  bool _started = false;
  bool _authenticated = false;
  Future<void>? _starting;
  int _registrationAttempt = 0;
  String? _registeredToken;
  Stream<PushMessage> get foregroundMessages => _foregroundMessages.stream;
  Stream<PushMessage> get openedMessages => _openedMessages.stream;

  static Future<bool> initialize() async =>
      defaultTargetPlatform == TargetPlatform.android;

  Future<void> start({required bool pushReady}) {
    if (!pushReady ||
        _started ||
        defaultTargetPlatform != TargetPlatform.android) {
      return Future<void>.value();
    }
    final starting = _starting;
    if (starting != null) return starting;
    final future = _start();
    _starting = future;
    return future.whenComplete(() {
      if (identical(_starting, future)) _starting = null;
    });
  }

  Future<void> _start() async {
    try {
      await RustorePushClient.attachCallbacks(
        onMessageReceived: (dynamic message) {
          if (message != null) _foregroundMessages.add(_fromRustore(message));
        },
        onMessageOpenedApp: (dynamic message) {
          if (message != null) _openedMessages.add(_fromRustore(message));
        },
        onNewToken: (dynamic token) {
          _registeredToken = null;
          if (_authenticated) unawaited(_registerCurrentDevice());
        },
      );
      _started = true;
    } catch (error) {
      _log('RuStore push initialization failed', error);
      return;
    }
    try {
      final initial = await RustorePushClient.getInitialMessage();
      if (initial != null) _openedMessages.add(_fromRustore(initial));
    } catch (error) {
      _log('RuStore initial message unavailable', error);
    }
    if (_authenticated) await _registerCurrentDevice();
  }

  PushMessage _fromRustore(dynamic message) => PushMessage.fromData(
    messageId: message.messageId?.toString(),
    rawData: message.data,
  );

  Future<void> setAuthenticated(bool authenticated) async {
    final generation = _deviceOperations.setAuthenticated(authenticated);
    _authenticated = authenticated;
    _registrationAttempt++;
    if (authenticated) {
      await _registerCurrentDevice();
      return;
    }
    _registeredToken = null;
    await _unregisterDevice(generation: generation);
    try {
      await RustorePushClient.deleteToken();
    } catch (error) {
      _log('RuStore token removal failed', error);
    }
  }

  Future<void> _registerCurrentDevice() async {
    if (!_started || !_authenticated) return;
    final generation = _deviceOperations.generation;
    final attempt = ++_registrationAttempt;
    try {
      final granted = await _permissionChannel.invokeMethod<bool>(
        'requestPermission',
      );
      if (attempt != _registrationAttempt) return;
      if (granted != true || !await RustorePushClient.available()) {
        _registeredToken = null;
        await _unregisterDevice(generation: generation);
        return;
      }
      if (attempt != _registrationAttempt) {
        return;
      }
      final token = await RustorePushClient.getToken();
      if (token.isEmpty || attempt != _registrationAttempt) return;
      final installationId = await _installationId();
      if (attempt != _registrationAttempt ||
          !_deviceOperations.isCurrent(generation)) {
        return;
      }
      await _deviceOperations.enqueue(() async {
        if (!_deviceOperations.isCurrent(generation)) return;
        if (_registeredToken == token) return;
        final registration = PushDeviceRegistration(
          installationId: installationId,
          platform: 'android',
          provider: 'rustore',
          token: token,
        );
        await _dio.post('/notifications/devices', data: registration.toJson());
        if (_deviceOperations.isCurrent(generation)) _registeredToken = token;
      });
    } catch (error) {
      _log('Mobile push registration failed', error);
    }
  }

  Future<void> _unregisterDevice({required int generation}) async {
    await _deviceOperations.enqueue(() async {
      if (!_deviceOperations.isGenerationCurrent(generation)) return;
      try {
        final installationId = await _storage.getPushInstallationId();
        if (!_deviceOperations.isGenerationCurrent(generation) ||
            installationId == null ||
            installationId.isEmpty) {
          return;
        }
        await _dio.delete(
          '/notifications/devices/${Uri.encodeComponent(installationId)}',
        );
      } catch (error) {
        _log('Mobile push deregistration failed', error);
      }
    });
  }

  Future<String> _installationId() async {
    final existing = await _storage.getPushInstallationId();
    if (existing != null && existing.isNotEmpty) return existing;
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await _storage.savePushInstallationId(id);
    return id;
  }

  void _log(String message, Object error) {
    if (kDebugMode) debugPrint('$message: ${error.runtimeType}');
  }

  Future<void> dispose() async {
    await _foregroundMessages.close();
    await _openedMessages.close();
  }
}
