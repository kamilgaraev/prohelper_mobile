import 'package:flutter/material.dart';
import 'package:prohelpers_mobile/core/theme/app_colors.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/pro_card.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';

class SiteRequestCard extends StatelessWidget {
  const SiteRequestCard({
    super.key,
    required this.request,
    required this.onTap,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final SiteRequestModel request;
  final VoidCallback onTap;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(request.status);
    final priorityColor = _getPriorityColor(request.priority);
    final hasAttention = _needsAttention(request);

    return ProCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.title,
                      style: AppTypography.h2(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _requestSubtitle(request),
                      style: AppTypography.bodyMedium(context).copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusBadge(
                label: _statusLabel(request),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaBadge(
                icon: Icons.category_outlined,
                label: _requestTypeLabel(request),
              ),
              _MetaBadge(
                icon: Icons.flag_outlined,
                label: _priorityLabel(request),
                color: priorityColor,
              ),
              if (request.createdAt != null)
                _MetaBadge(
                  icon: Icons.schedule_outlined,
                  label: _formatDate(request.createdAt!),
                ),
              if ((request.assignedUserName ?? '').trim().isNotEmpty)
                _MetaBadge(
                  icon: Icons.person_outline_rounded,
                  label: request.assignedUserName!,
                ),
              if (request.groupRequestCount > 1)
                _MetaBadge(
                  icon: Icons.layers_outlined,
                  label: '${request.groupRequestCount} позиции',
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasAttention)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _attentionText(request),
                style: AppTypography.bodyMedium(context).copyWith(
                  color: priorityColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Text(
              'Заявка не требует срочного вмешательства.',
              style: AppTypography.caption(context).copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (primaryActionLabel != null || secondaryActionLabel != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (primaryActionLabel != null)
                  FilledButton.tonal(
                    onPressed: onPrimaryAction,
                    child: Text(primaryActionLabel!),
                  ),
                if (secondaryActionLabel != null)
                  OutlinedButton(
                    onPressed: onSecondaryAction,
                    child: Text(secondaryActionLabel!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _requestSubtitle(SiteRequestModel request) {
    if ((request.materialName ?? '').trim().isNotEmpty) {
      final quantity = request.materialQuantity != null
          ? '${_formatQuantity(request.materialQuantity!)} ${request.materialUnit ?? ''}'.trim()
          : request.materialUnit ?? '';
      return [request.materialName!, quantity]
          .where((value) => value.trim().isNotEmpty)
          .join(' • ');
    }

    if ((request.personnelTypeLabel ?? '').trim().isNotEmpty) {
      final count = request.personnelCount != null
          ? '${request.personnelCount} чел.'
          : '';
      return [request.personnelTypeLabel!, count]
          .where((value) => value.trim().isNotEmpty)
          .join(' • ');
    }

    if ((request.equipmentTypeLabel ?? request.equipmentType ?? '').trim().isNotEmpty) {
      return request.equipmentTypeLabel ?? request.equipmentType!;
    }

    return request.description?.trim().isNotEmpty == true
        ? request.description!
        : 'Без дополнительного описания';
  }

  String _requestTypeLabel(SiteRequestModel request) {
    final label = request.requestTypeLabel?.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }

    return switch (request.requestType.trim().toLowerCase()) {
      'material' || 'material_request' => 'Материалы',
      'personnel' || 'personnel_request' => 'Персонал',
      'equipment' || 'equipment_request' => 'Техника',
      _ => 'Заявка',
    };
  }

  String _priorityLabel(SiteRequestModel request) {
    final label = request.priorityLabel?.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }

    return switch (request.priority.trim().toLowerCase()) {
      'urgent' => 'Срочно',
      'high' => 'Высокий приоритет',
      'medium' => 'Средний приоритет',
      'low' => 'Низкий приоритет',
      _ => 'Приоритет не указан',
    };
  }

  String _statusLabel(SiteRequestModel request) {
    final label = request.statusLabel?.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }

    return switch (request.status.trim().toLowerCase()) {
      'draft' => 'Черновик',
      'pending' => 'На согласовании',
      'in_review' => 'На проверке',
      'approved' => 'Согласована',
      'in_progress' => 'В работе',
      'fulfilled' => 'Исполнена',
      'completed' => 'Закрыта',
      'cancelled' => 'Отменена',
      'rejected' => 'Отклонена',
      _ => request.status,
    };
  }

  String _attentionText(SiteRequestModel request) {
    if (_isUrgentRequest(request)) {
      return 'Срочная заявка: нужен быстрый ответ по исполнению.';
    }

    return switch (request.status.trim().toLowerCase()) {
      'pending' || 'in_review' => 'Ожидает согласования или проверки.',
      'approved' => 'Уже согласована и должна уйти в работу.',
      'in_progress' => 'Исполнение уже началось.',
      'fulfilled' => 'Нужно подтвердить получение или закрытие.',
      _ => 'Статус заявки требует внимания.',
    };
  }

  Color _getStatusColor(String status) {
    return switch (status.trim().toLowerCase()) {
      'draft' => AppColors.textSecondary,
      'pending' => AppColors.warning,
      'in_review' => AppColors.primary,
      'approved' => AppColors.primary,
      'in_progress' => AppColors.secondary,
      'fulfilled' => AppColors.success,
      'completed' => AppColors.success,
      'on_hold' => AppColors.warning,
      'cancelled' || 'rejected' => AppColors.error,
      _ => AppColors.textSecondary,
    };
  }

  Color _getPriorityColor(String priority) {
    return switch (priority.trim().toLowerCase()) {
      'high' || 'urgent' => AppColors.error,
      'medium' => AppColors.warning,
      'normal' => AppColors.textSecondary,
      'low' => AppColors.success,
      _ => AppColors.textSecondary,
    };
  }

  bool _needsAttention(SiteRequestModel request) {
    final status = request.status.trim().toLowerCase();
    return _isUrgentRequest(request) ||
        status == 'pending' ||
        status == 'in_review' ||
        status == 'approved' ||
        status == 'in_progress' ||
        status == 'fulfilled';
  }

  bool _isUrgentRequest(SiteRequestModel request) {
    final priority = request.priority.trim().toLowerCase();
    return priority == 'high' || priority == 'urgent';
  }

  String _formatQuantity(double value) {
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: AppTypography.caption(context).copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedColor = color ?? theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: resolvedColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: resolvedColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.caption(context).copyWith(
              color: resolvedColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
