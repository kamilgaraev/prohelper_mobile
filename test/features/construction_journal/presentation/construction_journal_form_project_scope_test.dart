import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_models.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_repository.dart';
import 'package:prohelpers_mobile/features/construction_journal/domain/construction_journal_provider.dart';
import 'package:prohelpers_mobile/features/construction_journal/presentation/journal_entry_detail_screen.dart';
import 'package:prohelpers_mobile/features/construction_journal/presentation/journal_entry_form_screen.dart';
import 'package:prohelpers_mobile/features/construction_journal/presentation/journal_form_screen.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

class _ProjectsRepository extends ProjectsRepository {
  _ProjectsRepository() : super(Dio());
}

class _ProjectsNotifier extends ProjectsNotifier {
  _ProjectsNotifier(int projectId) : super(_ProjectsRepository()) {
    select(projectId);
  }

  void select(int projectId) {
    final project =
        Project()
          ..serverId = projectId
          ..name = 'Объект $projectId'
          ..address = 'Площадка $projectId';
    state = state.copyWith(selectedProject: project);
  }
}

class _JournalRepository extends ConstructionJournalRepository {
  _JournalRepository() : super(Dio());

  int journalUpdates = 0;
  int entryUpdates = 0;

  @override
  Future<ConstructionJournalEntryModel> fetchEntryDetail(int entryId) async =>
      _entry;

  @override
  Future<List<ConstructionJournalContractOption>> fetchJournalFormOptions({
    required int projectId,
  }) async => const [ConstructionJournalContractOption(id: 4, number: 'ДОГ-4')];

  @override
  Future<ConstructionJournalModel> updateJournal({
    required int journalId,
    required int contractId,
    required String name,
    required String journalNumber,
    required String startDate,
  }) async {
    journalUpdates++;
    return _journal;
  }

  @override
  Future<ConstructionJournalEntryFormOptions> fetchEntryFormOptions(
    int journalId,
  ) async => const ConstructionJournalEntryFormOptions(
    estimates: [],
    workTypes: [],
    projectMaterials: [],
  );

  @override
  Future<ConstructionJournalEntryModel> updateEntry({
    required int entryId,
    required String entryDate,
    required String workDescription,
    int? scheduleTaskId,
    int? estimateId,
    String? problemsDescription,
    String? safetyNotes,
    String? visitorsNotes,
    String? qualityNotes,
    ConstructionJournalWeatherModel? weatherConditions,
    List<ConstructionJournalWorkVolumeModel> workVolumes = const [],
    List<ConstructionJournalWorkerModel> workers = const [],
    List<ConstructionJournalEquipmentModel> equipment = const [],
    List<ConstructionJournalMaterialUsageModel> materials = const [],
  }) async {
    entryUpdates++;
    return _entry;
  }
}

final _journal = ConstructionJournalModel(
  id: 7,
  projectId: 9,
  name: 'Журнал',
  journalNumber: 'Ж-7',
  startDate: '2026-09-01',
  status: 'active',
  statusLabel: 'Активен',
  contractId: 4,
  totalEntries: 1,
  approvedEntries: 0,
  submittedEntries: 0,
  rejectedEntries: 0,
  availableActions: const [],
);

final _entry = ConstructionJournalEntryModel(
  id: 18,
  journalId: 7,
  entryDate: '2026-09-20',
  entryNumber: 1,
  workDescription: 'Монтаж',
  status: 'draft',
  statusLabel: 'Черновик',
  workflowState: 'ready',
  workVolumes: const [],
  blockers: const [],
  availableActions: const [
    ConstructionJournalActionModel(
      action: ConstructionJournalActionKeys.update,
      label: 'Редактировать',
    ),
  ],
);

void main() {
  testWidgets('opened journal edit form refuses save after project switch', (
    tester,
  ) async {
    final projects = _ProjectsNotifier(9);
    final repository = _JournalRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsProvider.overrideWith((ref) => projects),
          constructionJournalRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(home: JournalFormScreen(initialJournal: _journal)),
      ),
    );
    await tester.pumpAndSettle();
    final save =
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Сохранить'),
            )
            .onPressed!;
    projects.select(52);
    save();
    await tester.pumpAndSettle();

    expect(repository.journalUpdates, 0);
  });

  testWidgets('opened journal entry form refuses save after project switch', (
    tester,
  ) async {
    final projects = _ProjectsNotifier(9);
    final repository = _JournalRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsProvider.overrideWith((ref) => projects),
          constructionJournalRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: JournalEntryFormScreen(
            journalId: 7,
            projectId: 9,
            initialEntry: _entry,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Сохранить черновик'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    final save =
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Сохранить черновик'),
            )
            .onPressed!;
    projects.select(52);
    save();
    await tester.pumpAndSettle();

    expect(repository.entryUpdates, 0);
  });

  testWidgets('entry detail passes its original project into the edit form', (
    tester,
  ) async {
    final projects = _ProjectsNotifier(9);
    final repository = _JournalRepository();
    const scope = (entryId: 18, projectId: 9);
    final detailNotifier = ConstructionJournalEntryDetailNotifier(
      repository,
      18,
      projectId: 9,
    );
    await detailNotifier.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsProvider.overrideWith((ref) => projects),
          constructionJournalRepositoryProvider.overrideWithValue(repository),
          constructionJournalEntryDetailProvider(
            scope,
          ).overrideWith((ref) => detailNotifier),
        ],
        child: const MaterialApp(
          home: JournalEntryDetailScreen(
            journalId: 7,
            entryId: 18,
            projectId: 9,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Редактировать'));
    await tester.pumpAndSettle();
    projects.select(52);
    await tester.pump();

    expect(
      tester
          .widget<JournalEntryFormScreen>(find.byType(JournalEntryFormScreen))
          .projectId,
      9,
    );
    await tester.scrollUntilVisible(
      find.text('Сохранить черновик'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    final save =
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Сохранить черновик'),
            )
            .onPressed;
    expect(save, isNull);
    expect(repository.entryUpdates, 0);
  });
}
