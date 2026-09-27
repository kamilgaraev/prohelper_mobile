import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_models.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_repository.dart';
import 'package:prohelpers_mobile/features/construction_journal/domain/construction_journal_provider.dart';
import 'package:prohelpers_mobile/features/construction_journal/presentation/construction_journal_screen.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

class _JournalRepository extends ConstructionJournalRepository {
  _JournalRepository() : super(Dio());
}

class _JournalNotifier extends ConstructionJournalNotifier {
  _JournalNotifier() : super(_JournalRepository()) {
    state = ConstructionJournalState(
      items: const [
        ConstructionJournalModel(
          id: 1,
          projectId: 9,
          name: 'Журнал_монтажных_работ_северного_корпуса_секции_А',
          journalNumber: 'QA-JOURNAL-2026-001',
          startDate: '2026-08-01',
          status: 'active',
          statusLabel: 'Ожидает подтверждения заказчика',
          totalEntries: 5,
          approvedEntries: 2,
          submittedEntries: 2,
          rejectedEntries: 1,
          availableActions: [],
        ),
      ],
      summary: const ConstructionJournalSummary(
        totalJournals: 1,
        activeJournals: 1,
      ),
      project: const ConstructionJournalProjectRef(id: 9, name: 'Башня'),
    );
  }

  @override
  Future<void> load({required int? projectId}) async {}
}

class _ProjectsRepository extends ProjectsRepository {
  _ProjectsRepository() : super(Dio());
}

class _ProjectsNotifier extends ProjectsNotifier {
  _ProjectsNotifier() : super(_ProjectsRepository()) {
    final selected =
        Project()
          ..serverId = 9
          ..name = 'Башня'
          ..address = 'Площадка 1';
    state = ProjectsState(
      isLoading: false,
      projects: [selected],
      selectedProject: selected,
    );
  }
}

void main() {
  testWidgets('journal card shows long title above status on compact screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsProvider.overrideWith((ref) => _ProjectsNotifier()),
          constructionJournalProvider.overrideWith((ref) => _JournalNotifier()),
        ],
        child: MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
          home: const ConstructionJournalScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    const title = 'Журнал_монтажных_работ_северного_корпуса_секции_А';
    await tester.scrollUntilVisible(
      find.text(title),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text(title), findsOneWidget);
    expect(find.text('Ожидает подтверждения заказчика'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
