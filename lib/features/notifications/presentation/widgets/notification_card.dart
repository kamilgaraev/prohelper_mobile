import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
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
    final color = _priorityColor(context, notification.priority);

    return IndustrialCard(
      onTap: onTap,
      borderColor: notification.isUnread ? color.withValues(alpha: 0.45) : null,
      backgroundColor:
          notification.isUnread
              ? color.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.12 : 0.06,
              )
              : null,
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
              if (notification.isUnread && onMarkRead != null)
                TextButton.icon(
                  onPressed: onMarkRead,
                  icon: const Icon(Icons.done_rounded, size: 18),
                  label: const Text('Прочитано'),
                ),
            ],
          ),
        ],
      ),
    );
  }
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

Color _priorityColor(BuildContext context, String priority) {
  return switch (priority.trim().toLowerCase()) {
    'critical' => AppColors.error,
    'high' => AppColors.warning,
    'low' => AppColors.success,
    _ => Theme.of(context).colorScheme.primary,
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
