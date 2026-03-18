import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_model.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_repository.dart';
import 'package:prohelpers_mobile/features/schedule/domain/schedule_provider.dart';
import 'package:prohelpers_mobile/features/schedule/presentation/schedule_screen.dart';

class _FakeProjectsRepository extends ProjectsRepository {
  _FakeProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _FakeProjectsNotifier extends ProjectsNotifier {
  _FakeProjectsNotifier(Project project) : super(_FakeProjectsRepository()) {
    state = ProjectsState(
      isLoading: false,
      projects: [project],
      selectedProject: project,
      error: null,
    );
  }
}

class _FakeScheduleRepository extends ScheduleRepository {
  _FakeScheduleRepository() : super(Dio());

  @override
  Future<ScheduleOverviewModel> fetchSchedules({required int projectId}) async {
    return _overview;
  }
}

class _FakeScheduleNotifier extends ScheduleNotifier {
  _FakeScheduleNotifier() : super(_FakeScheduleRepository()) {
    state = const ScheduleState(
      isLoading: false,
      overview: _overview,
      error: null,
      projectId: 15,
    );
  }

  @override
  Future<void> load({int? projectId}) async {}
}

const _overview = ScheduleOverviewModel(
  project: ScheduleProjectModel(
    id: 15,
    name: 'Дом 300м Царево',
  ),
  summary: ScheduleOverviewSummaryModel(
    totalSchedules: 3,
    activeSchedules: 1,
    completedSchedules: 1,
    averageProgressPercent: 48.5,
  ),
  schedules: [
    ScheduleItemModel(
      id: 1,
      projectId: 15,
      name: 'Фундамент',
      description: 'Ключевой этап по основанию здания.',
      status: 'draft',
      statusLabel: 'Черновик',
      statusColor: '#6B7280',
      overallProgressPercent: 12,
      progressColor: '#FF9500',
      healthStatus: 'at_risk',
      plannedStartDate: '2026-03-01',
      plannedEndDate: '2026-03-20',
      plannedDurationDays: 20,
      actualStartDate: '2026-03-03',
      actualEndDate: null,
      criticalPathCalculated: false,
      criticalPathDurationDays: null,
      tasksCount: 10,
      completedTasksCount: 1,
      overdueTasksCount: 2,
      createdAt: null,
      updatedAt: null,
    ),
    ScheduleItemModel(
      id: 2,
      projectId: 15,
      name: 'Монтаж кровли',
      description: 'Работы по устройству кровли.',
      status: 'active',
      statusLabel: 'В работе',
      statusColor: '#34C759',
      overallProgressPercent: 63,
      progressColor: '#34C759',
      healthStatus: 'healthy',
      plannedStartDate: '2026-03-05',
      plannedEndDate: '2026-03-28',
      plannedDurationDays: 24,
      actualStartDate: '2026-03-06',
      actualEndDate: null,
      criticalPathCalculated: true,
      criticalPathDurationDays: 12,
      tasksCount: 14,
      completedTasksCount: 8,
      overdueTasksCount: 0,
      createdAt: null,
      updatedAt: null,
    ),
    ScheduleItemModel(
      id: 3,
      projectId: 15,
      name: 'Отделка секции А',
      description: 'Финальная чистовая отделка.',
      status: 'completed',
      statusLabel: 'Завершено',
      statusColor: '#007AFF',
      overallProgressPercent: 100,
      progressColor: '#007AFF',
      healthStatus: 'healthy',
      plannedStartDate: '2026-02-01',
      plannedEndDate: '2026-02-18',
      plannedDurationDays: 18,
      actualStartDate: '2026-02-01',
      actualEndDate: '2026-02-17',
      criticalPathCalculated: true,
      criticalPathDurationDays: 8,
      tasksCount: 8,
      completedTasksCount: 8,
      overdueTasksCount: 0,
      createdAt: null,
      updatedAt: null,
    ),
  ],
);

void main() {
  Project buildProject() {
    return Project()
      ..serverId = 15
      ..name = 'Дом 300м Царево'
      ..address = 'Лесная улица, 15'
      ..myRole = 'Прораб';
  }

  Widget createWidget() {
    final project = buildProject();

    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith((ref) => _FakeProjectsNotifier(project)),
        scheduleProvider.overrideWith((ref) => _FakeScheduleNotifier()),
      ],
      child: const MaterialApp(
        home: ScheduleScreen(),
      ),
    );
  }

  testWidgets('показывает графики и фильтрует их по риску и поиску', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.text('Ситуация под контролем'), findsNothing);
    expect(find.text('Нужны действия'), findsOneWidget);
    expect(find.text('Найдено: 3 из 3'), findsOneWidget);
    expect(find.text('В риске'), findsOneWidget);

    await tester.ensureVisible(find.text('В риске'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('В риске'));
    await tester.pumpAndSettle();

    expect(find.text('Найдено: 1 из 3'), findsOneWidget);

    await _scrollToText(tester, 'Фундамент');

    expect(find.text('Фундамент'), findsOneWidget);
    expect(find.text('Монтаж кровли'), findsNothing);
    expect(find.text('Отделка секции А'), findsNothing);
    
    await _scrollToTop(tester);
    await tester.ensureVisible(find.text('Все'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Все'));
    await tester.pumpAndSettle();

    expect(find.text('Найдено: 3 из 3'), findsOneWidget);

    await _scrollToSearch(tester);
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'Отделка',
    );
    await tester.pumpAndSettle();

    await _scrollToText(tester, 'Отделка секции А');

    expect(find.text('Отделка секции А'), findsOneWidget);
    expect(find.text('Фундамент'), findsNothing);
    expect(find.text('Монтаж кровли'), findsNothing);
    expect(find.text('Найдено: 1 из 3'), findsOneWidget);
  });
}

Future<void> _scrollToText(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollToSearch(WidgetTester tester) async {
  await _scrollToTop(tester);
  await tester.pumpAndSettle();
}

Future<void> _scrollToTop(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 1200));
  await tester.pumpAndSettle();
}
