import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/contract_management/data/legal_document_model.dart';
import 'package:prohelpers_mobile/features/contract_management/presentation/widgets/legal_document_detail.dart';

void main() {
  testWidgets('shows upload progress and disables a second original upload', (tester) async {
    var uploadCalls = 0;
    var cancelCalls = 0;

    await tester.pumpWidget(_detail(
      uploads: const {19: PaperOriginalUploadState.uploading(0.42)},
      onUpload: (_) async => uploadCalls++,
      onCancel: (_) => cancelCalls++,
    ));

    expect(find.text('Загрузка скана 42%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Отменить'), findsOneWidget);
    expect(find.text('Загрузить скан оригинала'), findsNothing);

    await tester.tap(find.text('Отменить'));
    await tester.pump();
    expect(cancelCalls, 1);

    await tester.tap(find.byType(ListTile).last);
    await tester.pump();
    expect(uploadCalls, 0);
  });

  testWidgets('offers stable retry after a failed upload', (tester) async {
    var retryCalls = 0;

    await tester.pumpWidget(_detail(
      uploads: const {19: PaperOriginalUploadState.failed()},
      onRetry: (_) => retryCalls++,
    ));

    expect(find.text('Не удалось загрузить скан'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pump();

    expect(retryCalls, 1);
  });

  testWidgets('allows selecting an original when no upload is running', (tester) async {
    var uploadCalls = 0;

    await tester.pumpWidget(_detail(onUpload: (_) async => uploadCalls++));

    expect(find.text('Загрузить скан оригинала'), findsOneWidget);
    await tester.tap(find.byType(ListTile).last);
    await tester.pump();

    expect(uploadCalls, 1);
  });
}

Widget _detail({
  Map<int, PaperOriginalUploadState> uploads = const <int, PaperOriginalUploadState>{},
  Future<void> Function(LegalDocumentSignatureRequest request)? onUpload,
  ValueChanged<LegalDocumentSignatureRequest>? onCancel,
  ValueChanged<LegalDocumentSignatureRequest>? onRetry,
}) {
  return MaterialApp(
    home: Scaffold(
      body: LegalDocumentDetail(
        document: _document(),
        onAction: (_) {},
        onVersionOpen: (_, _) async {},
        onPaperOriginalUpload: onUpload ?? (_) async {},
        paperOriginalUploads: uploads,
        onPaperOriginalUploadCancel: onCancel,
        onPaperOriginalUploadRetry: onRetry,
      ),
    ),
  );
}

LegalDocumentModel _document() => const LegalDocumentModel(
  id: 44,
  title: 'Договор подряда',
  documentTypeLabel: 'Договор',
  status: 'pending',
  statusLabel: 'Ожидает подписи',
  workflow: LegalDocumentWorkflow(status: 'pending', actions: [], problemFlags: []),
  versions: [],
  signatureStatus: 'not_signed',
  obligations: [],
  signatureRequests: [LegalDocumentSignatureRequest(id: 19, method: 'paper')],
);
