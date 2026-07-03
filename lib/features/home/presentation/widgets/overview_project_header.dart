import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';

class OverviewProjectHeader extends StatelessWidget {
  const OverviewProjectHeader({
    super.key,
    required this.project,
    required this.user,
    required this.onSwitchProject,
  });

  final Project? project;
  final User? user;
  final VoidCallback onSwitchProject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final organizationName = user?.organizationName?.trim();
    final projectName = project?.name.trim();
    final projectAddress = project?.address?.trim();
    final hasProject = projectName != null && projectName.isNotEmpty;
    final hasAddress = projectAddress != null && projectAddress.isNotEmpty;

    return ProSurface(
      key: const ValueKey('overview_project_header_surface'),
      tone: ProSurfaceTone.tinted,
      padding: const EdgeInsets.all(ProSpacing.sm),
      onTap: onSwitchProject,
      semanticLabel: _semanticLabel(
        projectName: projectName,
        organizationName: organizationName,
        address: projectAddress,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: ProTouchTarget.min,
            height: ProTouchTarget.min,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(ProRadius.sm),
            ),
            child: Icon(Icons.domain_rounded, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: ProSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    'Текущий объект',
                    if (organizationName != null && organizationName.isNotEmpty)
                      organizationName,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(context),
                ),
                const SizedBox(height: ProSpacing.xxs),
                Text(
                  hasProject ? projectName : 'Объект не выбран',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyLarge(context).copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                if (hasAddress) ...[
                  const SizedBox(height: ProSpacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: ProSpacing.xs),
                      Expanded(
                        child: Text(
                          projectAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: ProSpacing.sm),
          const _SwitchProjectPill(),
        ],
      ),
    );
  }

  String _semanticLabel({
    required String? projectName,
    required String? organizationName,
    required String? address,
  }) {
    final parts = <String>[
      projectName == null || projectName.isEmpty
          ? 'Выбрать объект для работы'
          : 'Сменить текущий объект: $projectName',
      if (organizationName != null && organizationName.isNotEmpty)
        'Организация: $organizationName',
      if (address != null && address.isNotEmpty) 'Адрес: $address',
    ];

    return parts.join('. ');
  }
}

class _SwitchProjectPill extends StatelessWidget {
  const _SwitchProjectPill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: ProTouchTarget.min),
      padding: const EdgeInsets.symmetric(
        horizontal: ProSpacing.sm,
        vertical: ProSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(ProRadius.sm),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.swap_horiz_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: ProSpacing.xs),
          Text(
            'Сменить',
            style: AppTypography.bodySmall(context).copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
