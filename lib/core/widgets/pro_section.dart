import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';

class ProSectionHeader extends StatelessWidget {
  const ProSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ProSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h2(context),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: ProSpacing.xxs),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(context),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: ProSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class ProSectionBlock extends StatelessWidget {
  const ProSectionBlock({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
    this.spacing = ProSpacing.sm,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProSectionHeader(title: title, subtitle: subtitle, trailing: trailing),
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }
}

class ProSectionDivider extends StatelessWidget {
  const ProSectionDivider({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: indent,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
    );
  }
}
