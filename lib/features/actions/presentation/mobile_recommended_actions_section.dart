import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/navigation/mobile_action_recommendation.dart';
import 'package:prohelpers_mobile/core/widgets/pro_action_tile.dart';
import 'package:prohelpers_mobile/core/widgets/pro_section.dart';

class MobileRecommendedActionsSection extends StatelessWidget {
  const MobileRecommendedActionsSection({
    super.key,
    required this.actions,
    required this.onOpen,
    this.title = 'Рекомендуемые',
    this.subtitle = 'Самые полезные действия для текущей роли и объекта.',
  });

  final List<MobileActionRecommendation> actions;
  final ValueChanged<MobileActionRecommendation> onOpen;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ProSectionBlock(
      title: title,
      subtitle: subtitle,
      children:
          actions.isEmpty
              ? [
                const ProActionTile(
                  title: 'Рекомендации появятся после загрузки данных',
                  subtitle: 'Пока можно открыть нужный раздел через поиск.',
                  icon: Icons.auto_awesome_outlined,
                  onTap: null,
                ),
              ]
              : [
                for (final action in actions.take(5))
                  ProActionTile(
                    title: action.destination.shortTitle,
                    subtitle:
                        action.source == MobileActionSource.pinned
                            ? 'Закреплено'
                            : action.destination.title ==
                                action.destination.shortTitle
                            ? action.reason
                            : '${action.destination.title} · ${action.reason}',
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
