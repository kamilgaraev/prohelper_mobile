import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/budget_estimates/data/budget_estimate_model.dart';
import 'package:prohelpers_mobile/features/budget_estimates/data/budget_estimates_repository.dart';
import 'package:prohelpers_mobile/features/budget_estimates/domain/budget_estimates_provider.dart';

class _RecordingBudgetRepository extends BudgetEstimatesRepository {
  _RecordingBudgetRepository({this.error}) : super(Dio());

  final Object? error;

  int? loadedProjectId;
  int? fetchedEstimateId;
  int? approvedEstimateId;
  int? returnedEstimateId;
  String? approvedComment;
  String? returnComment;
  int refreshCount = 0;

  @override
  Future<BudgetEstimateSummaryModel> fetchSummary({
    required int projectId,
  }) async {
    final currentError = error;
    if (currentError != null) {
      throw currentError;
    }

    loadedProjectId = projectId;
    refreshCount++;
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

void main() {
  test('loads summary for selected project', () async {
    final repository = _RecordingBudgetRepository();
    final notifier = BudgetEstimatesNotifier(repository);

    notifier.syncProject(9);
    await notifier.loadSummary();

    expect(repository.loadedProjectId, 9);
    expect(notifier.state.summary?.project.name, 'Башня');
    expect(notifier.state.summary?.assignedApprovals.single.id, 17);
    expect(notifier.state.error, isNull);
  });

  test('clears summary when project is not selected', () async {
    final repository = _RecordingBudgetRepository();
    final notifier = BudgetEstimatesNotifier(repository);

    notifier.syncProject(9);
    await notifier.loadSummary();
    notifier.syncProject(null);
    await notifier.loadSummary();

    expect(notifier.state.projectId, isNull);
    expect(notifier.state.summary, isNull);
    expect(repository.refreshCount, 1);
  });

  test('runs approval actions and refreshes summary', () async {
    final repository = _RecordingBudgetRepository();
    final notifier = BudgetEstimatesNotifier(repository)..syncProject(9);

    await notifier.approveEstimate(id: 17, comment: 'Проверено');
    await notifier.requestChanges(id: 17, comment: 'Уточнить объем');

    expect(repository.approvedEstimateId, 17);
    expect(repository.approvedComment, 'Проверено');
    expect(repository.returnedEstimateId, 17);
    expect(repository.returnComment, 'Уточнить объем');
    expect(repository.refreshCount, 2);
  });

  test('marks permission and malformed contract states', () async {
    final denied = BudgetEstimatesNotifier(
      _RecordingBudgetRepository(
        error: const ApiException('Нет доступа', statusCode: 403),
      ),
    )..syncProject(9);
    await denied.loadSummary();

    expect(denied.state.permissionDenied, isTrue);
    expect(denied.state.summary, isNull);

    final malformed = BudgetEstimatesNotifier(
      _RecordingBudgetRepository(error: const FormatException('bad data')),
    )..syncProject(9);
    await malformed.loadSummary();

    expect(malformed.state.malformedContract, isTrue);
    expect(malformed.state.summary, isNull);
  });

  test('loads detail by id', () async {
    final repository = _RecordingBudgetRepository();
    final notifier = BudgetEstimatesNotifier(repository);

    final detail = await notifier.fetchEstimate(17);

    expect(repository.fetchedEstimateId, 17);
    expect(detail.estimate.name, 'Каркас секции А');
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
