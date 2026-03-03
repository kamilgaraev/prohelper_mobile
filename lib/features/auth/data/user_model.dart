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
  
  // Permissions are stored as JSON strings for simplicity in this iteration
  // Key: Module Slug, Value: List of permissions
  late String permissionsJson; 
}
