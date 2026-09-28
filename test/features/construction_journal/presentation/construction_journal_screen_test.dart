import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/widgets/industrial_card.dart';
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
  _JournalNotifier({bool canCreate = false}) : super(_JournalRepository()) {
    final actions =
        canCreate
            ? const [
              ConstructionJournalActionModel(
                action: ConstructionJournalActionKeys.create,
                label: 'Создать журнал',
              ),
            ]
            : const <ConstructionJournalActionModel>[];
    state = ConstructionJournalState(
      projectId: 9,
      availableActions: actions,
      items: [
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
          availableActions: actions,
        ),
      ],
      summary: const ConstructionJournalSummary(
        totalJournals: 1,
        activeJournals: 1,
      ),
      project: const ConstructionJournalProjectRef(id: 9, name: 'Башня'),
    );
  }

  final requestedProjects = <int?>[];

  @override
  Future<void> load({required int? projectId}) async {
    requestedProjects.add(projectId);
    if (projectId != 9) {
      state = ConstructionJournalState(
        projectId: projectId,
        isLoading: projectId != null,
      );
    }
  }
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

  void select(int id, String name) {
    final selected =
        Project()
          ..serverId = id
          ..name = name
          ..address = 'Площадка $id';
    state = state.copyWith(selectedProject: selected);
  }
}

void main() {
  testWidgets(
    'retained journal screen reloads and hides previous project data',
    (tester) async {
      final projects = _ProjectsNotifier();
      final journal = _JournalNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectsProvider.overrideWith((ref) => projects),
            constructionJournalProvider.overrideWith((ref) => journal),
          ],
          child: const MaterialApp(home: ConstructionJournalScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Журнал_монтажных_работ_северного_корпуса_секции_А'),
        findsOneWidget,
      );

      projects.select(52, 'Корпус 52');
      await tester.pump();

      expect(journal.requestedProjects, contains(52));
      expect(
        find.text('Журнал_монтажных_работ_северного_корпуса_секции_А'),
        findsNothing,
      );
      expect(find.text('Загружаем журналы работ'), findsOneWidget);
    },
  );

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
    expect(find.byTooltip('Новый журнал'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('journal creation stays in app bar above scrollable card', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsProvider.overrideWith((ref) => _ProjectsNotifier()),
          constructionJournalProvider.overrideWith(
            (ref) => _JournalNotifier(canCreate: true),
          ),
        ],
        child: const MaterialApp(home: ConstructionJournalScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final createButton = find.byTooltip('Новый журнал');
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(createButton, findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    final title = find.text(
      'Журнал_монтажных_работ_северного_корпуса_секции_А',
    );
    final card =
        find.ancestor(of: title, matching: find.byType(IndustrialCard)).first;
    expect(
      tester.getRect(card).overlaps(tester.getRect(createButton)),
      isFalse,
    );
    expect(tester.getRect(card).contains(const Offset(316, 756)), isTrue);
  });
}
