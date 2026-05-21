import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/widgets/app_action_buttons.dart';

class ProButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Widget? icon;
  final bool isLoading;

  const ProButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.backgroundColor,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppPrimaryActionButton(
      label: text,
      onPressed: onPressed,
      leading: icon,
      isBusy: isLoading,
      backgroundColor: backgroundColor,
    );
  }
}
