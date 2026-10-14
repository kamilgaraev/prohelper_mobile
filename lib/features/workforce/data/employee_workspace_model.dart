class EmployeeWorkspaceModel {
  const EmployeeWorkspaceModel({
    required this.employeeName,
    required this.personnelNumber,
    required this.documents,
    required this.requests,
    required this.periods,
    this.workingTimezone,
    this.workingTimezoneDate,
    this.workingContractId,
    this.workingTimezones = const [],
  });

  final String? workingTimezone;
  final String? workingTimezoneDate;
  final int? workingContractId;
  final List<WorkingContractTimezoneModel> workingTimezones;
  final String employeeName;
  final String personnelNumber;
  final List<EmployeeDocumentModel> documents;
  final List<EmployeeRequestModel> requests;
  final List<EmployeeMonthModel> periods;

  factory EmployeeWorkspaceModel.fromJson(Map<String, dynamic> json) {
    final employee = Map<String, dynamic>.from(json['employee'] as Map);
    final facts = Map<String, dynamic>.from(json['monthly_facts'] as Map);
    return EmployeeWorkspaceModel(
      workingTimezone: employee['working_timezone'] as String?,
      workingTimezoneDate: employee['working_timezone_date'] as String?,
      workingContractId: (employee['working_contract_id'] as num?)?.toInt(),
      workingTimezones:
          _maps(
            employee['working_timezones'],
          ).map(WorkingContractTimezoneModel.fromJson).toList(),
      employeeName: employee['full_name'] as String,
      personnelNumber: employee['personnel_number'] as String,
      documents:
          _maps(json['documents']).map(EmployeeDocumentModel.fromJson).toList(),
      requests:
          _maps(json['requests']).map(EmployeeRequestModel.fromJson).toList(),
      periods:
          _maps(facts['periods']).map(EmployeeMonthModel.fromJson).toList(),
    );
  }
}

class EmployeeDocumentModel {
  const EmployeeDocumentModel({
    required this.id,
    required this.title,
    required this.evidenceKind,
  });
  final int id;
  final String title;
  final String evidenceKind;
  factory EmployeeDocumentModel.fromJson(Map<String, dynamic> json) =>
      EmployeeDocumentModel(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String,
        evidenceKind: json['evidence_kind'] as String,
      );
}

class EmployeeRequestModel {
  const EmployeeRequestModel({
    required this.id,
    required this.kind,
    required this.status,
    required this.dateFrom,
    required this.dateTo,
    required this.basis,
    this.managerBasis,
    this.hrBasis,
  });
  final int id;
  final String kind;
  final String status;
  final String dateFrom;
  final String dateTo;
  final String basis;
  final String? managerBasis;
  final String? hrBasis;
  factory EmployeeRequestModel.fromJson(Map<String, dynamic> json) =>
      EmployeeRequestModel(
        id: (json['id'] as num).toInt(),
        kind: json['kind'] as String,
        status: json['status'] as String,
        dateFrom: json['date_from'] as String,
        dateTo: json['date_to'] as String,
        basis: json['basis'] as String,
        managerBasis: json['manager_decision_basis'] as String?,
        hrBasis: json['hr_decision_basis'] as String?,
      );
}

class EmployeeMonthModel {
  const EmployeeMonthModel({
    required this.id,
    required this.status,
    required this.days,
    this.employmentContractId,
    this.contractNumber,
  });
  final int? employmentContractId;
  final String? contractNumber;
  final int id;
  final String status;
  final List<EmployeeDayModel> days;
  factory EmployeeMonthModel.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String;
    if (status != 'approved' && status != 'closed') {
      throw const FormatException(
        'Непроверенный табель нельзя показать как подтверждённый.',
      );
    }
    return EmployeeMonthModel(
      id: (json['id'] as num).toInt(),
      status: status,
      employmentContractId: (json['employment_contract_id'] as num?)?.toInt(),
      contractNumber: json['contract_number'] as String?,
      days: _maps(json['days']).map(EmployeeDayModel.fromJson).toList(),
    );
  }
}

class EmployeeDayModel {
  const EmployeeDayModel({
    required this.date,
    required this.factMinutes,
    required this.plannedMinutes,
  });
  final String date;
  final int factMinutes;
  final int plannedMinutes;
  factory EmployeeDayModel.fromJson(Map<String, dynamic> json) =>
      EmployeeDayModel(
        date: json['work_date'] as String,
        factMinutes: (json['fact_minutes'] as num).toInt(),
        plannedMinutes: (json['planned_minutes'] as num).toInt(),
      );
}

List<Map<String, dynamic>> _maps(dynamic value) =>
    (value as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

class EmployeeRequestPageModel {
  const EmployeeRequestPageModel({
    required this.requests,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
  final List<EmployeeRequestModel> requests;
  final int currentPage;
  final int lastPage;
  final int total;
}

class WorkingContractTimezoneModel {
  const WorkingContractTimezoneModel({
    required this.contractId,
    required this.timezone,
    this.contractNumber,
  });
  final int contractId;
  final String timezone;
  final String? contractNumber;
  factory WorkingContractTimezoneModel.fromJson(Map<String, dynamic> json) =>
      WorkingContractTimezoneModel(
        contractId: (json['employment_contract_id'] as num).toInt(),
        timezone: json['timezone'] as String,
        contractNumber: json['contract_number'] as String?,
      );
}
