import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/widgets/app_loading_state.dart';
import 'package:prohelpers_mobile/core/widgets/pro_status_banner.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_widget_model.dart';

class OverviewTodayStatus extends StatelessWidget {
  const OverviewTodayStatus({
    super.key,
    required this.widgets,
    required this.unreadCount,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  final List<DashboardWidgetModel> widgets;
  final int unreadCount;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading && widgets.isEmpty) {
      return const AppLoadingState(message: 'Обновляем состояние объекта');
    }

    final criticalCount =
        widgets
            .where((widget) => widget.status == DashboardWidgetStatus.critical)
            .length;
    final attentionCount =
        widgets
            .where((widget) => widget.status == DashboardWidgetStatus.attention)
            .length;

    final tone =
        criticalCount > 0
            ? ProStatusTone.danger
            : attentionCount > 0 || unreadCount > 0
            ? ProStatusTone.warning
            : ProStatusTone.success;
    final title =
        criticalCount > 0
            ? 'Нужны действия'
            : attentionCount > 0 || unreadCount > 0
            ? 'Есть вопросы'
            : 'Все спокойно';
    final description =
        criticalCount > 0
            ? 'Критичных зон: $criticalCount. Проверьте ближайшие действия ниже.'
            : attentionCount > 0 || unreadCount > 0
            ? 'Требуют внимания: $attentionCount. Непрочитанных уведомлений: $unreadCount.'
            : 'По доступным разделам нет критичных сигналов.';

    return ProStatusBanner(title: title, description: description, tone: tone);
  }
}
