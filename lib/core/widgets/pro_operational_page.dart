import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/widgets/pro_page_scaffold.dart';

class ProOperationalPage extends StatelessWidget {
  const ProOperationalPage({
    super.key,
    required this.title,
    required this.children,
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
  final List<Widget>? actions;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ProPageScaffold(
      title: title,
      subtitle: subtitle,
      actions: actions,
      onRefresh: onRefresh,
      floatingActionButton: floatingActionButton,
      padding: padding,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
