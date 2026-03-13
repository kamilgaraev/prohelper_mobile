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
  late String organizationsJson; // Stored as JSON string list of objects
  
  @ignore
  List<Map<String, dynamic>> get organizations {
    try {
      if (organizationsJson.isEmpty) return [];
      final List<dynamic> list = jsonDecode(organizationsJson);
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  late List<String> roles;
  
  late String permissionsJson; 

  @ignore
  List<String> get displayRoles {
    return roles.map(_humanizeRole).toList();
  }

  String _humanizeRole(String role) {
    return switch (role) {
      'organization_owner' => 'Владелец',
      'organization_admin' => 'Администратор',
      'foreman' => 'Прораб',
      'worker' => 'Рабочий',
      _ => role
          .split('_')
          .where((part) => part.isNotEmpty)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' '),
    };
  }
}
