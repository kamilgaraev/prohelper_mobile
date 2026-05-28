import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/navigation/mobile_action_recommendation_provider.dart';
import 'package:prohelpers_mobile/core/widgets/mobile_navigation_components.dart';

class SmartActionStrip extends ConsumerWidget {
  const SmartActionStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(mobileRecommendedActionsProvider);

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NavigationSectionHeader(
            title: 'Рекомендуемые действия',
            subtitle: 'Подобрано по роли и текущему объекту',
            icon: Icons.auto_awesome_rounded,
          ),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: actions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final action = actions[index];
                final actionId = action.destination.actionId;
                final isPinned = ref.watch(
                  mobilePinnedActionIdsProvider.select(
                    (ids) => actionId != null && ids.contains(actionId),
                  ),
                );

                return SizedBox(
                  width: 286,
                  child: NavigationActionCard(
                    action: action,
                    compact: true,
                    isPinned: isPinned,
                    onTogglePinned:
                        actionId == null
                            ? null
                            : () => ref
                                .read(mobilePinnedActionIdsProvider.notifier)
                                .toggle(actionId),
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: action.destination.builder,
                          ),
                        ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
