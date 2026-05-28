import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/navigation/mobile_action_recommendation.dart';
import 'package:prohelpers_mobile/core/widgets/pro_action_tile.dart';
import 'package:prohelpers_mobile/core/widgets/pro_section.dart';

class OverviewNextActions extends StatelessWidget {
  const OverviewNextActions({
    super.key,
    required this.actions,
    required this.onOpen,
    required this.onOpenActionCenter,
  });

  final List<MobileActionRecommendation> actions;
  final ValueChanged<MobileActionRecommendation> onOpen;
  final VoidCallback onOpenActionCenter;

  @override
  Widget build(BuildContext context) {
    return ProSectionBlock(
      title: 'Следующие действия',
      subtitle: 'Пять быстрых входов под вашу роль и текущий объект.',
      trailing: TextButton(
        onPressed: onOpenActionCenter,
        child: const Text('Все'),
      ),
      children:
          actions.isEmpty
              ? [
                ProActionTile(
                  title: 'Открыть центр действий',
                  subtitle: 'Выберите нужный рабочий сценарий вручную.',
                  icon: Icons.bolt_rounded,
                  onTap: onOpenActionCenter,
                ),
              ]
              : [
                for (final action in actions.take(5))
                  ProActionTile(
                    title: action.destination.title,
                    subtitle:
                        action.source == MobileActionSource.pinned
                            ? 'Закреплено'
                            : action.reason,
                    badge:
                        action.source == MobileActionSource.pinned
                            ? 'Закреплено'
                            : null,
                    icon: action.destination.icon,
                    onTap: () => onOpen(action),
                  ),
              ],
    );
  }
}
