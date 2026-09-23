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
    this.floatingActionButton,
    this.padding = const EdgeInsets.fromLTRB(
      ProSpacing.pageHorizontal,
      ProSpacing.md,
      ProSpacing.pageHorizontal,
      ProSpacing.bottomNavSafe,
    ),
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Future<void> Function()? onRefresh;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolbarHeight = _toolbarHeight(
      context,
      hasSubtitle: subtitle != null,
    );
    final content = ListView(padding: padding, children: [body]);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        centerTitle: false,
        scrolledUnderElevation: 0,
        toolbarHeight: toolbarHeight,
        shape: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.22),
            width: 0.5,
          ),
        ),
        surfaceTintColor: Colors.transparent,
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
      floatingActionButton: floatingActionButton,
      body:
          onRefresh == null
              ? content
              : RefreshIndicator(onRefresh: onRefresh!, child: content),
    );
  }
}

double _toolbarHeight(BuildContext context, {required bool hasSubtitle}) {
  const verticalPadding = ProSpacing.sm * 2;
  const subtitleGap = ProSpacing.xxs;
  final textScaler = MediaQuery.textScalerOf(context);
  final titleHeight = _scaledLineHeight(textScaler, AppTypography.h2(context));
  final subtitleHeight =
      hasSubtitle
          ? subtitleGap +
              _scaledLineHeight(textScaler, AppTypography.caption(context))
          : 0;

  final contentHeight = titleHeight + subtitleHeight + verticalPadding;
  return contentHeight < kToolbarHeight ? kToolbarHeight : contentHeight;
}

double _scaledLineHeight(TextScaler textScaler, TextStyle style) {
  final fontSize = style.fontSize ?? 14;
  final lineHeight = style.height ?? 1.2;

  return textScaler.scale(fontSize) * lineHeight;
}
