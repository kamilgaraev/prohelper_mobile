import 'dart:math';

sealed class MachineryAction {
  MachineryAction(this.assetId, {String? idempotencyKey})
    : idempotencyKey = idempotencyKey ?? _newIdempotencyKey(assetId);

  final int assetId;
  final String idempotencyKey;

  String get operationType;
  String get method => 'POST';
  String get endpoint;
  Map<String, dynamic> get payload;

  static String _newIdempotencyKey(int assetId) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final entropy = Random.secure().nextInt(0x7fffffff);
    return 'machinery-$assetId-$now-$entropy';
  }
}

final class StartShiftAction extends MachineryAction {
  StartShiftAction(
    super.assetId, {
    required this.assignmentId,
    required this.projectId,
    required this.meterStart,
    this.plannedHours,
    super.idempotencyKey,
  });

  final int assignmentId;
  final int projectId;
  final double meterStart;
  final double? plannedHours;

  @override
  String get operationType => 'start_shift';

  @override
  String get endpoint => '/machinery-operations/shift-reports';

  @override
  Map<String, dynamic> get payload => {
    'asset_id': assetId,
    'project_id': projectId,
    'assignment_id': assignmentId,
    'report_date': DateTime.now().toIso8601String().split('T').first,
    if (plannedHours != null) 'planned_hours': plannedHours,
    'actual_hours': 0,
    'fuel_consumed': 0,
    'meter_start': meterStart,
  };
}

final class FinishShiftAction extends MachineryAction {
  FinishShiftAction(
    super.assetId, {
    required this.shiftId,
    required this.actualHours,
    required this.fuelConsumed,
    required this.meterEnd,
    this.workDescription,
    super.idempotencyKey,
  });

  final int shiftId;
  final double actualHours;
  final double fuelConsumed;
  final double meterEnd;
  final String? workDescription;

  @override
  String get operationType => 'finish_shift';

  @override
  String get endpoint => '/machinery-operations/shift-reports/$shiftId/finish';

  @override
  Map<String, dynamic> get payload => {
    'actual_hours': actualHours,
    'fuel_consumed': fuelConsumed,
    'meter_end': meterEnd,
    if (workDescription?.trim().isNotEmpty ?? false)
      'work_description': workDescription!.trim(),
  };
}

final class SubmitShiftAction extends MachineryAction {
  SubmitShiftAction(
    super.assetId, {
    required this.shiftId,
    super.idempotencyKey,
  });

  final int shiftId;

  @override
  String get operationType => 'submit_shift';

  @override
  String get endpoint => '/machinery-operations/shift-reports/$shiftId/submit';

  @override
  Map<String, dynamic> get payload => const {};
}

final class RecordDowntimeAction extends MachineryAction {
  RecordDowntimeAction(
    super.assetId, {
    required this.projectId,
    required this.shiftId,
    required this.reasonCode,
    required this.startedAt,
    required this.durationMinutes,
    this.comment,
    super.idempotencyKey,
  });

  final int projectId;
  final int shiftId;
  final String reasonCode;
  final DateTime startedAt;
  final int durationMinutes;
  final String? comment;

  @override
  String get operationType => 'record_downtime';

  @override
  String get endpoint => '/machinery-operations/downtimes';

  @override
  Map<String, dynamic> get payload => {
    'asset_id': assetId,
    'project_id': projectId,
    'shift_report_id': shiftId,
    'reason': reasonCode,
    'started_at': startedAt.toUtc().toIso8601String(),
    'duration_minutes': durationMinutes,
    if (comment?.trim().isNotEmpty ?? false) 'comment': comment!.trim(),
  };
}

final class CompleteMaintenanceAction extends MachineryAction {
  CompleteMaintenanceAction(
    super.assetId, {
    required this.orderId,
    this.completionComment,
    super.idempotencyKey,
  });

  final int orderId;
  final String? completionComment;

  @override
  String get operationType => 'complete_maintenance';

  @override
  String get endpoint =>
      '/machinery-operations/maintenance-orders/$orderId/complete';

  @override
  Map<String, dynamic> get payload => {
    if (completionComment?.trim().isNotEmpty ?? false)
      'completion_comment': completionComment!.trim(),
  };
}

final class IssueAssetAction extends MachineryAction {
  IssueAssetAction(
    super.assetId, {
    required this.recipientUserId,
    required this.expectedReturnAt,
    super.idempotencyKey,
  });

  final int recipientUserId;
  final DateTime expectedReturnAt;

  @override
  String get operationType => 'issue_asset';

  @override
  String get endpoint => '/warehouse/custody/issue';

  @override
  Map<String, dynamic> get payload => {
    'organization_asset_id': assetId,
    'responsible_user_id': recipientUserId,
    'expected_return_at': expectedReturnAt.toUtc().toIso8601String(),
  };
}
