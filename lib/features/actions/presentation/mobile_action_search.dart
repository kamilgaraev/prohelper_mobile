import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';

import 'package:prohelpers_mobile/core/navigation/mobile_navigation_registry.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/features/modules/data/mobile_module_model.dart';

List<MobileModuleDestination> visibleMobileDestinations(
  Iterable<MobileModuleModel> modules,
) {
  final visible = <MobileModuleDestination?>[];
  for (final module in modules) {
    final destination =
        MobileNavigationRegistry.destinationForRoute(module.route) ??
        MobileNavigationRegistry.destinationForRoute(module.slug);
    if (destination != null &&
        destination.allowsPermissions(module.permissions)) {
      visible.add(destination);
    }

    final appModule = AppModuleX.fromSlug(module.slug);
    if (appModule == null) {
      continue;
    }
    for (final secondary in MobileNavigationRegistry.destinations.where(
      (item) => item.isSecondary && item.appModule == appModule,
    )) {
      if (secondary.allowsPermissions(module.permissions)) {
        visible.add(secondary);
      }
    }
  }
  return uniqueDestinations(visible);
}

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
