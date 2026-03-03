import 'package:isar/isar.dart';

part 'project_model.g.dart';

@collection
class Project {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late int serverId;

  late String name;
  String? address;
  String? myRole;

  Project();

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project()
      ..serverId = json['id']
      ..name = json['name']
      ..address = json['address']
      ..myRole = json['my_role'];
  }
}
