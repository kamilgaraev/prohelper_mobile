import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/industrial_card.dart';
import '../../construction_journal/presentation/construction_journal_screen.dart';
import '../../construction_journal/presentation/journal_entry_detail_screen.dart';
import '../../schedule/presentation/schedule_details_screen.dart';
import '../../schedule/presentation/schedule_screen.dart';
import '../../site_requests/presentation/screens/site_request_detail_screen.dart';
import '../../site_requests/presentation/screens/site_requests_screen.dart';
import '../../warehouse/data/warehouse_repository.dart';
import '../../warehouse/presentation/warehouse_screen.dart';
import '../../warehouse/presentation/warehouse_tasks_screen.dart';
import '../data/notification_model.dart';
import '../domain/notification_navigation_target.dart';
import '../domain/notifications_provider.dart';

class NotificationDetailScreen extends ConsumerStatefulWidget {
  const NotificationDetailScreen({
    super.key,
    required this.notificationId,
    this.initialNotification,
  });

  final String notificationId;
  final NotificationModel? initialNotification;

  @override
  ConsumerState<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState
    extends ConsumerState<NotificationDetailScreen> {
  bool _markReadRequested = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationDetailProvider(widget.notificationId));
    final notification = state.notification ?? widget.initialNotification;

    if (!_markReadRequested && state.notification?.isUnread == true) {
      _markReadRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(notificationDetailProvider(widget.notificationId).notifier)
              .markAsRead();
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомление'),
        centerTitle: false,
        actions: [
          if (notification?.isUnread == true)
            IconButton(
              onPressed:
                  state.isMarkingRead
                      ? null
                      : () =>
                          ref
                              .read(
                                notificationDetailProvider(
                                  widget.notificationId,
                                ).notifier,
                              )
                              .markAsRead(),
              icon:
                  state.isMarkingRead
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.done_rounded),
            ),
        ],
      ),
      body:
          state.isLoading && notification == null
              ? const Center(child: CircularProgressIndicator())
              : state.error != null && notification == null
              ? AppStateView(
                icon: Icons.error_outline_rounded,
                iconColor: AppColors.error,
                title: 'Не удалось загрузить уведомление',
                description: state.error,
                action: OutlinedButton(
                  onPressed:
                      () =>
                          ref
                              .read(
                                notificationDetailProvider(
                                  widget.notificationId,
                                ).notifier,
                              )
                              .load(),
                  child: const Text('Повторить'),
                ),
              )
              : _NotificationDetailContent(
                notification: notification!,
                onOpenTarget: () => _openTarget(context, notification),
                onRefresh:
                    () =>
                        ref
                            .read(
                              notificationDetailProvider(
                                widget.notificationId,
                              ).notifier,
                            )
                            .load(),
              ),
    );
  }

  Future<void> _openTarget(
    BuildContext context,
    NotificationModel notification,
  ) async {
    final target = NotificationNavigationTarget.fromNotification(notification);
    final navigator = Navigator.of(context);

    switch (target.type) {
      case NotificationTargetType.siteRequest:
        if (target.siteRequestId != null) {
          await navigator.push(
            MaterialPageRoute(
              builder:
                  (_) => SiteRequestDetailScreen(id: target.siteRequestId!),
            ),
          );
        } else {
          await navigator.push(
            MaterialPageRoute(builder: (_) => const SiteRequestsScreen()),
          );
        }
        return;
      case NotificationTargetType.constructionJournalEntry:
        if (target.journalId != null && target.journalEntryId != null) {
          await navigator.push(
            MaterialPageRoute(
              builder:
                  (_) => JournalEntryDetailScreen(
                    journalId: target.journalId!,
                    entryId: target.journalEntryId!,
                  ),
            ),
          );
        } else {
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => const ConstructionJournalScreen(),
            ),
          );
        }
        return;
      case NotificationTargetType.schedule:
        if (target.scheduleId != null) {
          await navigator.push(
            MaterialPageRoute(
              builder:
                  (_) => ScheduleDetailsScreen(scheduleId: target.scheduleId!),
            ),
          );
        } else {
          await navigator.push(
            MaterialPageRoute(builder: (_) => const ScheduleScreen()),
          );
        }
        return;
      case NotificationTargetType.warehouseTask:
        await _openWarehouseTarget(context, target);
        return;
      case NotificationTargetType.unknown:
        _showMessage(
          context,
          'Связанный раздел пока недоступен в мобильном приложении.',
        );
        return;
    }
  }

  Future<void> _openWarehouseTarget(
    BuildContext context,
    NotificationNavigationTarget target,
  ) async {
    final navigator = Navigator.of(context);

    try {
      final summary =
          await ref.read(warehouseRepositoryProvider).fetchWarehouseSummary();
      if (!context.mounted) {
        return;
      }

      await navigator.push(
        MaterialPageRoute(
          builder:
              (_) => WarehouseTasksScreen(
                summary: summary,
                initialWarehouseId: target.warehouseId,
                initialEntityType:
                    target.warehouseTaskId == null ? null : 'task',
                initialEntityId: target.warehouseTaskId,
              ),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      await navigator.push(
        MaterialPageRoute(builder: (_) => const WarehouseScreen()),
      );
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NotificationDetailContent extends StatelessWidget {
  const _NotificationDetailContent({
    required this.notification,
    required this.onOpenTarget,
    required this.onRefresh,
  });

  final NotificationModel notification;
  final VoidCallback onOpenTarget;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final target = NotificationNavigationTarget.fromNotification(notification);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          IndustrialCard(
            borderColor:
                notification.isUnread
                    ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.35)
                    : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.title, style: AppTypography.h1(context)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Badge(
                      label: notification.isUnread ? 'Новое' : 'Прочитано',
                      color:
                          notification.isUnread
                              ? Theme.of(context).colorScheme.primary
                              : AppColors.success,
                    ),
                    _Badge(
                      label: _priorityLabel(notification.priority),
                      color: _priorityColor(context, notification.priority),
                    ),
                    _Badge(
                      label: _formatDateTime(notification.createdAt),
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  notification.message,
                  style: AppTypography.bodyLarge(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          IndustrialCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Действие', style: AppTypography.h2(context)),
                const SizedBox(height: 8),
                Text(
                  _targetDescription(target),
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onOpenTarget,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Открыть связанный раздел'),
                  ),
                ),
              ],
            ),
          ),
          if (_details(notification).isNotEmpty) ...[
            const SizedBox(height: 12),
            IndustrialCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Детали', style: AppTypography.h2(context)),
                  const SizedBox(height: 12),
                  ..._details(notification).map(
                    (item) => _DetailRow(label: item.label, value: item.value),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: AppTypography.bodyMedium(
                context,
              ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: AppTypography.bodyLarge(context))),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

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

class _NotificationDetailItem {
  const _NotificationDetailItem(this.label, this.value);

  final String label;
  final String value;
}

List<_NotificationDetailItem> _details(NotificationModel notification) {
  final data = notification.data;
  final items = <_NotificationDetailItem>[];

  void add(String label, String key) {
    final value = notificationAsNullableString(data[key]);
    if (value != null) {
      items.add(_NotificationDetailItem(label, value));
    }
  }

  add('Объект', 'project_name');
  add('Организация', 'organization_name');
  add('Номер', 'order_number');
  add('Поставщик', 'supplier_name');
  add('Сумма', 'amount');
  add('Валюта', 'currency');
  add('Исполнитель', 'payee_name');

  return items;
}

String _targetDescription(NotificationNavigationTarget target) {
  return switch (target.type) {
    NotificationTargetType.siteRequest =>
      target.siteRequestId == null
          ? 'Откроется список заявок.'
          : 'Откроется карточка заявки.',
    NotificationTargetType.constructionJournalEntry =>
      target.hasConcreteTarget
          ? 'Откроется запись журнала работ.'
          : 'Откроется журнал работ.',
    NotificationTargetType.schedule =>
      target.scheduleId == null
          ? 'Откроется список графиков работ.'
          : 'Откроется график работ.',
    NotificationTargetType.warehouseTask =>
      target.warehouseTaskId == null
          ? 'Откроется складской раздел.'
          : 'Откроется очередь складских задач.',
    NotificationTargetType.unknown =>
      'Для этого уведомления нет прямого перехода.',
  };
}

String _priorityLabel(String priority) {
  return switch (priority.trim().toLowerCase()) {
    'critical' => 'Критично',
    'high' => 'Высокий',
    'low' => 'Низкий',
    _ => 'Обычный',
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
