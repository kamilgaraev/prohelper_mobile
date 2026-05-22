import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/workflow_management/data/workflow_repository.dart';
import 'package:prohelpers_mobile/features/workflow_management/data/workflow_task_model.dart';
import 'package:prohelpers_mobile/features/workflow_management/domain/workflow_provider.dart';
import 'package:prohelpers_mobile/features/workflow_management/presentation/workflow_management_screen.dart';

class _RecordingWorkflowRepository extends WorkflowRepository {
  _RecordingWorkflowRepository() : super(Dio());

  int? loadedProjectId;
  String? loadedStatus;
  bool? loadedAssignedToMe;
  String? loadedSearch;
  int? fetchedTaskId;
  int? approvedTaskId;
  int? changesTaskId;
  String? approvedComment;
  String? changesComment;

  @override
  Future<WorkflowTaskListResult> fetchTasks({
    int page = 1,
    int perPage = 20,
    int? projectId,
    String? status,
    required bool assignedToMe,
    String? search,
  }) async {
    loadedProjectId = projectId;
    loadedStatus = status;
    loadedAssignedToMe = assignedToMe;
    loadedSearch = search;

    return WorkflowTaskListResult(
      items: const [_task],
      meta: const WorkflowTaskListMeta(
        currentPage: 1,
        perPage: 20,
        total: 1,
        lastPage: 1,
      ),
      summary: WorkflowTaskListSummary(
        byStatus: const {'pending': 1, 'in_review': 0, 'confirmed': 0},
        projectId: projectId,
        status: status,
        assignedToMe: assignedToMe,
        search: search,
      ),
    );
  }

  @override
  Future<WorkflowTaskModel> fetchTask(int id) async {
    fetchedTaskId = id;
    return _detailTask;
  }

  @override
  Future<WorkflowTaskModel> approveTask(int id, {String? comment}) async {
    approvedTaskId = id;
    approvedComment = comment;
    return _task;
  }

  @override
  Future<WorkflowTaskModel> requestChanges({
    required int id,
    required String comment,
  }) async {
    changesTaskId = id;
    changesComment = comment;
    return _task;
  }
}

class _TestProjectsRepository extends ProjectsRepository {
  _TestProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _TestProjectsNotifier extends ProjectsNotifier {
  _TestProjectsNotifier(Project project) : super(_TestProjectsRepository()) {
    state = ProjectsState(
      isLoading: false,
      projects: [project],
      selectedProject: project,
    );
  }
}

const _task = WorkflowTaskModel(
  id: 17,
  organizationId: 4,
  projectId: 9,
  projectLabel: 'Башня',
  workTypeLabel: 'Бетонирование',
  assignedUserLabel: 'Иван Петров',
  completionDate: '2026-05-22',
  notes: 'Проверить опалубку',
  status: 'pending',
  statusLabel: 'Ожидает согласования',
  availableActions: ['approve', 'reject', 'request_changes', 'comment'],
  workflowSummary: WorkflowSummaryModel(
    status: 'pending',
    stage: 'pending',
    stageLabel: 'Ожидает согласования',
    availableActions: ['approve', 'reject', 'request_changes', 'comment'],
    nextAction: 'approve',
    nextActionLabel: 'Согласовать',
  ),
  comments: [],
  statusHistory: [],
  createdAt: '2026-05-22T08:00:00Z',
  updatedAt: '2026-05-22T10:00:00Z',
);

const _detailTask = WorkflowTaskModel(
  id: 17,
  organizationId: 4,
  projectId: 9,
  projectLabel: 'Башня',
  workTypeLabel: 'Бетонирование',
  contractLabel: 'Д-12',
  contractorLabel: 'Монолит Строй',
  assignedUserLabel: 'Иван Петров',
  scheduleTaskLabel: 'Заливка секции А',
  estimateItemLabel: 'Бетон М300',
  workOriginType: 'manual',
  workOriginLabel: 'Ручной ввод',
  planningStatus: 'planned',
  planningStatusLabel: 'Запланировано',
  quantity: 10,
  completedQuantity: 9.5,
  measurementUnitLabel: 'м3',
  totalAmount: 9500,
  completionDate: '2026-05-22',
  notes: 'Проверить опалубку',
  status: 'pending',
  statusLabel: 'Ожидает согласования',
  availableActions: ['approve', 'reject', 'request_changes', 'comment'],
  workflowSummary: WorkflowSummaryModel(
    status: 'pending',
    stage: 'pending',
    stageLabel: 'Ожидает согласования',
    availableActions: ['approve', 'reject', 'request_changes', 'comment'],
  ),
  comments: [
    WorkflowTaskEntryModel(
      id: 'comment-1',
      action: 'comment',
      fromStatus: 'pending',
      toStatus: 'pending',
      userId: 8,
      createdAt: '2026-05-22T10:00:00Z',
      comment: 'Комментарий бригадира',
    ),
  ],
  statusHistory: [
    WorkflowTaskEntryModel(
      id: 'history-1',
      action: 'request_changes',
      fromStatus: 'draft',
      toStatus: 'in_review',
      userId: 8,
      createdAt: '2026-05-22T09:00:00Z',
      comment: 'Уточнить объем',
    ),
  ],
  createdAt: '2026-05-22T08:00:00Z',
  updatedAt: '2026-05-22T10:00:00Z',
);

void main() {
  Project project() {
    return Project()
      ..serverId = 9
      ..name = 'Башня'
      ..address = 'Площадка 1';
  }

  Widget buildApp(Widget child, _RecordingWorkflowRepository repository) {
    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith(
          (ref) => _TestProjectsNotifier(project()),
        ),
        workflowProvider.overrideWith((ref) => WorkflowNotifier(repository)),
      ],
      child: MaterialApp(home: child),
    );
  }

  Future<void> pumpUi(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
  }

  void useLargeSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('shows workflow list and applies visible filters', (
    tester,
  ) async {
    final repository = _RecordingWorkflowRepository();

    await tester.pumpWidget(
      buildApp(const WorkflowManagementScreen(), repository),
    );
    await pumpUi(tester);

    expect(repository.loadedProjectId, 9);
    expect(repository.loadedAssignedToMe, isTrue);
    expect(find.text('Бетонирование'), findsOneWidget);
    expect(find.text('Проверить опалубку'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Доработка'));
    await pumpUi(tester);
    expect(repository.loadedStatus, 'in_review');

    await tester.tap(find.widgetWithText(FilterChip, 'Мне'));
    await pumpUi(tester);
    expect(repository.loadedAssignedToMe, isFalse);

    await tester.enterText(find.byType(TextField), ' бетон ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpUi(tester);
    expect(repository.loadedSearch, 'бетон');
  });

  testWidgets('opens workflow detail with history and comments', (
    tester,
  ) async {
    final repository = _RecordingWorkflowRepository();

    await tester.pumpWidget(
      buildApp(WorkflowTaskDetailScreen(taskId: 17), repository),
    );
    await pumpUi(tester);

    expect(repository.fetchedTaskId, 17);
    expect(find.text('Детали согласования'), findsOneWidget);
    expect(find.text('Монолит Строй'), findsOneWidget);
    expect(find.text('Уточнить объем'), findsOneWidget);
    expect(find.text('Комментарий бригадира'), findsOneWidget);
  });

  testWidgets('submits approve and request changes actions', (tester) async {
    final repository = _RecordingWorkflowRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(
      buildApp(const WorkflowManagementScreen(), repository),
    );
    await pumpUi(tester);

    await tester.tap(find.text('Согласовать').first);
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).last, 'Проверено');
    await tester.tap(find.text('Согласовать').last);
    await pumpUi(tester);

    expect(repository.approvedTaskId, 17);
    expect(repository.approvedComment, 'Проверено');

    await tester.ensureVisible(find.text('Изменения').first);
    await tester.tap(find.text('Изменения').first);
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).last, 'Уточнить объем');
    await tester.tap(find.text('Отправить').last);
    await pumpUi(tester);

    expect(repository.changesTaskId, 17);
    expect(repository.changesComment, 'Уточнить объем');
  });
}
