String scheduleDisplayName(String name) {
  final shortened = name.trim().replaceFirst(
    RegExp(r'^График работ по смете:\s*', caseSensitive: false),
    '',
  );
  final codeMatch = _scheduleCodePattern.firstMatch(shortened);
  final title =
      (codeMatch == null ? shortened : shortened.substring(codeMatch.end))
          .replaceAll('_', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
  return title.isEmpty ? name.trim().replaceAll('_', ' ') : title;
}

String? scheduleDisplayCode(String name) {
  final shortened = name.trim().replaceFirst(
    RegExp(r'^График работ по смете:\s*', caseSensitive: false),
    '',
  );
  return _scheduleCodePattern
      .firstMatch(shortened)
      ?.group(1)
      ?.replaceAll('_', '.');
}

final _scheduleCodePattern = RegExp(r'^(\d+(?:_\d+)+)_');
