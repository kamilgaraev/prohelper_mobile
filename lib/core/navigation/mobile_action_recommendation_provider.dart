import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/providers/context_provider.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_widget_model.dart';
import 'package:prohelpers_mobile/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:prohelpers_mobile/features/notifications/domain/notifications_provider.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

import 'mobile_action_recommendation.dart';
import 'mobile_navigation_registry.dart';

final mobilePinnedActionIdsProvider =
    StateNotifierProvider<MobilePinnedActionIdsNotifier, List<String>>((ref) {
      return MobilePinnedActionIdsNotifier(ref.read(secureStorageProvider));
    });

final mobileRecommendedActionsProvider =
    Provider<List<MobileActionRecommendation>>((ref) {
      final permissions = ref.watch(permissionServiceProvider);
      final userContext = ref.watch(userContextProvider);
      final selectedProject = ref.watch(projectsProvider).selectedProject;
      final pinnedActionIds = ref.watch(mobilePinnedActionIdsProvider);
      final urgency = _MobileUrgency.fromRef(ref);

      return MobileActionRecommender.recommend(
        destinations: MobileNavigationRegistry.destinations,
        context: MobileRecommendationContext(
          permissions: permissions,
          userContext: userContext,
          hasSelectedProject: selectedProject != null,
          pinnedActionIds: pinnedActionIds,
          urgencyScores: urgency.scores,
          reasonOverrides: urgency.reasons,
        ),
      );
    });

class MobilePinnedActionIdsNotifier extends StateNotifier<List<String>> {
  MobilePinnedActionIdsNotifier(this._storage) : super(const []) {
    _load();
  }

  final SecureStorageService _storage;

  Future<void> _load() async {
    try {
      final ids = await _storage.getPinnedMobileActionIds();
      if (mounted) {
        state = ids.take(2).toList(growable: false);
      }
    } on MissingPluginException {
      if (mounted) {
        state = const [];
      }
    } catch (_) {
      if (mounted) {
        state = const [];
      }
    }
  }

  Future<void> toggle(String actionId) async {
    final normalized = actionId.trim();
    if (normalized.isEmpty) {
      return;
    }

    final next = [...state];
    if (next.contains(normalized)) {
      next.remove(normalized);
    } else {
      next.remove(normalized);
      next.insert(0, normalized);
      if (next.length > 2) {
        next.removeRange(2, next.length);
      }
    }

    state = List.unmodifiable(next);

    try {
      await _storage.savePinnedMobileActionIds(state);
    } on MissingPluginException {
      return;
    } catch (_) {
      return;
    }
  }

  bool isPinned(String? actionId) {
    return actionId != null && state.contains(actionId);
  }
}

class _MobileUrgency {
  const _MobileUrgency({required this.scores, required this.reasons});

  final Map<String, int> scores;
  final Map<String, String> reasons;

  static _MobileUrgency fromRef(Ref ref) {
    final scores = <String, int>{};
    final reasons = <String, String>{};
    final unreadCount = ref.watch(
      notificationsProvider.select((state) => state.unreadCount),
    );

    if (unreadCount > 0) {
      scores['approve_request'] = unreadCount * 10;
      reasons['approve_request'] =
          unreadCount == 1
              ? '1 уведомление требует внимания'
              : '$unreadCount уведомлений требуют внимания';
    }

    final widgets = ref.watch(
      dashboardControllerProvider.select((state) => state.widgets),
    );

    for (final widget in widgets) {
      final destination =
          MobileNavigationRegistry.destinationForRoute(widget.route) ??
          MobileNavigationRegistry.destinationForRoute(widget.slug);
      final actionId = destination?.actionId;
      if (actionId == null) {
        continue;
      }

      final score = _statusWeight(widget.status) + _metricWeight(widget);
      if (score <= 0) {
        continue;
      }

      scores[actionId] = math.max(scores[actionId] ?? 0, score);
      reasons.putIfAbsent(actionId, () {
        final value = _metricValue(widget.primaryMetric.value);
        if (value > 0) {
          return '$value ${widget.primaryMetric.label.toLowerCase()}';
        }

        return switch (widget.status) {
          DashboardWidgetStatus.critical => 'Есть критичные вопросы',
          DashboardWidgetStatus.attention => 'Требует внимания',
          DashboardWidgetStatus.active => 'Есть активные задачи',
          DashboardWidgetStatus.ok => destination!.recommendedReason,
        };
      });
    }

    return _MobileUrgency(
      scores: Map.unmodifiable(scores),
      reasons: Map.unmodifiable(reasons),
    );
  }

  static int _statusWeight(DashboardWidgetStatus status) {
    return switch (status) {
      DashboardWidgetStatus.critical => 80,
      DashboardWidgetStatus.attention => 50,
      DashboardWidgetStatus.active => 12,
      DashboardWidgetStatus.ok => 0,
    };
  }

  static int _metricWeight(DashboardWidgetModel widget) {
    return math.min(
      40,
      _metricValue(widget.primaryMetric.value) +
          _metricValue(widget.secondaryMetric.value),
    );
  }

  static int _metricValue(Object value) {
    if (value is int) {
      return value.abs();
    }

    if (value is num) {
      return value.abs().round();
    }

    return 0;
  }
}
