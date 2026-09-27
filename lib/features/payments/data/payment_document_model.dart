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
          ? _statusLabels[_text(values['status'])] ?? _text(values['status'])
          : 'Без статуса';

  String get amount => _text(values['amount']);

  List<MapEntry<String, String>> get detailValues {
    const labels = {
      'amount': 'Сумма',
      'payment_purpose': 'Назначение',
      'description': 'Комментарий',
      'document_date': 'Дата документа',
      'due_date': 'Срок оплаты',
      'direction': 'Направление',
      'invoice_type': 'Тип счета',
    };
    return labels.entries
        .where((entry) => _text(values[entry.key]).isNotEmpty)
        .map((entry) {
          final value = _text(values[entry.key]);
          final localized = switch (entry.key) {
            'direction' =>
              _text(values['direction_label']).isNotEmpty
                  ? _text(values['direction_label'])
                  : _directionLabels[value] ?? value,
            'invoice_type' =>
              _text(values['invoice_type_label']).isNotEmpty
                  ? _text(values['invoice_type_label'])
                  : _invoiceTypeLabels[value] ?? value,
            'document_date' || 'due_date' => _localizedDate(value),
            _ => value,
          };
          return MapEntry(entry.value, localized);
        })
        .toList();
  }

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

String _localizedDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

const _directionLabels = {
  'incoming': 'Входящий (дебиторка)',
  'outgoing': 'Исходящий (кредиторка)',
};

const _invoiceTypeLabels = {
  'act': 'По акту выполненных работ',
  'advance': 'Авансовый платёж',
  'progress': 'Промежуточный платёж',
  'final': 'Финальный расчёт',
  'material_purchase': 'Закупка материалов',
  'service': 'Оплата услуг',
  'equipment': 'Оплата оборудования',
  'salary': 'Заработная плата',
  'other': 'Прочее',
};

const _statusLabels = {
  'draft': 'Черновик',
  'submitted': 'Отправлен',
  'pending_approval': 'На согласовании',
  'approved': 'Утвержден',
  'scheduled': 'Запланирован',
  'paid': 'Оплачен',
  'partially_paid': 'Частично оплачен',
  'rejected': 'Отклонен',
  'cancelled': 'Отменен',
};
