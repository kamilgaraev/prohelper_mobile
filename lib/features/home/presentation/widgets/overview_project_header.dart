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

    return ProSurface(
      tone: ProSurfaceTone.tinted,
      padding: const EdgeInsets.all(ProSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(ProRadius.sm),
            ),
            child: Icon(Icons.domain_rounded, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: ProSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Сегодня на объекте', style: AppTypography.caption(context)),
                const SizedBox(height: ProSpacing.xxs),
                Text(
                  project?.name ?? 'Объект не выбран',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h2(context).copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (user?.organizationName != null) ...[
                  const SizedBox(height: ProSpacing.xxs),
                  Text(
                    user!.organizationName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(context),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Сменить объект',
            onPressed: onSwitchProject,
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
        ],
      ),
    );
  }
}
