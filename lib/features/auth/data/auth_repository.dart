import 'dart:developer';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(dioProvider),
    ref.read(secureStorageProvider),
  );
});

class AuthRepository {
  final Dio _dio;
  final SecureStorageService _storage;

  AuthRepository(this._dio, this._storage);

  Future<User> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final data = response.data['data'];
      final token = data['token'];

      await _storage.saveToken(token);
      
      // Login response has limited user data (no orgs, no permissions).
      // We must fetch full profile immediately.
      return await getMe();
    } catch (e) {
      throw e;
    }
  }

  Future<User> switchOrganization(int organizationId) async {
    try {
      final response = await _dio.post('/auth/switch-organization', data: {
        'organization_id': organizationId,
      });

      final data = response.data['data'];
      final token = data['token'];
      
      if (token != null) {
        await _storage.saveToken(token);
      }

      // Reload profile with new context
      return await getMe();
    } catch (e) {
      throw e;
    }
  }

  Future<User> getMe() async {
    try {
      final response = await _dio.get('/auth/me');
      log('GET /auth/me payload: ${jsonEncode(response.data)}');
      return _mapJsonToUser(response.data['data']);
    } catch (e) {
      throw e;
    }
  }

  User _mapJsonToUser(Map<String, dynamic> json) {
    // API Response Structure (Final):
    // {
    //   "id": 45,
    //   "auth": { "roles": [...], "role_labels": ["Владелец..."] },
    //   "organizations": [...],
    //   "current_organization_id": 39
    // }

    // Parse organizations
    final organizations = (json['organizations'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ?? [];

    final currentOrgId = json['current_organization_id'] as int?;

    final authData = json['auth'] as Map<String, dynamic>?;
    final List<String> roles = [];
    if (authData != null && authData['roles'] != null) {
      roles.addAll(List<String>.from(authData['roles']));
    } else if (authData != null && authData['role_labels'] != null) {
      roles.addAll(List<String>.from(authData['role_labels']));
    }

    // Find organization name
    String? orgName;
    if (currentOrgId != null) {
      final currentOrg = organizations.firstWhere(
        (org) => org['id'] == currentOrgId,
        orElse: () => {},
      );
      orgName = currentOrg['name'] as String?;
    }
    
    // Fallback to first active if name not found
    if (orgName == null && organizations.isNotEmpty) {
       final activeOrg = organizations.firstWhere(
        (org) => org['is_active'] == true,
        orElse: () => {},
      );
      orgName = activeOrg['name'] as String?;
    }

    return User()
      ..serverId = json['id'] ?? 0
      ..email = json['email'] ?? ''
      ..name = json['name'] ?? 'User'
      // Prefer full URL, fallback to path if needed (though URL is signed and better)
      ..avatarUrl = json['avatar_url'] ?? json['avatar_path']
      ..roles = roles
      ..currentOrganizationId = currentOrgId
      ..organizationName = orgName
      ..organizationsJson = jsonEncode(organizations)
      ..permissionsJson = jsonEncode(authData != null ? authData['modules'] ?? {} : {});
  }

  Future<void> logout() async {
    await _storage.clearToken();
  }
}
