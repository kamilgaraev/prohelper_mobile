import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_document_models.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:prohelpers_mobile/features/ai_assistant/presentation/ai_assistant_documents_screen.dart';

void main() {
  test('OCR limit preserves minor precision and backend maximum', () {
    expect(parseAiDocumentLimit('25,50'), 2550);
    expect(parseAiDocumentLimit('0.01'), 1);
    expect(parseAiDocumentLimit('10000000'), 1000000000);
    expect(parseAiDocumentLimit('10000000.01'), isNull);
    expect(parseAiDocumentLimit('-1'), isNull);
    expect(parseAiDocumentLimit('1.234'), isNull);
  });
  testWidgets(
    'participant sees coverage without owner controls or settings call',
    (tester) async {
      final repository = _Repository(false);
      await tester.pumpWidget(_screen(repository));
      await tester.pumpAndSettle();
      expect(find.text('Требуют распознавания'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Архив: проверено 8 из 12 файлов'),
        400,
      );
      expect(find.text('Архив: проверено 8 из 12 файлов'), findsOneWidget);
      expect(find.text('Сохранить лимит'), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(repository.settingsCalls, 0);
    },
  );
  testWidgets('owner explicitly confirms OCR budget before saving', (
    tester,
  ) async {
    final repository = _Repository(true);
    await tester.pumpWidget(_screen(repository));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(TextField), 400);
    await tester.enterText(find.byType(TextField), '25,50');
    await tester.ensureVisible(find.text('Сохранить лимит'));
    await tester.tap(find.text('Сохранить лимит'));
    await tester.pumpAndSettle();
    expect(repository.savedLimit, isNull);
    expect(find.text('Подтвердить распознавание?'), findsOneWidget);
    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();
    expect(repository.savedLimit, 2550);
    expect(repository.savedScope, 'archive');
    expect(repository.settingsCalls, 2);
  });
}

Widget _screen(_Repository repository) => ProviderScope(
  overrides: [aiAssistantRepositoryProvider.overrideWithValue(repository)],
  child: const MaterialApp(home: AiAssistantDocumentsScreen()),
);

class _Repository extends AiAssistantRepository {
  _Repository(this.owner) : super(Dio());
  final bool owner;
  int settingsCalls = 0;
  int? savedLimit;
  String? savedScope;
  @override
  Future<AiDocumentProcessingStatus> fetchDocumentProcessing() async =>
      AiDocumentProcessingStatus.fromJson({
        'can_manage_document_settings': owner,
        'document_coverage': {'total': 4, 'ready': 2, 'ocr_required': 1},
        'archive_scan': {'expected_file_count': 12, 'scanned_file_count': 8},
      });
  @override
  Future<AiDocumentBudget> fetchDocumentBudget() async {
    settingsCalls++;
    return const AiDocumentBudget(
      enabled: true,
      scope: 'archive',
      limitMinor: 1000,
      spentMinor: 0,
      reservedMinor: 0,
      availableMinor: 1000,
    );
  }

  @override
  Future<AiDocumentBudget> approveDocumentBudget({
    required bool enabled,
    required String scope,
    required int limitMinor,
  }) async {
    savedLimit = limitMinor;
    savedScope = scope;
    return AiDocumentBudget(
      enabled: enabled,
      scope: scope,
      limitMinor: limitMinor,
      spentMinor: 0,
      reservedMinor: 0,
      availableMinor: limitMinor,
    );
  }
}
