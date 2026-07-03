import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';

class NotificationActionButton extends StatelessWidget {
  const NotificationActionButton({
    super.key,
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = _actionLabel(unreadCount);

    return Padding(
      padding: const EdgeInsets.only(right: ProSpacing.xs),
      child: Semantics(
        label: label,
        button: true,
        onTap: onPressed,
        child: ExcludeSemantics(
          child: IconButton(
            tooltip: label,
            onPressed: onPressed,
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
        ),
      ),
    );
  }
}

String _actionLabel(int unreadCount) {
  if (unreadCount <= 0) {
    return 'Открыть уведомления';
  }

  return 'Открыть уведомления, непрочитанных: $unreadCount';
}
