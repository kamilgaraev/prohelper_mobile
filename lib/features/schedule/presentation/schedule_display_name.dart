String scheduleDisplayName(String name) {
  final readable = name
      .trim()
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  final shortened = readable.replaceFirst(
    RegExp(r'^График работ по смете:\s*', caseSensitive: false),
    '',
  );
  return shortened.isEmpty ? readable : shortened;
}
