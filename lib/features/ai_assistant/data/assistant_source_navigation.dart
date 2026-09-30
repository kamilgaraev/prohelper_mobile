class AssistantSourceTarget {
  const AssistantSourceTarget({
    this.mobileRoute,
    this.webPath,
    required this.label,
    this.projectId,
  });

  final String? mobileRoute;
  final String? webPath;
  final String label;
  final String? projectId;
}

final _projectIdPattern = RegExp(
  r'^(?:[1-9]\d*|[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}|[0-9A-HJKMNP-TV-Z]{26})$',
  caseSensitive: false,
);

AssistantSourceTarget? resolveAssistantSourceTarget(
  String? value, {
  required String sourceBaseUrl,
  String? projectId,
}) {
  if ((value == null || value.trim().isEmpty) && projectId != null &&
      _projectIdPattern.hasMatch(projectId)) {
    return AssistantSourceTarget(
      webPath: '/dashboard/projects/${Uri.encodeComponent(projectId)}',
      label: 'Открыть проект',
      projectId: projectId,
    );
  }
  if (value == null || value.trim().isEmpty) return null;

  final base = Uri.tryParse(sourceBaseUrl);
  final source = Uri.tryParse(value.trim());
  if (base == null || source == null || !base.hasAuthority) return null;
  if (source.hasScheme || source.hasAuthority) {
    if ((source.scheme != 'https' && source.scheme != 'http') ||
        source.host != base.host ||
        source.port != base.port ||
        source.userInfo.isNotEmpty) {
      return null;
    }
  } else if (!value.trim().startsWith('/') || value.trim().startsWith('//')) {
    return null;
  }

  final resolved = base.resolveUri(source);
  final path = resolved.path;
  final projectPath = RegExp(
    r'^/(?:dashboard/)?projects/([^/]+)(?:/video-monitoring)?/?$',
  ).firstMatch(path);
  final pathProjectId = projectPath?.group(1);
  final resolvedProjectId = projectId ?? pathProjectId;
  final safeProjectId = resolvedProjectId != null &&
          _projectIdPattern.hasMatch(resolvedProjectId)
      ? resolvedProjectId
      : null;

  final projectVideo = path.endsWith('/video-monitoring') && safeProjectId != null;
  if (projectVideo) {
    return AssistantSourceTarget(
      mobileRoute: 'video-monitoring',
      label: 'Открыть раздел «Видеонаблюдение»',
      projectId: safeProjectId,
    );
  }

  if (RegExp(r'^/(?:dashboard/)?projects/[^/]+/?$').hasMatch(path) &&
      safeProjectId != null) {
    return AssistantSourceTarget(
      webPath: '/dashboard/projects/${Uri.encodeComponent(safeProjectId)}',
      label: 'Открыть проект',
      projectId: safeProjectId,
    );
  }

  const moduleRoutes = <String, String>{
    '/crm': 'crm',
    '/tenders': 'tenders',
    '/payments': 'payments',
    '/budgeting': 'budgeting',
    '/integrations/1c': 'one-c-basic-exchange',
    '/design-management': 'design-management',
    '/executive-documentation': 'executive-documentation',
    '/brigades': 'brigades',
    '/brigades/catalog': 'brigades',
    '/brigades/requests': 'brigades',
    '/brigades/assignments': 'brigades',
    '/brigades/invitations': 'brigades',
    '/workforce': 'workforce-management',
    '/production-labor': 'production-labor',
    '/materials': 'catalog-management',
    '/work-types': 'catalog-management',
    '/measurement-units': 'catalog-management',
    '/catalogs/materials': 'catalog-management',
    '/catalogs/work-types': 'catalog-management',
    '/catalogs/measurement-units': 'catalog-management',
    '/report-templates': 'report-templates',
  };
  final matchedRoute = moduleRoutes.entries
      .where((entry) => path == entry.key || path.startsWith('${entry.key}/'))
      .map((entry) => entry.value)
      .firstOrNull;
  if (matchedRoute != null) {
    return AssistantSourceTarget(
      mobileRoute: matchedRoute,
      label: 'Открыть раздел',
      projectId: safeProjectId,
    );
  }

  if (safeProjectId != null) {
    return AssistantSourceTarget(
      webPath: '/dashboard/projects/${Uri.encodeComponent(safeProjectId)}',
      label: 'Открыть проект',
      projectId: safeProjectId,
    );
  }
  return null;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
