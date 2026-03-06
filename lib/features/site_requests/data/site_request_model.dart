import 'package:isar/isar.dart';

// part 'site_request_model.g.dart'; // Disabled generation

// @collection // Disabled Isar collection for immediate build fix
class SiteRequestModel {
  Id id = Isar.autoIncrement;

  // @Index(unique: true, replace: true)
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
  
  // Дополнительные поля (Персонал, Техника)
  String? personnelType;
  String? personnelTypeLabel;
  int? personnelCount;
  String? equipmentType;
  String? equipmentTypeLabel;
  String? workStartDate;
  String? workEndDate;
  String? rentalStartDate;
  String? rentalEndDate;

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
      ..personnelType = json['personnel_type']
      ..personnelTypeLabel = json['personnel_type_label']
      ..personnelCount = json['personnel_count']
      ..equipmentType = json['equipment_type']
      ..equipmentTypeLabel = json['equipment_type_label']
      ..workStartDate = json['work_start_date']
      ..workEndDate = json['work_end_date']
      ..rentalStartDate = json['rental_start_date']
      ..rentalEndDate = json['rental_end_date']
      ..projectId = json['project_id']
      ..projectName = json['project'] != null ? json['project']['name'] : null
      ..createdAt = json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null;
  }
}
