import 'package:isar/isar.dart';

part 'site_request_model.g.dart';

@collection
class SiteRequestModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late int serverId;

  late String title;
  String? description;
  late String status;
  String? statusLabel;
  String? statusColor;
  late String priority;
  String? priorityLabel;
  String? priorityColor;
  late String requestType;
  String? requestTypeLabel;
  
  String? requiredDate;
  
  // Материалы (основной кейс для прораба)
  String? materialName;
  double? materialQuantity;
  String? materialUnit;

  // Проект
  int? projectId;
  String? projectName;

  DateTime? createdAt;

  SiteRequestModel();

  factory SiteRequestModel.fromJson(Map<String, dynamic> json) {
    return SiteRequestModel()
      ..serverId = json['id']
      ..title = json['title'] ?? ''
      ..description = json['description']
      ..status = json['status'] ?? 'draft'
      ..statusLabel = json['status_label']
      ..statusColor = json['status_color']
      ..priority = json['priority'] ?? 'normal'
      ..priorityLabel = json['priority_label']
      ..priorityColor = json['priority_color']
      ..requestType = json['request_type'] ?? 'material'
      ..requestTypeLabel = json['request_type_label']
      ..requiredDate = json['required_date']
      ..materialName = json['material_name']
      ..materialQuantity = json['material_quantity'] != null 
          ? double.tryParse(json['material_quantity'].toString()) 
          : null
      ..materialUnit = json['material_unit']
      ..projectId = json['project_id']
      ..projectName = json['project'] != null ? json['project']['name'] : null
      ..createdAt = json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null;
  }
}
