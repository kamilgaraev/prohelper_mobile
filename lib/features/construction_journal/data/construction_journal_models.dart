class JournalPaginationMeta {
  const JournalPaginationMeta({
    required this.currentPage,
    required this.perPage,
    required this.lastPage,
    required this.total,
  });

  final int currentPage;
  final int perPage;
  final int lastPage;
  final int total;

  factory JournalPaginationMeta.fromJson(Map<String, dynamic> json) {
    return JournalPaginationMeta(
      currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
      perPage: (json['per_page'] as num?)?.toInt() ?? 0,
      lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class ConstructionJournalSummary {
  const ConstructionJournalSummary({
    this.totalJournals = 0,
    this.activeJournals = 0,
    this.archivedJournals = 0,
    this.closedJournals = 0,
    this.totalEntries = 0,
    this.approvedEntries = 0,
    this.submittedEntries = 0,
    this.rejectedEntries = 0,
  });

  final int totalJournals;
  final int activeJournals;
  final int archivedJournals;
  final int closedJournals;
  final int totalEntries;
  final int approvedEntries;
  final int submittedEntries;
  final int rejectedEntries;

  factory ConstructionJournalSummary.fromJson(Map<String, dynamic> json) {
    return ConstructionJournalSummary(
      totalJournals: (json['total_journals'] as num?)?.toInt() ?? 0,
      activeJournals: (json['active_journals'] as num?)?.toInt() ?? 0,
      archivedJournals: (json['archived_journals'] as num?)?.toInt() ?? 0,
      closedJournals: (json['closed_journals'] as num?)?.toInt() ?? 0,
      totalEntries: (json['total_entries'] as num?)?.toInt() ?? 0,
      approvedEntries: (json['approved_entries'] as num?)?.toInt() ?? 0,
      submittedEntries: (json['submitted_entries'] as num?)?.toInt() ?? 0,
      rejectedEntries: (json['rejected_entries'] as num?)?.toInt() ?? 0,
    );
  }
}

class ConstructionJournalProjectRef {
  const ConstructionJournalProjectRef({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory ConstructionJournalProjectRef.fromJson(Map<String, dynamic> json) {
    return ConstructionJournalProjectRef(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
    );
  }
}

class ConstructionJournalModel {
  const ConstructionJournalModel({
    required this.id,
    required this.projectId,
    required this.name,
    required this.journalNumber,
    required this.startDate,
    required this.status,
    this.endDate,
    this.project,
    this.contractNumber,
    this.createdByName,
    this.totalEntries = 0,
    this.approvedEntries = 0,
    this.submittedEntries = 0,
    this.rejectedEntries = 0,
    this.availableActions = const [],
  });

  final int id;
  final int projectId;
  final String name;
  final String journalNumber;
  final String startDate;
  final String? endDate;
  final String status;
  final ConstructionJournalProjectRef? project;
  final String? contractNumber;
  final String? createdByName;
  final int totalEntries;
  final int approvedEntries;
  final int submittedEntries;
  final int rejectedEntries;
  final List<String> availableActions;

  factory ConstructionJournalModel.fromJson(Map<String, dynamic> json) {
    final projectPayload = json['project'];
    final contractPayload = json['contract'];
    final createdByPayload = json['createdBy'];

    return ConstructionJournalModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      projectId: (json['project_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      journalNumber: json['journal_number'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String?,
      status: json['status'] as String? ?? '',
      project: projectPayload is Map<String, dynamic>
          ? ConstructionJournalProjectRef.fromJson(projectPayload)
          : projectPayload is Map
              ? ConstructionJournalProjectRef.fromJson(
                  projectPayload.map((key, value) => MapEntry(key.toString(), value)),
                )
              : null,
      contractNumber: contractPayload is Map ? contractPayload['number'] as String? : null,
      createdByName: createdByPayload is Map ? createdByPayload['name'] as String? : null,
      totalEntries: (json['total_entries'] as num?)?.toInt() ?? 0,
      approvedEntries: (json['approved_entries'] as num?)?.toInt() ?? 0,
      submittedEntries: (json['submitted_entries'] as num?)?.toInt() ?? 0,
      rejectedEntries: (json['rejected_entries'] as num?)?.toInt() ?? 0,
      availableActions: _parseActions(json['available_actions']),
    );
  }
}

class ConstructionJournalEntryModel {
  const ConstructionJournalEntryModel({
    required this.id,
    required this.journalId,
    required this.entryDate,
    required this.entryNumber,
    required this.workDescription,
    required this.status,
    this.rejectionReason,
    this.createdByName,
    this.approvedByName,
    this.problemsDescription,
    this.safetyNotes,
    this.visitorsNotes,
    this.qualityNotes,
    this.availableActions = const [],
  });

  final int id;
  final int journalId;
  final String entryDate;
  final int entryNumber;
  final String workDescription;
  final String status;
  final String? rejectionReason;
  final String? createdByName;
  final String? approvedByName;
  final String? problemsDescription;
  final String? safetyNotes;
  final String? visitorsNotes;
  final String? qualityNotes;
  final List<String> availableActions;

  factory ConstructionJournalEntryModel.fromJson(Map<String, dynamic> json) {
    final createdByPayload = json['createdBy'];
    final approvedByPayload = json['approvedBy'];

    return ConstructionJournalEntryModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      journalId: (json['journal_id'] as num?)?.toInt() ?? 0,
      entryDate: json['entry_date'] as String? ?? '',
      entryNumber: (json['entry_number'] as num?)?.toInt() ?? 0,
      workDescription: json['work_description'] as String? ?? '',
      status: json['status'] as String? ?? '',
      rejectionReason: json['rejection_reason'] as String?,
      createdByName: createdByPayload is Map ? createdByPayload['name'] as String? : null,
      approvedByName: approvedByPayload is Map ? approvedByPayload['name'] as String? : null,
      problemsDescription: json['problems_description'] as String?,
      safetyNotes: json['safety_notes'] as String?,
      visitorsNotes: json['visitors_notes'] as String?,
      qualityNotes: json['quality_notes'] as String?,
      availableActions: _parseActions(json['available_actions']),
    );
  }
}

class ConstructionJournalListPayload {
  const ConstructionJournalListPayload({
    required this.items,
    required this.meta,
    required this.summary,
    required this.availableActions,
    this.project,
  });

  final List<ConstructionJournalModel> items;
  final JournalPaginationMeta meta;
  final ConstructionJournalSummary summary;
  final List<String> availableActions;
  final ConstructionJournalProjectRef? project;
}

class ConstructionJournalDetailPayload {
  const ConstructionJournalDetailPayload({
    required this.journal,
    required this.entries,
    required this.entriesMeta,
    required this.entriesSummary,
    required this.availableActions,
  });

  final ConstructionJournalModel journal;
  final List<ConstructionJournalEntryModel> entries;
  final JournalPaginationMeta entriesMeta;
  final ConstructionJournalSummary entriesSummary;
  final List<String> availableActions;
}

List<String> _parseActions(dynamic payload) {
  if (payload is! List) {
    return const [];
  }

  return payload.whereType<String>().toList();
}
