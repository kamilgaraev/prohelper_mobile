import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_models.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_repository.dart';
import 'package:prohelpers_mobile/features/construction_journal/presentation/include_journal_entry_dialog.dart';

class _Repository extends ConstructionJournalRepository {
  _Repository({this.empty = false, this.failFirst = false}) : super(Dio());
  final bool empty;
  final bool failFirst;
  int calls = 0;
  int? target;
  String? comment;
  @override
  Future<List<JournalReportingTarget>> reportingTargets(int entryId) async =>
      empty ? [] : [const JournalReportingTarget(id: 8, name: 'Мой журнал')];
  @override
  Future<ConstructionJournalEntryModel> includeInJournal(
    int entryId,
    int targetJournalId,
    String text,
  ) async {
    calls++;
    target = targetJournalId;
    comment = text;
    if (failFirst && calls == 1) {
      throw const ApiException('Сеть недоступна. Повторите запрос.');
    }
    return const ConstructionJournalEntryModel(
      id: 29,
      journalId: 8,
      entryDate: '2026-10-11',
      entryNumber: 1,
      workDescription: 'Принятые работы',
      status: 'draft',
      statusLabel: 'Черновик',
      workflowState: 'ready',
      workVolumes: [],
      blockers: [],
      availableActions: [],
    );
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    _Repository repository, {
    bool current = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          constructionJournalRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed:
                        () => showDialog(
                          context: context,
                          builder:
                              (_) => IncludeJournalEntryDialog(
                                sourceId: 17,
                                isContextCurrent: () => current,
                              ),
                        ),
                    child: const Text('Открыть'),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
  }

  testWidgets('missing target is explained and include disabled', (
    tester,
  ) async {
    final repository = _Repository(empty: true);
    await open(tester, repository);
    expect(
      find.textContaining('Нет активного собственного журнала'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Включить'))
          .onPressed,
      isNull,
    );
  });
  testWidgets('failed include retains target and comment for retry', (
    tester,
  ) async {
    final repository = _Repository(failFirst: true);
    await open(tester, repository);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Мой журнал · №8').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Отчёт за смену');
    await tester.tap(find.widgetWithText(FilledButton, 'Включить'));
    await tester.pumpAndSettle();
    expect(find.text('Сеть недоступна. Повторите запрос.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Включить'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(repository.target, 8);
    expect(repository.comment, 'Отчёт за смену');
    expect(find.byType(IncludeJournalEntryDialog), findsNothing);
  });
  testWidgets('changed project or actor blocks the mutation', (tester) async {
    final repository = _Repository();
    await open(tester, repository, current: false);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Мой журнал · №8').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Включить'));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    expect(
      find.textContaining('Объект или организация изменились'),
      findsOneWidget,
    );
  });
}
