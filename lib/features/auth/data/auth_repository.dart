import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
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
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final SecureStorageService _storage;

  Future<User> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final data = response.data['data'];
      final token = data['token'];

      await _storage.saveToken(token);

      return await getMe();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось выполнить вход.',
      );
    } catch (_) {
      throw const ApiException('Не удалось выполнить вход.');
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

      return await getMe();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось переключить организацию.',
      );
    } catch (_) {
      throw const ApiException('Не удалось переключить организацию.');
    }
  }

  Future<User> getMe() async {
    try {
      final response = await _dio.get('/auth/me');
      log('GET /auth/me payload: ${jsonEncode(response.data)}');
      return _mapJsonToUser(response.data['data']);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить профиль пользователя.',
      );
    } catch (_) {
      throw const ApiException('Не удалось загрузить профиль пользователя.');
    }
  }

  User _mapJsonToUser(Map<String, dynamic> json) {
    final organizations = (json['organizations'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];

    final currentOrgId = json['current_organization_id'] as int?;
    final authData = json['auth'] as Map<String, dynamic>?;
    final roles = <String>[];

    if (authData != null && authData['roles'] != null) {
      roles.addAll(List<String>.from(authData['roles']));
    } else if (authData != null && authData['role_labels'] != null) {
      roles.addAll(List<String>.from(authData['role_labels']));
    }

    String? orgName;
    if (currentOrgId != null) {
      final currentOrg = organizations.firstWhere(
        (org) => org['id'] == currentOrgId,
        orElse: () => {},
      );
      orgName = currentOrg['name'] as String?;
    }

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
      ..avatarUrl = json['avatar_url'] ?? json['avatar_path']
      ..roles = roles
      ..currentOrganizationId = currentOrgId
      ..organizationName = orgName
      ..organizationsJson = jsonEncode(organizations)
      ..permissionsJson = jsonEncode(
        authData != null ? authData['modules'] ?? {} : {},
      );
  }

  Future<void> logout() async {
    await _storage.clearToken();
  }
}
