import 'package:flutter/material.dart';
import 'package:prohelpers_mobile/core/theme/app_colors.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/pro_card.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';

class SiteRequestCard extends StatelessWidget {
  final SiteRequestModel request;
  final VoidCallback onTap;

  const SiteRequestCard({
    super.key,
    required this.request,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ProCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  request.title,
                  style: AppTypography.h2.copyWith(color: theme.colorScheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(
                label: request.statusLabel ?? request.status,
                color: _getStatusColor(request.status),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (request.projectName != null) ...[
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.projectName!,
                    style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (request.materialName != null) ...[
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${request.materialName} - ${request.materialQuantity} ${request.materialUnit}',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Приоритет: ${request.priorityLabel ?? request.priority}',
                style: AppTypography.caption.copyWith(color: _getPriorityColor(request.priority)),
              ),
              if (request.createdAt != null)
                Text(
                  _formatDate(request.createdAt!),
                  style: AppTypography.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    return switch (status) {
      'draft' => AppColors.textSecondary,
      'pending' => AppColors.warning,
      'approved' => AppColors.primary,
      'completed' => AppColors.success,
      'cancelled' || 'rejected' => AppColors.error,
      _ => AppColors.textSecondary,
    };
  }

  Color _getPriorityColor(String priority) {
    return switch (priority) {
      'high' || 'urgent' => AppColors.error,
      'normal' => AppColors.textSecondary,
      'low' => AppColors.success,
      _ => AppColors.textSecondary,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
