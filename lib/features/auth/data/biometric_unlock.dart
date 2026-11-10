import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final biometricUnlockProvider = Provider<BiometricUnlock>(
  (ref) =>
      Platform.isAndroid
          ? const AndroidBiometricUnlock()
          : const UnavailableBiometricUnlock(),
);

enum BiometricAvailability { available, notEnrolled, unavailable }

enum BiometricResult {
  success,
  cancelled,
  invalidated,
  lockedOut,
  unavailable,
  failed,
}

class BiometricPromptText {
  const BiometricPromptText({
    required this.title,
    required this.subtitle,
    required this.cancel,
  });

  final String title;
  final String subtitle;
  final String cancel;

  Map<String, String> toMap() => {
    'title': title,
    'subtitle': subtitle,
    'cancel': cancel,
  };
}

abstract class BiometricUnlock {
  Future<BiometricAvailability> availability();

  Future<BiometricResult> enable(BiometricPromptText text);

  Future<BiometricResult> authenticate(BiometricPromptText text);

  Future<void> disable();
}

class UnavailableBiometricUnlock implements BiometricUnlock {
  const UnavailableBiometricUnlock();

  @override
  Future<BiometricAvailability> availability() async =>
      BiometricAvailability.unavailable;

  @override
  Future<BiometricResult> enable(BiometricPromptText text) async =>
      BiometricResult.unavailable;

  @override
  Future<BiometricResult> authenticate(BiometricPromptText text) async =>
      BiometricResult.unavailable;

  @override
  Future<void> disable() async {}
}

class AndroidBiometricUnlock implements BiometricUnlock {
  const AndroidBiometricUnlock();

  static const _channel = MethodChannel('most.android.biometric');

  @override
  Future<BiometricAvailability> availability() async {
    try {
      final value = await _channel.invokeMethod<String>('availability');
      return switch (value) {
        'available' => BiometricAvailability.available,
        'not_enrolled' => BiometricAvailability.notEnrolled,
        _ => BiometricAvailability.unavailable,
      };
    } catch (_) {
      return BiometricAvailability.unavailable;
    }
  }

  @override
  Future<BiometricResult> enable(BiometricPromptText text) =>
      _invoke('enable', text);

  @override
  Future<BiometricResult> authenticate(BiometricPromptText text) =>
      _invoke('authenticate', text);

  @override
  Future<void> disable() async {
    try {
      await _channel.invokeMethod<void>('disable');
    } catch (_) {}
  }

  Future<BiometricResult> _invoke(
    String method,
    BiometricPromptText text,
  ) async {
    try {
      final value = await _channel.invokeMethod<String>(method, text.toMap());
      return parseBiometricResult(value);
    } catch (_) {
      return BiometricResult.failed;
    }
  }
}

BiometricResult parseBiometricResult(String? value) => switch (value) {
  'success' => BiometricResult.success,
  'cancelled' => BiometricResult.cancelled,
  'invalidated' => BiometricResult.invalidated,
  'locked_out' => BiometricResult.lockedOut,
  'unavailable' => BiometricResult.unavailable,
  _ => BiometricResult.failed,
};
