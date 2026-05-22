import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_model.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_repository.dart';
import 'package:prohelpers_mobile/features/schedule/domain/schedule_provider.dart';

class _FakeScheduleRepository extends ScheduleRepository {
  _FakeScheduleRepository({
    this.overviewError,
    this.dailyPlans = const [],
    this.updatedAssignment,
  }) : super(Dio());

  final Object? overviewError;
  final List<DailyWorkPlanModel> dailyPlans;
  final DailyWorkPlanAssignmentModel? updatedAssignment;
  DailyWorkFactInput? capturedFactInput;

  @override
  Future<ScheduleOverviewModel> fetchSchedules({required int projectId}) async {
    final error = overviewError;
    if (error != null) {
      throw error;
    }

    return const ScheduleOverviewModel(
      project: ScheduleProjectModel(id: 15, name: 'Дом 300м Царево'),
      summary: ScheduleOverviewSummaryModel(
        totalSchedules: 0,
        activeSchedules: 0,
        completedSchedules: 0,
        averageProgressPercent: 0,
      ),
      schedules: [],
    );
  }

  @override
  Future<List<DailyWorkPlanModel>> fetchDailyWorkPlans({
    required int projectId,
  }) async {
    return dailyPlans;
  }

  @override
  Future<DailyWorkPlanAssignmentModel> recordDailyWorkFact({
    required int assignmentId,
    required DailyWorkFactInput input,
  }) async {
    capturedFactInput = input;
    return updatedAssignment!;
  }
}

void main() {
  test('marks schedule overview as permission denied on 403', () async {
    final notifier = ScheduleNotifier(
      _FakeScheduleRepository(
        overviewError: const ApiException('Нет прав', statusCode: 403),
      ),
    );

    await notifier.load(projectId: 15);

    expect(notifier.state.permissionDenied, isTrue);
    expect(notifier.state.error, 'Нет прав');
  });

  test('normalizes malformed schedule contract error', () async {
    final notifier = ScheduleNotifier(
      _FakeScheduleRepository(overviewError: const FormatException('bad')),
    );

    await notifier.load(projectId: 15);

    expect(notifier.state.permissionDenied, isFalse);
    expect(
      notifier.state.error,
      'Данные графика пришли неполными. Обновите экран и повторите попытку.',
    );
  });

  test(
    'recordFact forwards explicit fact input without planned defaults',
    () async {
      final assignment = _assignment(
        status: 'planned',
        statusLabel: 'Запланировано',
      );
      final updatedAssignment = _assignment(
        status: 'done',
        statusLabel: 'Выполнено',
        completedQuantity: 3,
        actualWorkHours: 2,
      );
      final plan = DailyWorkPlanModel(
        id: 41,
        projectId: 15,
        scheduleId: 7,
        lookaheadPlanId: 3,
        scheduleName: 'Tower schedule',
        workDate: '2026-06-08',
        status: 'published',
        statusLabel: 'Опубликован',
        availableActions: const [
          ScheduleActionModel(
            action: ScheduleActionKeys.recordFact,
            label: 'Зафиксировать факт',
          ),
        ],
        assignments: [assignment],
      );
      final repository = _FakeScheduleRepository(
        dailyPlans: [plan],
        updatedAssignment: updatedAssignment,
      );
      final notifier = DailyWorkPlansNotifier(repository);

      await notifier.load(projectId: 15);
      await notifier.recordFact(
        assignment,
        const DailyWorkFactInput(
          status: 'done',
          completedQuantity: 3,
          actualWorkHours: 2,
          factComment: 'Смонтировано по факту',
        ),
      );

      expect(repository.capturedFactInput?.completedQuantity, 3);
      expect(repository.capturedFactInput?.actualWorkHours, 2);
      expect(notifier.state.plans.single.assignments.single.status, 'done');
    },
  );
}

DailyWorkPlanAssignmentModel _assignment({
  required String status,
  required String statusLabel,
  double? completedQuantity,
  double? actualWorkHours,
}) {
  return DailyWorkPlanAssignmentModel(
    id: 51,
    dailyWorkPlanId: 41,
    lookaheadPlanTaskId: 17,
    scheduleTaskId: 7,
    status: status,
    statusLabel: statusLabel,
    factStatusOptions: const [
      DailyWorkFactStatusOptionModel(status: 'done', label: 'Выполнено'),
      DailyWorkFactStatusOptionModel(
        status: 'partially_done',
        label: 'Выполнено частично',
      ),
      DailyWorkFactStatusOptionModel(status: 'not_done', label: 'Не выполнено'),
    ],
    scheduleTaskName: 'Foundation reinforcement',
    plannedQuantity: 10,
    completedQuantity: completedQuantity,
    plannedWorkHours: 8,
    actualWorkHours: actualWorkHours,
    constraints: const [],
    linkedBlockingEntities: const [],
  );
}
