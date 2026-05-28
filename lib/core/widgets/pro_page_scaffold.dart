import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';

class ProPageScaffold extends StatelessWidget {
  const ProPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.onRefresh,
    this.padding = const EdgeInsets.fromLTRB(
      ProSpacing.pageHorizontal,
      ProSpacing.sm,
      ProSpacing.pageHorizontal,
      ProSpacing.bottomNavSafe,
    ),
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Future<void> Function()? onRefresh;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final content = ListView(padding: padding, children: [body]);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AppTypography.h2(context)),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption(context),
              ),
          ],
        ),
        actions: actions,
      ),
      body:
          onRefresh == null
              ? content
              : RefreshIndicator(onRefresh: onRefresh!, child: content),
    );
  }
}
