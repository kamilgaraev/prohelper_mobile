import 'dart:math';

String newIncomingControlOperationKey() =>
    List.generate(
      32,
      (_) => Random.secure().nextInt(16).toRadixString(16),
    ).join();

Map<String, dynamic> incomingMap(dynamic value) =>
    value is Map
        ? value.map((key, item) => MapEntry(key.toString(), item))
        : const {};

List<Map<String, dynamic>> incomingMaps(dynamic value) =>
    value is List
        ? value.whereType<Map>().map(incomingMap).toList(growable: false)
        : const [];

double incomingQuantity(dynamic value) =>
    double.tryParse(value?.toString() ?? '') ?? 0;

class IncomingControlModel {
  IncomingControlModel.fromJson(Map<String, dynamic> json)
    : data = Map.unmodifiable(json),
      id = int.parse(json['id'].toString()),
      projectId = int.parse(json['project_id'].toString()),
      version = int.parse(json['version'].toString());

  final Map<String, dynamic> data;
  final int id;
  final int projectId;
  final int version;

  String get number => data['number']?.toString() ?? '#$id';
  String get materialName =>
      incomingMap(data['material'])['name']?.toString() ?? 'Материал';
  String get status => data['status']?.toString() ?? 'draft';
  String get statusLabel => incomingControlStatusLabel(status);
  String? text(String field) => data[field]?.toString();
  double quantity(String field) => incomingQuantity(data[field]);
  List<String> get availableActions =>
      (data['available_actions'] as List? ?? [])
          .map((item) => item.toString())
          .toList(growable: false);
  List<Map<String, dynamic>> get documents =>
      incomingMaps(data['quality_document_versions']);
  List<Map<String, dynamic>> get attachments =>
      incomingMaps(data['attachments']);
  List<Map<String, dynamic>> get history => incomingMaps(data['history']);
}

String incomingControlStatusLabel(String status) => switch (status) {
  'draft' => 'Черновик',
  'pending' => 'Ожидает решения',
  'accepted' => 'Принято',
  'accepted_with_restrictions' => 'Принято с ограничениями',
  'rejected' => 'Отклонено',
  'revoked' => 'Решение отозвано',
  _ => 'Статус уточняется',
};

class IncomingControlPage {
  const IncomingControlPage(
    this.items, {
    required this.page,
    required this.lastPage,
  });
  final List<IncomingControlModel> items;
  final int page;
  final int lastPage;
}

class IncomingControlReferences {
  const IncomingControlReferences(this.data);
  final Map<String, dynamic> data;
  List<Map<String, dynamic>> get materials => incomingMaps(data['materials']);
  List<Map<String, dynamic>> get qualityDocuments =>
      incomingMaps(data['quality_documents']);
  List<Map<String, dynamic>> get warehouses => incomingMaps(data['warehouses']);
  Map<String, dynamic> get policy => incomingMap(data['policy']);
  bool get enabled => policy['enabled'] == true;
  bool can(String action) {
    final permissions = data['permissions'];
    if (permissions is Map) {
      return permissions[action] == true || permissions['can_$action'] == true;
    }
    if (permissions is List) {
      return permissions.contains(action) ||
          permissions.contains('quality-control.incoming-controls.$action');
    }
    return false;
  }
}

class IncomingControlQuantities {
  const IncomingControlQuantities({
    required this.document,
    required this.presented,
    required this.accepted,
    required this.pending,
    required this.rejected,
  });
  final double document;
  final double presented;
  final double accepted;
  final double pending;
  final double rejected;

  String? get validationError {
    final values = [document, presented, accepted, pending, rejected];
    if (values.any((value) => !value.isFinite || value < 0) || presented <= 0) {
      return 'Укажите положительное предъявленное количество и неотрицательные остальные количества.';
    }
    if ((accepted + pending + rejected - presented).abs() > 0.000001) {
      return 'Принято, ожидает и отклонено должны вместе равняться предъявленному количеству.';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'document_quantity': document,
    'presented_quantity': presented,
    'accepted_quantity': accepted,
    'pending_quantity': pending,
    'rejected_quantity': rejected,
  };
}
