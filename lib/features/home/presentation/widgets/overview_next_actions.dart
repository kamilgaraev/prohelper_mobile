import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_action_recommendation.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/pro_section.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';

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
    void openAllActions() {
      HapticFeedback.selectionClick();
      onOpenActionCenter();
    }

    final visibleActionCount =
        actions.isEmpty ? 0 : (actions.length > 5 ? 5 : actions.length);
    final rows =
        actions.isEmpty
            ? <_OverviewActionRow>[
              _OverviewActionRow(
                title: 'Открыть центр действий',
                subtitle: 'Выберите нужный рабочий сценарий вручную.',
                icon: Icons.bolt_rounded,
                onTap: onOpenActionCenter,
              ),
            ]
            : [
              for (final action in actions.take(5))
                _OverviewActionRow(
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
            ];

    return ProSurface(
      tone: ProSurfaceTone.elevated,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ProSpacing.md,
              ProSpacing.md,
              ProSpacing.md,
              0,
            ),
            child: ProSectionHeader(
              title: 'Следующие действия',
              subtitle: _nextActionsSubtitle(visibleActionCount),
              trailing: Semantics(
                container: true,
                button: true,
                enabled: true,
                excludeSemantics: true,
                label: 'Открыть все действия',
                onTap: openAllActions,
                child: TextButton(
                  onPressed: openAllActions,
                  child: const Text('Все'),
                ),
              ),
            ),
          ),
          const ProSectionDivider(indent: ProSpacing.md),
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index != rows.length - 1) const ProSectionDivider(indent: 72),
          ],
        ],
      ),
    );
  }
}

String _nextActionsSubtitle(int visibleActionCount) {
  if (visibleActionCount <= 0) {
    return 'Откройте центр действий или выберите рабочий сценарий вручную.';
  }

  if (visibleActionCount == 1) {
    return '1 быстрый вход по вашим правам и текущему объекту.';
  }

  if (visibleActionCount < 5) {
    return '$visibleActionCount быстрых входа по вашим правам и текущему объекту.';
  }

  return '$visibleActionCount быстрых входов по вашим правам и текущему объекту.';
}

class _OverviewActionRow extends StatelessWidget {
  const _OverviewActionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final String? badge;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = proStatusStyle(context, ProStatusTone.info);
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      button: true,
      enabled: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(ProSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: status.background,
                  borderRadius: BorderRadius.circular(ProRadius.sm),
                ),
                child: Icon(icon, color: status.foreground, size: 22),
              ),
              const SizedBox(width: ProSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium(
                              context,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: ProSpacing.xs),
                          _OverviewActionBadge(
                            label: badge!,
                            color: status.foreground,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: ProSpacing.xxs),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ProSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewActionBadge extends StatelessWidget {
  const _OverviewActionBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ProSpacing.xs,
        vertical: ProSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ProRadius.pill),
      ),
      child: Text(
        label,
        style: AppTypography.caption(
          context,
        ).copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}
