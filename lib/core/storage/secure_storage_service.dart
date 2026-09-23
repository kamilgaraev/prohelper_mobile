import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:convert';
import 'dart:math';

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _selectedProjectIdKey = 'selected_project_id';
  static const _pinnedMobileActionsKey = 'pinned_mobile_action_ids';
  static const _offlineAuthKey = 'offline_auth_session';
  static const _offlineSessionIdKey = 'offline_session_id';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await clearOfflineAuth();
  }

  Future<String> ensureSessionId() async {
    final current = await _storage.read(key: _offlineSessionIdKey);
    if (current != null && current.isNotEmpty) return current;
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final value = base64UrlEncode(bytes);
    await _storage.write(key: _offlineSessionIdKey, value: value);
    return value;
  }

  Future<void> saveOfflineAuth(Map<String, dynamic> value) async {
    await _storage.write(key: _offlineAuthKey, value: jsonEncode(value));
  }

  Future<Map<String, dynamic>?> getOfflineAuth() async {
    final value = await _storage.read(key: _offlineAuthKey);
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearOfflineAuth() async {
    await _storage.delete(key: _offlineAuthKey);
    await _storage.delete(key: _offlineSessionIdKey);
  }

  Future<void> rebindOfflineAuthToken(String token) async {
    final record = await getOfflineAuth();
    if (record == null) return;
    record['token'] = token;
    await saveOfflineAuth(record);
  }

  Future<void> saveSelectedProjectId(int projectId) async {
    await _storage.write(
      key: _selectedProjectIdKey,
      value: projectId.toString(),
    );
  }

  Future<int?> getSelectedProjectId() async {
    final value = await _storage.read(key: _selectedProjectIdKey);
    return int.tryParse(value ?? '');
  }

  Future<void> clearSelectedProjectId() async {
    await _storage.delete(key: _selectedProjectIdKey);
  }

  Future<List<String>> getPinnedMobileActionIds() async {
    final value = await _storage.read(key: _pinnedMobileActionsKey);
    if (value == null || value.trim().isEmpty) {
      return const [];
    }

    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(2)
        .toList(growable: false);
  }

  Future<void> savePinnedMobileActionIds(List<String> actionIds) async {
    final normalized = actionIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(2)
        .join(',');

    await _storage.write(key: _pinnedMobileActionsKey, value: normalized);
  }
}
