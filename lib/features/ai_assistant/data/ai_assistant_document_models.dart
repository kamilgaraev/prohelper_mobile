class AiDocumentProcessingStatus {
  const AiDocumentProcessingStatus({
    required this.statusAvailable,
    required this.documentCoverage,
    required this.archiveScan,
    required this.canManageSettings,
    required this.coverageComplete,
    required this.processing,
  });
  final bool statusAvailable;
  final Map<String, int> documentCoverage;
  final AiArchiveScan archiveScan;
  final bool canManageSettings;
  final bool coverageComplete;
  final bool processing;
  factory AiDocumentProcessingStatus.fromJson(Map<String, dynamic> json) {
    final documents =
        json['document_coverage'] is Map
            ? json['document_coverage'] as Map
            : const {};
    final archive =
        json['archive_scan'] is Map ? json['archive_scan'] as Map : const {};
    return AiDocumentProcessingStatus(
      statusAvailable: json['status_available'] != false,
      documentCoverage: {
        for (final key in const [
          'total',
          'ready',
          'pending',
          'ocr_required',
          'ocr_processing',
          'failed',
          'unsupported',
          'empty',
          'processed_units',
          'total_pages',
          'ocr_completed_pages',
        ])
          key: _count(documents[key]),
      },
      archiveScan: AiArchiveScan(
        expected: _count(archive['expected_file_count']),
        scanned: _count(archive['scanned_file_count']),
        processing: archive['processing'] == true,
        completedAt: DateTime.tryParse(
          archive['completed_at']?.toString() ?? '',
        ),
      ),
      canManageSettings: json['can_manage_document_settings'] == true,
      coverageComplete: json['coverage_complete'] == true,
      processing: json['processing'] == true,
    );
  }
}

class AiArchiveScan {
  const AiArchiveScan({
    required this.expected,
    required this.scanned,
    required this.processing,
    this.completedAt,
  });
  final int expected;
  final int scanned;
  final bool processing;
  final DateTime? completedAt;
}

class AiDocumentBudget {
  const AiDocumentBudget({
    required this.enabled,
    required this.scope,
    required this.limitMinor,
    required this.spentMinor,
    required this.reservedMinor,
    required this.availableMinor,
  });
  final bool enabled;
  final String scope;
  final int limitMinor;
  final int spentMinor;
  final int reservedMinor;
  final int availableMinor;
  factory AiDocumentBudget.fromJson(Map<String, dynamic> json) =>
      AiDocumentBudget(
        enabled: json['enabled'] == true,
        scope: json['scope'] == 'archive' ? 'archive' : 'new',
        limitMinor: _count(json['limit_minor']),
        spentMinor: _count(json['spent_minor']),
        reservedMinor: _count(json['reserved_minor']),
        availableMinor: _count(json['available_minor']),
      );
}

int _count(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;
