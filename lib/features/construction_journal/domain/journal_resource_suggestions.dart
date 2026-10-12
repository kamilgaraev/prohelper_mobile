import '../data/construction_journal_models.dart';

class JournalResourceSuggestion {
  const JournalResourceSuggestion({
    required this.key,
    required this.resource,
    required this.quantity,
    this.contractId,
  });

  final String key;
  final ConstructionJournalEstimateResource resource;
  final double quantity;
  final int? contractId;
}

List<JournalResourceSuggestion> journalContractResourceSuggestions(
  Iterable<
    ({
      ConstructionJournalEstimateItemOption item,
      double quantity,
      int? contractId,
    })
  >
  works,
) {
  final groups =
      <
        int?,
        List<({ConstructionJournalEstimateItemOption item, double quantity})>
      >{};
  for (final work in works) {
    (groups[work.contractId] ??= []).add((
      item: work.item,
      quantity: work.quantity,
    ));
  }
  return [
    for (final group in groups.entries)
      for (final suggestion in journalResourceSuggestions(group.value))
        JournalResourceSuggestion(
          key: 'contract:${group.key ?? 'unassigned'}:${suggestion.key}',
          resource: suggestion.resource,
          quantity: suggestion.quantity,
          contractId: group.key,
        ),
  ];
}

List<JournalResourceSuggestion> journalResourceSuggestions(
  Iterable<({ConstructionJournalEstimateItemOption item, double quantity})>
  works,
) {
  final suggestions = <String, JournalResourceSuggestion>{};
  for (final work in works) {
    if (!work.quantity.isFinite || work.quantity <= 0) continue;
    for (final resource in journalResourceComposition(work.item.resources)) {
      final norm = resource.quantityPerUnit;
      if (!resource.hasKnownNorm || norm == null || norm <= 0) {
        continue;
      }
      final key =
          '${resource.resourceType}:${resource.estimateItemId ?? ''}:${resource.materialId ?? ''}:${resource.measurementUnitId ?? resource.measurementUnit?.id ?? resource.unitName ?? ''}:${resource.name}';
      final quantity = norm * work.quantity;
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
    quantity.toStringAsFixed(8).replaceFirst(RegExp(r'\.?0+$'), '');

List<ConstructionJournalEstimateResource> journalResourceComposition(
  Iterable<ConstructionJournalEstimateResource> resources,
) {
  final seen = <String>{};
  return resources
      .where((resource) {
        final source = resource.sourceKey?.trim();
        return seen.add(
          source == null || source.isEmpty ? 'resource:${resource.id}' : source,
        );
      })
      .toList(growable: false);
}

bool journalResourceBasisMatches(
  ConstructionJournalEstimateItemOption item,
  int? measurementUnitId,
) {
  final basis = item.measurementUnitId ?? item.measurementUnit?.id;
  return basis != null && measurementUnitId == basis;
}

bool canUpdateJournalSuggestion(String current, String? previous) =>
    previous != null && current == previous;

String? journalNormHoursPerUnit(double totalHours, String count) {
  final units = int.tryParse(count.trim());
  if (units == null || units <= 0 || !totalHours.isFinite || totalHours < 0) {
    return null;
  }
  return journalSuggestedQuantity(totalHours / units);
}
