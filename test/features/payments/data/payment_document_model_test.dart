import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/payments/data/payment_document_model.dart';

void main() {
  test('reads per-action capabilities without inferring them from role', () {
    final document = PaymentDocumentModel.fromJson({
      'id': 17,
      'status': 'draft',
      'can_edit': true,
      'can_submit': false,
      'can_register_payment': true,
      'can_approve': true,
      'can_reject': false,
    });

    expect(document.id, 17);
    expect(document.canEdit, isTrue);
    expect(document.canSubmit, isFalse);
    expect(document.canRegisterPayment, isTrue);
    expect(document.canApprove, isTrue);
    expect(document.canReject, isFalse);
  });

  test('rejects documents without a valid identifier', () {
    expect(
      () => PaymentDocumentModel.fromJson({'status': 'draft'}),
      throwsFormatException,
    );
  });

  test('shows financial details with business labels', () {
    final document = PaymentDocumentModel.fromJson({
      'id': 18,
      'status': 'approved',
      'direction': 'outgoing',
      'invoice_type': 'act',
      'document_date': '2026-09-04',
    });

    expect(document.status, 'Утвержден');
    expect(
      document.detailValues.map((entry) => '${entry.key}: ${entry.value}'),
      contains('Направление: Исходящий (кредиторка)'),
    );
    expect(
      document.detailValues.map((entry) => '${entry.key}: ${entry.value}'),
      contains('Тип счета: По акту выполненных работ'),
    );
    expect(
      document.detailValues.map((entry) => '${entry.key}: ${entry.value}'),
      contains('Дата документа: 04.09.2026'),
    );
  });
}
