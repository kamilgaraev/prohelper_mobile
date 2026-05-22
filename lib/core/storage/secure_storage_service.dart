import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _selectedProjectIdKey = 'selected_project_id';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
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
}
