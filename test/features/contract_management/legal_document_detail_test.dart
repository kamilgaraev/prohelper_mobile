import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/contract_management/data/legal_document_model.dart';
import 'package:prohelpers_mobile/features/contract_management/presentation/widgets/legal_document_detail.dart';

void main() {
  testWidgets('hides paper-original upload when server gives no permission', (
    tester,
  ) async {
    var uploadCalls = 0;
    await tester.pumpWidget(_detail(onUpload: (_) async => uploadCalls++));

    expect(find.text('Загрузить скан оригинала'), findsNothing);
    expect(find.text('Оригиналы'), findsNothing);
    expect(uploadCalls, 0);
  });

  testWidgets('shows original upload only when API explicitly allows it', (
    tester,
  ) async {
    var uploadCalls = 0;
    await tester.pumpWidget(
      _detail(canUploadOriginal: true, onUpload: (_) async => uploadCalls++),
    );

    expect(find.text('Загрузить скан оригинала'), findsOneWidget);
    await tester.tap(find.text('Загрузить скан оригинала'));
    await tester.pump();
    expect(uploadCalls, 1);
  });
}

Widget _detail({
  required Future<void> Function(LegalDocumentSignatureRequest request)
  onUpload,
  bool canUploadOriginal = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: LegalDocumentDetail(
        document: _document(canUploadOriginal: canUploadOriginal),
        onAction: (_) {},
        onVersionOpen: (_, _) async {},
        onPaperOriginalUpload: onUpload,
      ),
    ),
  );
}

LegalDocumentModel _document({required bool canUploadOriginal}) =>
    LegalDocumentModel(
      id: 44,
      title: 'Договор подряда',
      documentTypeLabel: 'Договор',
      status: 'pending',
      statusLabel: 'Ожидает подписи',
      workflow: const LegalDocumentWorkflow(
        status: 'pending',
        actions: [],
        problemFlags: [],
      ),
      versions: const [],
      signatureStatus: 'not_signed',
      obligations: const [],
      signatureRequests: [
        LegalDocumentSignatureRequest(
          id: 19,
          method: 'paper',
          canUploadOriginal: canUploadOriginal,
        ),
      ],
    );
