import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/budget_estimates/data/budget_estimate_model.dart';
import 'package:prohelpers_mobile/features/budget_estimates/data/budget_estimates_repository.dart';
import 'package:prohelpers_mobile/features/budget_estimates/domain/budget_estimates_provider.dart';
import 'package:prohelpers_mobile/features/budget_estimates/presentation/budget_estimates_screen.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

class _RecordingBudgetRepository extends BudgetEstimatesRepository {
  _RecordingBudgetRepository() : super(Dio());

  int? loadedProjectId;
  int? fetchedEstimateId;
  int? approvedEstimateId;
  int? returnedEstimateId;
  String? approvedComment;
  String? returnComment;

  @override
  Future<BudgetEstimateSummaryModel> fetchSummary({
    required int projectId,
  }) async {
    loadedProjectId = projectId;
    return _summary;
  }

  @override
  Future<BudgetEstimateDetailModel> fetchEstimate(int id) async {
    fetchedEstimateId = id;
    return const BudgetEstimateDetailModel(
      estimate: _estimate,
      linkedChangeRequests: [_change],
    );
  }

  @override
  Future<BudgetEstimateModel> approveEstimate({
    required int id,
    String? comment,
  }) async {
    approvedEstimateId = id;
    approvedComment = comment;
    return _approvedEstimate;
  }

  @override
  Future<BudgetEstimateModel> requestChanges({
    required int id,
    required String comment,
  }) async {
    returnedEstimateId = id;
    returnComment = comment;
    return _estimate;
  }
}

class _TestProjectsRepository extends ProjectsRepository {
  _TestProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _TestProjectsNotifier extends ProjectsNotifier {
  _TestProjectsNotifier(Project? project) : super(_TestProjectsRepository()) {
    state = ProjectsState(
      isLoading: false,
      projects: project == null ? const [] : [project],
      selectedProject: project,
    );
  }
}

void main() {
  Project project() {
    return Project()
      ..serverId = 9
      ..name = 'Башня'
      ..address = 'Площадка 1';
  }

  Widget buildApp(
    Widget child,
    _RecordingBudgetRepository repository, {
    Project? selectedProject,
  }) {
    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith(
          (ref) => _TestProjectsNotifier(selectedProject),
        ),
        budgetEstimatesProvider.overrideWith(
          (ref) => BudgetEstimatesNotifier(repository),
        ),
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
    tester.view.physicalSize = const Size(1100, 1300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('shows selected project summary and estimates', (tester) async {
    final repository = _RecordingBudgetRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(
      buildApp(
        const BudgetEstimatesScreen(),
        repository,
        selectedProject: project(),
      ),
    );
    await pumpUi(tester);

    expect(repository.loadedProjectId, 9);
    expect(find.text('Сметы и бюджет'), findsOneWidget);
    expect(find.text('Башня'), findsWidgets);
    expect(find.text('Каркас секции А'), findsWidgets);
    expect(find.text('Изменения бюджета'), findsOneWidget);
    expect(find.text('Уточнение марки бетона'), findsOneWidget);
    expect(find.text('1 200 000 ₽'), findsWidgets);
  });

  testWidgets('shows explicit empty state without selected project', (
    tester,
  ) async {
    final repository = _RecordingBudgetRepository();

    await tester.pumpWidget(
      buildApp(const BudgetEstimatesScreen(), repository),
    );
    await pumpUi(tester);

    expect(repository.loadedProjectId, isNull);
    expect(find.text('Выберите объект'), findsOneWidget);
  });

  testWidgets('submits approval and request changes from summary', (
    tester,
  ) async {
    final repository = _RecordingBudgetRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(
      buildApp(
        const BudgetEstimatesScreen(),
        repository,
        selectedProject: project(),
      ),
    );
    await pumpUi(tester);

    await tester.tap(find.text('Согласовать').first);
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).last, 'Проверено');
    await tester.tap(find.text('Отправить').last);
    await pumpUi(tester);

    expect(repository.approvedEstimateId, 17);
    expect(repository.approvedComment, 'Проверено');

    await tester.tap(find.text('Доработка').first);
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).last, 'Уточнить объем');
    await tester.tap(find.text('Отправить').last);
    await pumpUi(tester);

    expect(repository.returnedEstimateId, 17);
    expect(repository.returnComment, 'Уточнить объем');
  });

  testWidgets('opens detail with estimate lines and linked changes', (
    tester,
  ) async {
    final repository = _RecordingBudgetRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(
      buildApp(
        BudgetEstimateDetailScreen(estimateId: 17),
        repository,
        selectedProject: project(),
      ),
    );
    await pumpUi(tester);

    expect(repository.fetchedEstimateId, 17);
    expect(find.text('Смета'), findsOneWidget);
    expect(find.text('Бетон М300'), findsOneWidget);
    expect(find.text('Уточнение марки бетона'), findsOneWidget);
  });
}

const _project = BudgetProjectModel(
  id: 9,
  name: 'Башня',
  status: 'active',
  budgetAmount: 1500000,
);

const _totals = BudgetTotalsModel(
  estimatesCount: 1,
  byStatus: {'draft': 0, 'in_review': 1, 'approved': 0, 'cancelled': 0},
  totalAmount: 1000000,
  totalAmountWithVat: 1200000,
  approvedAmountWithVat: 0,
  inReviewCount: 1,
);

const _budget = BudgetRemainingModel(
  projectBudgetAmount: 1500000,
  approvedEstimateAmount: 1200000,
  approvedChangeDelta: 60000,
  pendingChangeDelta: 25000,
  committedAmount: 1260000,
  budgetRemaining: 240000,
);

const _approval = BudgetEstimateApprovalSummaryModel(
  status: 'in_review',
  statusLabel: 'На согласовании',
  availableActions: ['approve', 'request_changes'],
);

const _approvedApproval = BudgetEstimateApprovalSummaryModel(
  status: 'approved',
  statusLabel: 'Согласовано',
  availableActions: [],
);

const _estimateTotals = BudgetEstimateTotalsModel(
  directCosts: 900000,
  overheadCosts: 50000,
  estimatedProfit: 50000,
  equipmentCosts: 0,
  amount: 1000000,
  amountWithVat: 1200000,
  vatRate: 20,
  overheadRate: 5,
  profitRate: 5,
);

const _statistics = BudgetEstimateStatisticsModel(
  sectionsCount: 1,
  itemsCount: 1,
);

const _item = BudgetEstimateLineItemModel(
  id: 101,
  estimateId: 17,
  estimateSectionId: 71,
  positionNumber: '1.1',
  name: 'Бетон М300',
  itemType: 'material',
  measurementUnitLabel: 'м3',
  quantity: 20,
  quantityTotal: 20,
  unitPrice: 4000,
  currentUnitPrice: 4100,
  totalAmount: 80000,
  currentTotalAmount: 82000,
  procurementStatus: 'planned',
);

const _lineGroup = BudgetEstimateLineGroupModel(
  id: 71,
  estimateId: 17,
  sectionNumber: '1',
  name: 'Бетонные работы',
  sortOrder: 10,
  isSummary: false,
  totalAmount: 800000,
  items: [_item],
);

const _estimate = BudgetEstimateModel(
  id: 17,
  organizationId: 4,
  projectId: 9,
  projectLabel: 'Башня',
  contractId: 3,
  number: 'EST-17',
  name: 'Каркас секции А',
  description: 'Работы нулевого цикла',
  type: 'base',
  status: 'in_review',
  statusLabel: 'На согласовании',
  version: 2,
  estimateDate: '2026-05-22',
  basePriceDate: '2026-05-01',
  totals: _estimateTotals,
  statistics: _statistics,
  approvalSummary: _approval,
  availableActions: ['approve', 'request_changes'],
  lineGroups: [_lineGroup],
  unsectionedItems: [],
  createdAt: '2026-05-22T08:00:00Z',
  updatedAt: '2026-05-22T10:00:00Z',
);

const _approvedEstimate = BudgetEstimateModel(
  id: 17,
  organizationId: 4,
  projectId: 9,
  projectLabel: 'Башня',
  contractId: 3,
  number: 'EST-17',
  name: 'Каркас секции А',
  description: 'Работы нулевого цикла',
  type: 'base',
  status: 'approved',
  statusLabel: 'Согласовано',
  version: 2,
  estimateDate: '2026-05-22',
  basePriceDate: '2026-05-01',
  totals: _estimateTotals,
  statistics: _statistics,
  approvalSummary: _approvedApproval,
  availableActions: [],
  lineGroups: [_lineGroup],
  unsectionedItems: [],
  createdAt: '2026-05-22T08:00:00Z',
  updatedAt: '2026-05-22T10:00:00Z',
);

const _change = BudgetChangeRequestModel(
  id: 33,
  projectId: 9,
  changeNumber: 'CR-17',
  title: 'Уточнение марки бетона',
  reason: 'Проектное изменение',
  status: 'submitted',
  statusLabel: 'На рассмотрении',
  costDelta: 25000,
  scheduleDeltaDays: 2,
  requiresEstimateRevision: true,
  affectedEstimateItemIds: [101],
  createdAt: '2026-05-22T09:00:00Z',
);

const _summary = BudgetEstimateSummaryModel(
  project: _project,
  totals: _totals,
  budget: _budget,
  estimates: [_estimate],
  linkedChangeRequests: [_change],
  assignedApprovals: [_estimate],
);
