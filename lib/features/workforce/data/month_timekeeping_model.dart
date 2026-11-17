class TimekeepingPeriod {
  const TimekeepingPeriod({
    required this.id,
    required this.month,
    required this.status,
    required this.revision,
    required this.rows,
    required this.actions,
    required this.documents,
    required this.summary,
    this.projectId,
    this.issues = const [],
  });

  final int id;
  final int? projectId;
  final String month;
  final String status;
  final int revision;
  final List<TimekeepingRow> rows;
  final List<TimekeepingAction> actions;
  final List<TimekeepingDocument> documents;
  final Map<String, dynamic> summary;
  final List<TimekeepingIssue> issues;

  bool get editable =>
      const ['draft', 'submitted', 'verified'].contains(status);
  String get statusLabel => switch (status) {
    'draft' => 'Черновик',
    'submitted' => 'На проверке',
    'verified' => 'Проверен',
    'approved' => 'Утверждён',
    'closed' => 'Закрыт',
    _ => 'Неизвестный статус',
  };

  factory TimekeepingPeriod.fromJson(Map<String, dynamic> json) =>
      TimekeepingPeriod(
        id: (json['id'] as num).toInt(),
        projectId: (json['project_id'] as num?)?.toInt(),
        month: json['month'] as String,
        status: json['status'] as String,
        revision: (json['revision'] as num).toInt(),
        rows: _maps(json['rows']).map(TimekeepingRow.fromJson).toList(),
        actions:
            _maps(json['actions']).map(TimekeepingAction.fromJson).toList(),
        documents:
            _maps(json['documents']).map(TimekeepingDocument.fromJson).toList(),
        summary: Map<String, dynamic>.from(json['summary'] as Map? ?? {}),
        issues: _maps(json['issues']).map(TimekeepingIssue.fromJson).toList(),
      );
}

class TimekeepingRow {
  const TimekeepingRow({
    required this.employeeId,
    required this.name,
    required this.personnelNumber,
    required this.days,
    required this.minutes,
    this.accountingMode,
    this.contractId,
    this.contractNumber,
  });

  final int employeeId;
  final String name;
  final String personnelNumber;
  final String? accountingMode;
  final int? contractId;
  final String? contractNumber;
  final List<TimekeepingDay> days;
  final num minutes;
  bool get hoursOnly => accountingMode == 'hours';
  String get key =>
      '$employeeId:${hoursOnly ? 'hours' : contractId ?? 'unallocated'}';

  factory TimekeepingRow.fromJson(Map<String, dynamic> json) => TimekeepingRow(
    employeeId: (json['employee_id'] as num).toInt(),
    name: json['full_name'] as String,
    personnelNumber: json['personnel_number'] as String? ?? '',
    accountingMode: json['accounting_mode'] as String?,
    contractId: (json['employment_contract_id'] as num?)?.toInt(),
    contractNumber: json['contract_number'] as String?,
    days: _maps(json['days']).map(TimekeepingDay.fromJson).toList(),
    minutes: (json['summary'] as Map?)?['fact_minutes'] as num? ?? 0,
  );
}

class TimekeepingDay {
  const TimekeepingDay({
    required this.date,
    required this.factMinutes,
    required this.plannedMinutes,
    required this.intervals,
    this.comment = '',
    this.absenceCode,
  });
  final String date;
  final num factMinutes;
  final num plannedMinutes;
  final List<Map<String, dynamic>> intervals;
  final String comment;
  final String? absenceCode;

  factory TimekeepingDay.fromJson(Map<String, dynamic> json) => TimekeepingDay(
    date: json['work_date'] as String,
    factMinutes: json['fact_minutes'] as num? ?? 0,
    plannedMinutes: json['planned_minutes'] as num? ?? 0,
    intervals: _maps(json['intervals']).toList(),
    comment: (json['correction'] as Map?)?['comment'] as String? ?? '',
    absenceCode: json['absence_code'] as String?,
  );
}

class TimekeepingAction {
  const TimekeepingAction(this.code, this.enabled, this.reason);
  final String code;
  final bool enabled;
  final String? reason;
  String get label => switch (code) {
    'submit' => 'Отправить на проверку',
    'verify' => 'Подтвердить проверку',
    'approve' => 'Утвердить табель',
    'close' => 'Закрыть табель',
    'reopen' => 'Вернуть в работу',
    _ => 'Действие недоступно',
  };
  String? get permission => switch (code) {
    'submit' || 'reopen' => 'workforce.timekeeping.manage',
    'verify' => 'workforce.timekeeping.verify',
    'approve' => 'workforce.timekeeping.approve',
    'close' => 'workforce.timekeeping.close',
    _ => null,
  };
  factory TimekeepingAction.fromJson(Map<String, dynamic> json) =>
      TimekeepingAction(
        json['code'] as String,
        json['enabled'] == true,
        json['reason'] as String?,
      );
}

class TimekeepingDocument {
  const TimekeepingDocument({
    required this.id,
    required this.revision,
    required this.filename,
    required this.format,
  });
  final int id;
  final int revision;
  final String filename;
  final String format;
  factory TimekeepingDocument.fromJson(Map<String, dynamic> json) =>
      TimekeepingDocument(
        id: (json['id'] as num).toInt(),
        revision: (json['revision'] as num).toInt(),
        filename: json['filename'] as String,
        format: json['format'] as String,
      );
}

class TimekeepingPage {
  const TimekeepingPage(this.periods, this.page, this.lastPage);
  final List<TimekeepingPeriod> periods;
  final int page;
  final int lastPage;
}

class TimekeepingIssue {
  const TimekeepingIssue(this.code, this.blocking, this.employeeId, this.date);
  final String code;
  final bool blocking;
  final int? employeeId;
  final String? date;
  factory TimekeepingIssue.fromJson(Map<String, dynamic> json) =>
      TimekeepingIssue(
        json['code'] as String,
        json['severity'] == 'blocking',
        (json['employee_id'] as num?)?.toInt(),
        json['work_date'] as String?,
      );
  String get label => switch (code) {
    'relation_reconciliation_required' => 'Сверьте вид трудовых отношений',
    'calendar_missing' => 'Назначьте проверенный производственный календарь',
    'schedule_overlap' => 'Устраните пересечение назначений графика',
    'schedule_contract_allocation_required' =>
      'Свяжите график с трудовым договором',
    'absence_not_approved' => 'Согласуйте отсутствие',
    'absence_overlap' => 'Устраните пересечение отсутствий',
    'absence_basis_missing' => 'Укажите основание отсутствия',
    'business_trip_work_review_required' =>
      'Подтвердите основание работы в командировке',
    'business_trip_not_approved' => 'Подтвердите командировку',
    'interval_reconciliation_required' =>
      'Проверьте начало, конец и часовой пояс работы',
    'measured_interval_overlap' => 'Устраните пересечение рабочих интервалов',
    'cross_contract_interval_overlap' =>
      'Устраните пересечение времени по договорам',
    'fact_without_employment_relation' =>
      'Распределите часы по действующему договору',
    'fact_timezone_mismatch' => 'Сверьте часовой пояс с трудовым договором',
    'measured_fact_missing' => 'Добавьте подтверждённый интервал работы',
    'absence_fact_conflict' => 'Сверьте работу с оформленным отсутствием',
    'presence_absence_review_required' =>
      'Проверьте присутствие во время отсутствия',
    'attendance_fact_conflict' => 'Сверьте явку и интервалы работы',
    'civil_not_normative_labor' => 'ГПХ учитывается отдельно от трудовой нормы',
    'overtime_pending_accounting_period' =>
      'Итог сверхурочных определяется после завершения учётного периода',
    'accounting_period_reconciliation_required' =>
      'Подтвердите итог суммированного учёта',
    'accounting_period_allocation_required' =>
      'Распределите сверхурочные по месяцам',
    'weekend_consent_compensation_review_required' =>
      'Подтвердите основание и компенсацию работы в выходной',
    'overtime_consent_basis_review_required' =>
      'Приложите согласие и приказ на сверхурочную работу',
    'annual_overtime_reconciliation_required' =>
      'Подтвердите сверхурочные с начала года',
    'overtime_daily_limit_exceeded' => 'Превышен дневной предел сверхурочных',
    'overtime_two_consecutive_days_limit_exceeded' =>
      'Превышен предел сверхурочных за два дня',
    'overtime_annual_limit_exceeded' => 'Превышен годовой предел сверхурочных',
    'overtime_legal_rule_review_required' =>
      'Проверьте правила сверхурочной работы в настройках организации',
    _ =>
      blocking
          ? 'Требуется исправление данных табеля'
          : 'Проверьте данные табеля',
  };
}

Iterable<Map<String, dynamic>> _maps(dynamic value) => (value as List? ?? [])
    .map((item) => Map<String, dynamic>.from(item as Map));

String timekeepingHours(num minutes) => (minutes / 60)
    .toStringAsFixed(2)
    .replaceFirst(RegExp(r'\.?0+$'), '')
    .replaceAll('.', ',');

int? parseTimekeepingHours(String input) {
  final normalized = input.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,2}(\.\d{1,2})?$').hasMatch(normalized)) return null;
  final hours = double.tryParse(normalized);
  if (hours == null || !hours.isFinite || hours < 0 || hours > 24) return null;
  return (hours * 60).round();
}
