import 'package:flutter/material.dart';

import '../../../../core/design/pro_status.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/industrial_card.dart';
import '../../data/notification_model.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    this.onMarkRead,
  });

  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusStyle = proStatusStyle(
      context,
      _priorityTone(notification.priority),
    );
    final color = statusStyle.foreground;
    final actionContext = _actionContext(notification);
    final markRead = onMarkRead;

    return IndustrialCard(
      borderColor: notification.isUnread ? color.withValues(alpha: 0.45) : null,
      backgroundColor: notification.isUnread ? statusStyle.background : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_iconFor(notification.category), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: AppTypography.bodyLarge(context).copyWith(
                        fontWeight:
                            notification.isUnread
                                ? FontWeight.w900
                                : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium(
                        context,
                      ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (notification.isUnread)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Pill(label: _categoryLabel(notification.category), color: color),
              _Pill(
                label: _formatDateTime(notification.createdAt),
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _NotificationCardActionButton(
                  semanticsLabel: 'Открыть уведомление: $actionContext',
                  onPressed: onTap,
                  child: TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Открыть'),
                  ),
                ),
                if (notification.isUnread && markRead != null)
                  _NotificationCardActionButton(
                    semanticsLabel:
                        'Отметить уведомление прочитанным: $actionContext',
                    onPressed: markRead,
                    child: TextButton.icon(
                      onPressed: markRead,
                      icon: const Icon(Icons.done_rounded, size: 18),
                      label: const Text('Отметить прочитанным'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCardActionButton extends StatelessWidget {
  const _NotificationCardActionButton({
    required this.semanticsLabel,
    required this.onPressed,
    required this.child,
  });

  final String semanticsLabel;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: true,
      excludeSemantics: true,
      label: semanticsLabel,
      onTap: onPressed,
      child: child,
    );
  }
}

String _actionContext(NotificationModel notification) {
  final createdAt = notification.createdAt;
  if (createdAt == null) {
    return notification.title;
  }

  return '${notification.title}, ${_formatDateTime(createdAt)}';
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.caption(
          context,
        ).copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

IconData _iconFor(String category) {
  return switch (category.trim().toLowerCase()) {
    'security' => Icons.shield_outlined,
    'warning' => Icons.warning_amber_rounded,
    'error' => Icons.error_outline_rounded,
    'procurement' => Icons.inventory_2_outlined,
    'schedule' => Icons.timeline_rounded,
    'warehouse' => Icons.warehouse_outlined,
    _ => Icons.notifications_none_rounded,
  };
}

ProStatusTone _priorityTone(String priority) {
  return switch (priority.trim().toLowerCase()) {
    'critical' => ProStatusTone.danger,
    'high' => ProStatusTone.warning,
    'low' => ProStatusTone.success,
    _ => ProStatusTone.info,
  };
}

String _categoryLabel(String category) {
  return switch (category.trim().toLowerCase()) {
    'security' => 'Безопасность',
    'warning' => 'Внимание',
    'error' => 'Важно',
    'procurement' => 'Закупки',
    'schedule' => 'График',
    'warehouse' => 'Склад',
    'general' => 'Общее',
    _ => category,
  };
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return 'Дата не указана';
  }

  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day.$month.${value.year} $hour:$minute';
}
