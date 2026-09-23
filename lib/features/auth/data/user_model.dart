import 'dart:convert';

import 'package:isar/isar.dart';

part 'user_model.g.dart';

@collection
class User {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late int serverId;

  late String email;
  late String name;
  String? avatarUrl;

  int? currentOrganizationId;
  String? organizationName;
  late String organizationsJson;

  @ignore
  List<Map<String, dynamic>> get organizations {
    try {
      if (organizationsJson.isEmpty) {
        return [];
      }

      final list = jsonDecode(organizationsJson) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  late List<String> roles;
  late String permissionsJson;

  @ignore
  Set<String> get grantedPermissions {
    try {
      final decoded = jsonDecode(permissionsJson);
      if (decoded is! Map) {
        return const <String>{};
      }

      final permissions = <String>{};
      for (final entry in decoded.entries) {
        final module = entry.key.toString();
        final values = entry.value;
        if (values is! List) {
          continue;
        }
        for (final value in values.whereType<String>()) {
          if (value == '*') {
            permissions.add('$module.*');
          } else if (value.contains('.')) {
            permissions.add(value);
          } else {
            permissions.add('$module.$value');
          }
        }
      }
      return permissions;
    } catch (_) {
      return const <String>{};
    }
  }

  @ignore
  List<String> get displayRoles {
    return roles.map(_humanizeRole).toList();
  }

  String _humanizeRole(String role) {
    return switch (role) {
      'organization_owner' => 'Владелец',
      'organization_admin' => 'Администратор',
      'foreman' => 'Участник',
      'worker' => 'Рабочий',
      'observer' => 'Наблюдатель',
      _ => role
          .split('_')
          .where((part) => part.isNotEmpty)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' '),
    };
  }
}
