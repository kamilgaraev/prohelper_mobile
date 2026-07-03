import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/widgets/app_loading_state.dart';
import 'package:prohelpers_mobile/core/widgets/pro_status_banner.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_widget_model.dart';

class OverviewTodayStatus extends StatelessWidget {
  const OverviewTodayStatus({
    super.key,
    required this.widgets,
    required this.unreadCount,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    this.onOpenNotifications,
  });

  final List<DashboardWidgetModel> widgets;
  final int unreadCount;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback? onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    if (isLoading && widgets.isEmpty) {
      return const AppLoadingState(message: 'Обновляем сводку', minHeight: 132);
    }

    if (error != null) {
      return ProStatusBanner(
        title: 'Сводка недоступна',
        description: error,
        tone: ProStatusTone.danger,
        surfaceTone: ProSurfaceTone.elevated,
        compact: true,
        action: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Повторить'),
        ),
      );
    }

    final criticalCount =
        widgets
            .where((widget) => widget.status == DashboardWidgetStatus.critical)
            .length;
    final attentionCount =
        widgets
            .where((widget) => widget.status == DashboardWidgetStatus.attention)
            .length;

    final hasDashboardAttention = criticalCount > 0 || attentionCount > 0;
    final tone =
        criticalCount > 0
            ? ProStatusTone.danger
            : hasDashboardAttention || unreadCount > 0
            ? ProStatusTone.warning
            : ProStatusTone.success;
    final title =
        criticalCount > 0
            ? 'Нужны действия'
            : hasDashboardAttention
            ? 'Есть вопросы'
            : unreadCount > 0
            ? 'Новые события'
            : 'Все спокойно';
    final description =
        criticalCount > 0
            ? 'Критичных зон: $criticalCount. Проверьте ближайшие действия ниже.'
            : hasDashboardAttention
            ? 'Требуют внимания: $attentionCount. Непрочитанных уведомлений: $unreadCount.'
            : unreadCount > 0
            ? 'Непрочитанных: $unreadCount. Проверьте обновления по объекту.'
            : 'По доступным разделам нет критичных сигналов.';
    final isNotificationOnly = !hasDashboardAttention && unreadCount > 0;
    final action =
        isNotificationOnly
            ? Semantics(
              container: true,
              focusable: true,
              label: 'Открыть уведомления',
              button: true,
              enabled: onOpenNotifications != null,
              onTap: onOpenNotifications,
              child: ExcludeSemantics(
                child: IconButton.filledTonal(
                  tooltip: 'Открыть уведомления',
                  onPressed: onOpenNotifications,
                  icon: const Icon(Icons.notifications_active_outlined),
                ),
              ),
            )
            : null;

    return ProStatusBanner(
      title: title,
      description: description,
      tone: tone,
      surfaceTone: ProSurfaceTone.elevated,
      action: action,
      compact: isNotificationOnly,
    );
  }
}
