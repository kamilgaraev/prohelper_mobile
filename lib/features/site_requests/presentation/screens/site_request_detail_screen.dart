import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/theme/app_colors.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/app_state_view.dart';
import 'package:prohelpers_mobile/core/widgets/mesh_background.dart';
import 'package:prohelpers_mobile/core/widgets/pro_button.dart';
import 'package:prohelpers_mobile/core/widgets/pro_card.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_request_detail_provider.dart';

class SiteRequestDetailScreen extends ConsumerWidget {
  final int id;

  const SiteRequestDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(siteRequestDetailProvider(id));
    final theme = Theme.of(context);

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('Детали заявки', style: AppTypography.h2(context)),
        ),
        body: state.isLoading && state.request == null
            ? const Center(child: CircularProgressIndicator())
            : state.error != null && state.request == null
                ? AppStateView(
                    icon: Icons.error_outline_rounded,
                    iconColor: AppColors.error,
                    title: 'Не удалось загрузить заявку',
                    description: state.error,
                    action: OutlinedButton(
                      onPressed: () => ref.read(siteRequestDetailProvider(id).notifier).loadDetails(),
                      child: const Text('Повторить'),
                    ),
                  )
                : _buildContent(context, state.request!),
        bottomNavigationBar: state.request != null ? _buildActions(context, ref, state) : null,
      ),
    );
  }

  Widget _buildContent(BuildContext context, SiteRequestModel request) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(context, request),
          if (request.materialName != null) ...[
            const SizedBox(height: 16),
            _buildMaterialSection(context, request),
          ],
          if (request.personnelTypeLabel != null || request.personnelCount != null) ...[
            const SizedBox(height: 16),
            _buildPersonnelSection(context, request),
          ],
          if (request.equipmentTypeLabel != null || request.equipmentType != null) ...[
            const SizedBox(height: 16),
            _buildEquipmentSection(context, request),
          ],
          if (request.description != null && request.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildDescriptionSection(context, request.description!),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, SiteRequestModel request) {
    final theme = Theme.of(context);

    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(request.title, style: AppTypography.h1(context)),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoLabel(label: 'ID #${request.serverId}'),
              const Spacer(),
              _StatusBadge(
                label: request.statusLabel ?? request.status,
                color: _getStatusColor(request.status),
              ),
            ],
          ),
          Divider(height: 32, color: theme.colorScheme.outline.withOpacity(0.2)),
          if (request.projectName != null)
            _ParamRow(
              icon: Icons.location_on_outlined,
              label: 'Объект',
              value: request.projectName!,
            ),
          if (request.requestTypeLabel != null)
            _ParamRow(
              icon: Icons.category_outlined,
              label: 'Тип',
              value: request.requestTypeLabel!,
            ),
          if (request.priorityLabel != null)
            _ParamRow(
              icon: Icons.flag_outlined,
              label: 'Приоритет',
              value: request.priorityLabel!,
              valueColor: _getPriorityColor(request.priority),
            ),
          if (request.createdAt != null)
            _ParamRow(
              icon: Icons.calendar_today_outlined,
              label: 'Создана',
              value: _formatDate(request.createdAt!),
            ),
        ],
      ),
    );
  }

  Widget _buildMaterialSection(BuildContext context, SiteRequestModel request) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Материалы', style: AppTypography.h2(context)),
          const SizedBox(height: 16),
          _ParamRow(
            icon: Icons.inventory_2_outlined,
            label: 'Наименование',
            value: request.materialName!,
          ),
          _ParamRow(
            icon: Icons.format_list_numbered_outlined,
            label: 'Количество',
            value: '${request.materialQuantity} ${request.materialUnit ?? ''}'.trim(),
          ),
          if (request.requiredDate != null)
            _ParamRow(
              icon: Icons.local_shipping_outlined,
              label: 'Дата поставки',
              value: request.requiredDate!,
            ),
        ],
      ),
    );
  }

  Widget _buildPersonnelSection(BuildContext context, SiteRequestModel request) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Персонал', style: AppTypography.h2(context)),
          const SizedBox(height: 16),
          if (request.personnelTypeLabel != null)
            _ParamRow(
              icon: Icons.groups_outlined,
              label: 'Специальность',
              value: request.personnelTypeLabel!,
            ),
          if (request.personnelCount != null)
            _ParamRow(
              icon: Icons.person_outline_rounded,
              label: 'Количество',
              value: request.personnelCount.toString(),
            ),
          if (request.workStartDate != null)
            _ParamRow(
              icon: Icons.event_available_outlined,
              label: 'Дата начала',
              value: request.workStartDate!,
            ),
          if (request.workEndDate != null)
            _ParamRow(
              icon: Icons.event_busy_outlined,
              label: 'Дата окончания',
              value: request.workEndDate!,
            ),
        ],
      ),
    );
  }

  Widget _buildEquipmentSection(BuildContext context, SiteRequestModel request) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Техника', style: AppTypography.h2(context)),
          const SizedBox(height: 16),
          _ParamRow(
            icon: Icons.precision_manufacturing_outlined,
            label: 'Тип',
            value: request.equipmentTypeLabel ?? request.equipmentType ?? 'Не указан',
          ),
          if (request.rentalStartDate != null)
            _ParamRow(
              icon: Icons.event_available_outlined,
              label: 'Начало аренды',
              value: request.rentalStartDate!,
            ),
          if (request.rentalEndDate != null)
            _ParamRow(
              icon: Icons.event_busy_outlined,
              label: 'Окончание аренды',
              value: request.rentalEndDate!,
            ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(BuildContext context, String description) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Описание', style: AppTypography.h2(context)),
          const SizedBox(height: 12),
          Text(description, style: AppTypography.bodyMedium(context)),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref, SiteRequestDetailState state) {
    final theme = Theme.of(context);
    final status = state.request!.status;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.05),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'draft')
            ProButton(
              text: 'ОТПРАВИТЬ ЗАЯВКУ',
              isLoading: state.isActionLoading,
              onPressed: () => _runAction(
                context,
                () => ref.read(siteRequestDetailProvider(id).notifier).submit(),
              ),
            ),
          if (status == 'fulfilled')
            ProButton(
              text: 'ПОДТВЕРДИТЬ ПОЛУЧЕНИЕ',
              backgroundColor: AppColors.success,
              isLoading: state.isActionLoading,
              onPressed: () => _runAction(
                context,
                () => ref.read(siteRequestDetailProvider(id).notifier).complete(),
              ),
            ),
          if (['draft', 'pending'].contains(status)) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: state.isActionLoading ? null : () => _showCancelDialog(context, ref),
              child: Text(
                'ОТМЕНИТЬ ЗАЯВКУ',
                style: AppTypography.bodyMedium(context).copyWith(color: AppColors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _runAction(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('Отмена заявки', style: AppTypography.h2(context)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: AppTypography.bodyMedium(context),
          decoration: InputDecoration(
            hintText: 'Причина отмены (необязательно)',
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Назад'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _runAction(
                context,
                () => ref.read(siteRequestDetailProvider(id).notifier).cancel(notes: controller.text),
              );
            },
            child: const Text('Отменить', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) => switch (status) {
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

  Color _getPriorityColor(String priority) => switch (priority) {
        'high' || 'urgent' => AppColors.error,
        'medium' => AppColors.warning,
        'normal' => AppColors.textSecondary,
        'low' => AppColors.success,
        _ => AppColors.textSecondary,
      };

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }
}

class _InfoLabel extends StatelessWidget {
  final String label;

  const _InfoLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: AppTypography.bodySmall(context)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall(context).copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ParamRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _ParamRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: AppTypography.bodyMedium(context).copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyLarge(context).copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
