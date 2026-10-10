import '../data/construction_journal_models.dart';

class JournalResourceSuggestion {
  const JournalResourceSuggestion({
    required this.key,
    required this.resource,
    required this.quantity,
  });

  final String key;
  final ConstructionJournalEstimateResource resource;
  final double quantity;
}

List<JournalResourceSuggestion> journalResourceSuggestions(
  Iterable<({ConstructionJournalEstimateItemOption item, double quantity})>
  works,
) {
  final suggestions = <String, JournalResourceSuggestion>{};
  for (final work in works) {
    if (!work.quantity.isFinite || work.quantity <= 0) continue;
    final seen = <int>{};
    for (final resource in work.item.resources) {
      if (!seen.add(resource.id) ||
          !resource.quantityPerUnit.isFinite ||
          resource.quantityPerUnit <= 0) {
        continue;
      }
      final key =
          '${resource.resourceType}:${resource.estimateItemId ?? ''}:${resource.materialId ?? ''}:${resource.measurementUnitId ?? resource.measurementUnit?.id ?? ''}:${resource.name}';
      final quantity = resource.quantityPerUnit * work.quantity;
      suggestions[key] = JournalResourceSuggestion(
        key: key,
        resource: resource,
        quantity: quantity + (suggestions[key]?.quantity ?? 0),
      );
    }
  }
  return suggestions.values.toList(growable: false);
}

String journalSuggestedQuantity(double quantity) =>
    quantity.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');

bool canUpdateJournalSuggestion(String current, String? previous) =>
    previous != null && current == previous;

String? journalNormHoursPerUnit(double totalHours, String count) {
  final units = int.tryParse(count.trim());
  if (units == null || units <= 0 || !totalHours.isFinite || totalHours < 0) {
    return null;
  }
  return journalSuggestedQuantity(totalHours / units);
}
