import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/workflow_management/data/workflow_repository.dart';
import 'package:prohelpers_mobile/features/workflow_management/data/workflow_task_model.dart';
import 'package:prohelpers_mobile/features/workflow_management/domain/workflow_provider.dart';

class _FakeWorkflowRepository extends WorkflowRepository {
  _FakeWorkflowRepository({this.error}) : super(Dio());

  final Object? error;

  int? loadedProjectId;
  String? loadedStatus;
  bool? loadedAssignedToMe;
  String? loadedSearch;
  int? fetchedTaskId;
  int? approvedTaskId;
  int? rejectedTaskId;
  int? changesTaskId;
  int? commentTaskId;
  String? approvedComment;
  String? rejectedReason;
  String? changesComment;
  String? addedComment;

  @override
  Future<WorkflowTaskListResult> fetchTasks({
    int page = 1,
    int perPage = 20,
    int? projectId,
    String? status,
    required bool assignedToMe,
    String? search,
  }) async {
    final currentError = error;
    if (currentError != null) {
      throw currentError;
    }

    loadedProjectId = projectId;
    loadedStatus = status;
    loadedAssignedToMe = assignedToMe;
    loadedSearch = search;

    return const WorkflowTaskListResult(
      items: [_task],
      meta: WorkflowTaskListMeta(
        currentPage: 1,
        perPage: 20,
        total: 1,
        lastPage: 1,
      ),
      summary: WorkflowTaskListSummary(
        byStatus: {'pending': 1},
        projectId: 9,
        status: 'pending',
        assignedToMe: true,
      ),
    );
  }

  @override
  Future<WorkflowTaskModel> fetchTask(int id) async {
    fetchedTaskId = id;
    return _task;
  }

  @override
  Future<WorkflowTaskModel> approveTask(int id, {String? comment}) async {
    approvedTaskId = id;
    approvedComment = comment;
    return _task;
  }

  @override
  Future<WorkflowTaskModel> rejectTask({
    required int id,
    required String reason,
  }) async {
    rejectedTaskId = id;
    rejectedReason = reason;
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

  @override
  Future<WorkflowTaskModel> addComment({
    required int id,
    required String comment,
  }) async {
    commentTaskId = id;
    addedComment = comment;
    return _task;
  }
}

const _task = WorkflowTaskModel(
  id: 17,
  organizationId: 4,
  projectId: 9,
  projectLabel: 'Башня',
  workTypeLabel: 'Бетонирование',
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

void main() {
  test('loads workflow tasks with selected filters', () async {
    final repository = _FakeWorkflowRepository();
    final notifier = WorkflowNotifier(repository);

    notifier.syncProject(9);
    notifier.setStatusFilter('pending');
    notifier.setAssignedToMe(true);
    notifier.setSearch(' бетон ');
    await notifier.loadTasks();

    expect(repository.loadedProjectId, 9);
    expect(repository.loadedStatus, 'pending');
    expect(repository.loadedAssignedToMe, isTrue);
    expect(repository.loadedSearch, 'бетон');
    expect(notifier.state.tasks.single.id, 17);
    expect(notifier.state.summary?.byStatus['pending'], 1);
  });

  test('refreshes list after workflow actions', () async {
    final repository = _FakeWorkflowRepository();
    final notifier = WorkflowNotifier(repository)..syncProject(9);

    await notifier.approveTask(17, comment: 'Проверено');
    await notifier.rejectTask(id: 17, reason: 'Не подтверждено');
    await notifier.requestChanges(id: 17, comment: 'Уточнить объем');
    await notifier.addComment(id: 17, comment: 'Принято в работу');

    expect(repository.approvedTaskId, 17);
    expect(repository.approvedComment, 'Проверено');
    expect(repository.rejectedReason, 'Не подтверждено');
    expect(repository.changesComment, 'Уточнить объем');
    expect(repository.addedComment, 'Принято в работу');
    expect(notifier.state.tasks, hasLength(1));
  });

  test('marks permission and malformed contract states', () async {
    final denied = WorkflowNotifier(
      _FakeWorkflowRepository(
        error: const ApiException('Нет доступа', statusCode: 403),
      ),
    );
    await denied.loadTasks();

    expect(denied.state.permissionDenied, isTrue);
    expect(denied.state.error, 'Нет доступа');

    final malformed = WorkflowNotifier(
      _FakeWorkflowRepository(error: const FormatException('bad payload')),
    );
    await malformed.loadTasks();

    expect(malformed.state.malformedContract, isTrue);
    expect(malformed.state.tasks, isEmpty);
  });

  test('loads workflow detail by id', () async {
    final repository = _FakeWorkflowRepository();
    final notifier = WorkflowNotifier(repository);

    final detail = await notifier.fetchTask(17);

    expect(repository.fetchedTaskId, 17);
    expect(detail.title, 'Бетонирование');
  });
}
