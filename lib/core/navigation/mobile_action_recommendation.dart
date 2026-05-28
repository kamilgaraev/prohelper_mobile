import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';

enum MobileActionSource { pinned, system }

class MobileActionRecommendation {
  const MobileActionRecommendation({
    required this.destination,
    required this.score,
    required this.reason,
    required this.source,
  });

  final MobileModuleDestination destination;
  final int score;
  final String reason;
  final MobileActionSource source;
}

class MobileRecommendationContext {
  const MobileRecommendationContext({
    required this.permissions,
    required this.userContext,
    required this.hasSelectedProject,
    required this.pinnedActionIds,
    required this.urgencyScores,
    this.reasonOverrides = const <String, String>{},
  });

  final PermissionService permissions;
  final UserContext userContext;
  final bool hasSelectedProject;
  final List<String> pinnedActionIds;
  final Map<String, int> urgencyScores;
  final Map<String, String> reasonOverrides;
}

class MobileActionRecommender {
  const MobileActionRecommender._();

  static List<MobileActionRecommendation> recommend({
    required List<MobileModuleDestination> destinations,
    required MobileRecommendationContext context,
  }) {
    final eligible = destinations
        .where((destination) {
          final actionId = destination.actionId;
          final module = destination.appModule;

          if (actionId == null || module == null) {
            return false;
          }

          if (destination.requiresProject && !context.hasSelectedProject) {
            return false;
          }

          return context.permissions.canAccessModule(module) &&
              context.permissions.canProcessAction(actionId);
        })
        .toList(growable: false);

    final pinned = <MobileActionRecommendation>[];
    for (final actionId in context.pinnedActionIds.take(2)) {
      MobileModuleDestination? destination;
      for (final item in eligible) {
        if (item.actionId == actionId) {
          destination = item;
          break;
        }
      }

      if (destination == null) {
        continue;
      }

      pinned.add(
        MobileActionRecommendation(
          destination: destination,
          score: _score(destination, context) + 1000,
          reason: 'Закреплено',
          source: MobileActionSource.pinned,
        ),
      );
    }

    final pinnedIds = pinned.map((item) => item.destination.actionId).toSet();
    final system =
        eligible
            .where((destination) => !pinnedIds.contains(destination.actionId))
            .map(
              (destination) => MobileActionRecommendation(
                destination: destination,
                score: _score(destination, context),
                reason: _reason(destination, context),
                source: MobileActionSource.system,
              ),
            )
            .toList()
          ..sort((left, right) {
            final scoreCompare = right.score.compareTo(left.score);
            if (scoreCompare != 0) {
              return scoreCompare;
            }

            return left.destination.title.compareTo(right.destination.title);
          });

    return <MobileActionRecommendation>[
      ...pinned,
      ...system,
    ].take(5).toList(growable: false);
  }

  static int _score(
    MobileModuleDestination destination,
    MobileRecommendationContext context,
  ) {
    final actionId = destination.actionId;
    final urgency = actionId == null ? 0 : context.urgencyScores[actionId] ?? 0;
    final contextBonus =
        destination.preferredContexts.contains(context.userContext) ? 40 : 0;

    return destination.basePriority + urgency + contextBonus;
  }

  static String _reason(
    MobileModuleDestination destination,
    MobileRecommendationContext context,
  ) {
    final actionId = destination.actionId;
    final reasonOverride = context.reasonOverrides[actionId];
    if (reasonOverride != null && reasonOverride.trim().isNotEmpty) {
      return reasonOverride;
    }

    final urgency = actionId == null ? 0 : context.urgencyScores[actionId] ?? 0;

    if (urgency > 0) {
      return '$urgency требуют внимания';
    }

    return destination.recommendedReason;
  }
}
