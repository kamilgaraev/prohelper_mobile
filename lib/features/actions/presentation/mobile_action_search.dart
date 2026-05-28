import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';

List<MobileModuleDestination> filterMobileActions(
  List<MobileModuleDestination> destinations,
  String query,
) {
  final normalized = query.trim();
  if (normalized.isEmpty) {
    return destinations;
  }

  return destinations
      .where((destination) => destination.matchesSearch(normalized))
      .toList(growable: false);
}

List<MobileModuleDestination> uniqueDestinations(
  Iterable<MobileModuleDestination?> destinations,
) {
  return destinations
      .whereType<MobileModuleDestination>()
      .fold<List<MobileModuleDestination>>(<MobileModuleDestination>[], (
        items,
        destination,
      ) {
        if (!items.any((item) => item.route == destination.route)) {
          items.add(destination);
        }

        return items;
      });
}
