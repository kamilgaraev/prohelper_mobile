class PaymentDocumentModel {
  const PaymentDocumentModel({required this.id, required this.values});

  final int id;
  final Map<String, dynamic> values;

  bool get canEdit => values['can_edit'] == true;
  bool get canSubmit => values['can_submit'] == true;
  bool get canRegisterPayment => values['can_register_payment'] == true;
  bool get canApprove => values['can_approve'] == true;
  bool get canReject => values['can_reject'] == true;

  String get title =>
      _text(values['document_number']).isNotEmpty
          ? _text(values['document_number'])
          : _text(values['payment_purpose']).isNotEmpty
          ? _text(values['payment_purpose'])
          : 'Документ №$id';

  String get status =>
      _text(values['status_label']).isNotEmpty
          ? _text(values['status_label'])
          : _text(values['status']).isNotEmpty
          ? _text(values['status'])
          : 'Без статуса';

  String get amount => _text(values['amount']);

  factory PaymentDocumentModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse('$rawId');
    if (id == null || id <= 0) {
      throw const FormatException('Некорректный ID финансового документа');
    }
    return PaymentDocumentModel(id: id, values: Map.unmodifiable(json));
  }
}

String _text(dynamic value) => value?.toString().trim() ?? '';
