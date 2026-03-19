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
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_request_form_screen.dart';

class SiteRequestDetailScreen extends ConsumerWidget {
  const SiteRequestDetailScreen({
    super.key,
    required this.id,
  });

  final int id;

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
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: theme.colorScheme.onSurface,
            ),
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
                      onPressed: () => ref
                          .read(siteRequestDetailProvider(id).notifier)
                          .loadDetails(),
                      child: const Text('Повторить'),
                    ),
                  )
                : _SiteRequestDetailContent(
                    request: state.request!,
                    onEdit: state.request!.canBeEdited
                        ? () async {
                            final updated = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => SiteRequestFormScreen(
                                  initialRequest: state.request,
                                ),
                              ),
                            );

                            if (updated == true && context.mounted) {
                              await ref
                                  .read(siteRequestsProvider.notifier)
                                  .loadRequests(refresh: true);
                              await ref
                                  .read(siteRequestDetailProvider(id).notifier)
                                  .loadDetails();
                            }
                          }
                        : null,
                  ),
        bottomNavigationBar: state.request == null
            ? null
            : _SiteRequestActions(
                transitions: _resolvedTransitions(state.request!),
                isLoading: state.isActionLoading,
                onTransitionSelected: (transition) =>
                    _runTransitionAction(context, ref, transition),
              ),
      ),
    );
  }

  Future<void> _runTransitionAction(
    BuildContext context,
    WidgetRef ref,
    SiteRequestTransition transition,
  ) async {
    if (_statusRequiresReason(transition.status)) {
      _showTransitionDialog(context, ref, transition);
      return;
    }

    try {
      await ref
          .read(siteRequestDetailProvider(id).notifier)
          .changeStatus(transition.status);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  void _showTransitionDialog(
    BuildContext context,
    WidgetRef ref,
    SiteRequestTransition transition,
  ) {
    final theme = Theme.of(context);
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(_transitionActionLabel(transition), style: AppTypography.h2(context)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: AppTypography.bodyMedium(context),
          decoration: InputDecoration(
            hintText: 'Комментарий к решению',
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Назад'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              try {
                await ref
                    .read(siteRequestDetailProvider(id).notifier)
                    .changeStatus(transition.status, notes: controller.text);
              } catch (error) {
                if (!context.mounted) {
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error.toString())),
                );
              }
            },
            child: Text(
              _transitionActionLabel(transition),
              style: TextStyle(color: _transitionColor(transition.status)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SiteRequestDetailContent extends StatelessWidget {
  const _SiteRequestDetailContent({
    required this.request,
    this.onEdit,
  });

  final SiteRequestModel request;
  final Future<void> Function()? onEdit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RequestHeroCard(request: request),
          const SizedBox(height: 16),
          _RequestAttentionBanner(request: request),
          const SizedBox(height: 16),
          _RequestContextCard(request: request),
          const SizedBox(height: 16),
          _RequestActorsCard(request: request),
          if (onEdit != null) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onEdit == null ? null : () => onEdit!.call(),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Редактировать заявку'),
              ),
            ),
          ],
          if (_hasGroupSection(request)) ...[
            const SizedBox(height: 16),
            _RequestGroupCard(request: request),
          ],
          if (_hasResourceSection(request)) ...[
            const SizedBox(height: 16),
            _RequestResourcesCard(request: request),
          ],
          if (_hasProcurementSection(request)) ...[
            const SizedBox(height: 16),
            _RequestProcurementCard(request: request),
          ],
          if ((request.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _RequestTextCard(
              title: 'Комментарий',
              description: request.notes!,
            ),
          ],
          if ((request.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _RequestTextCard(
              title: 'Описание',
              description: request.description!,
            ),
          ],
          if (request.history.isNotEmpty) ...[
            const SizedBox(height: 16),
            _RequestHistoryCard(history: request.history),
          ],
          const SizedBox(height: 112),
        ],
      ),
    );
  }
}

class _RequestHeroCard extends StatelessWidget {
  const _RequestHeroCard({required this.request});

  final SiteRequestModel request;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(request.title, style: AppTypography.h1(context)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoLabel(label: 'ID #${request.serverId}'),
              _StatusBadge(
                label: _statusLabel(request),
                color: _statusColor(request.status),
              ),
              _SoftBadge(
                icon: Icons.flag_outlined,
                label: _priorityLabel(request),
                color: _priorityColor(request.priority),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _requestSubtitle(request),
            style: AppTypography.bodyLarge(context),
          ),
        ],
      ),
    );
  }
}

class _RequestAttentionBanner extends StatelessWidget {
  const _RequestAttentionBanner({required this.request});

  final SiteRequestModel request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _attentionColor(request);

    return ProCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_attentionIcon(request), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _attentionTitle(request),
                  style: AppTypography.bodyLarge(context).copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _attentionDescription(request),
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _RequestContextCard extends StatelessWidget {
  const _RequestContextCard({required this.request});

  final SiteRequestModel request;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Контекст заявки', style: AppTypography.h2(context)),
          const SizedBox(height: 16),
          if ((request.projectName ?? '').trim().isNotEmpty)
            _ParamRow(
              icon: Icons.location_on_outlined,
              label: 'Объект',
              value: request.projectName!,
            ),
          _ParamRow(
            icon: Icons.category_outlined,
            label: 'Тип',
            value: _requestTypeLabel(request),
          ),
          _ParamRow(
            icon: Icons.flag_outlined,
            label: 'Приоритет',
            value: _priorityLabel(request),
            valueColor: _priorityColor(request.priority),
          ),
          _ParamRow(
            icon: Icons.radio_button_checked_outlined,
            label: 'Статус',
            value: _statusLabel(request),
            valueColor: _statusColor(request.status),
          ),
          if (request.createdAt != null)
            _ParamRow(
              icon: Icons.calendar_today_outlined,
              label: 'Создана',
              value: _formatDate(request.createdAt!),
            ),
          if ((request.requiredDate ?? '').trim().isNotEmpty)
            _ParamRow(
              icon: Icons.event_available_outlined,
              label: 'Нужна к дате',
              value: request.requiredDate!,
            ),
        ],
      ),
    );
  }
}

class _RequestActorsCard extends StatelessWidget {
  const _RequestActorsCard({required this.request});

  final SiteRequestModel request;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Участники', style: AppTypography.h2(context)),
          const SizedBox(height: 16),
          if ((request.userName ?? '').trim().isNotEmpty)
            _ParamRow(
              icon: Icons.person_outline_rounded,
              label: 'Создал',
              value: request.userName!,
            ),
          if ((request.assignedUserName ?? '').trim().isNotEmpty)
            _ParamRow(
              icon: Icons.assignment_ind_outlined,
              label: 'Исполнитель',
              value: request.assignedUserName!,
            ),
          if ((request.userName ?? '').trim().isEmpty &&
              (request.assignedUserName ?? '').trim().isEmpty)
            Text(
              'Исполнитель пока не назначен.',
              style: AppTypography.bodyMedium(context),
            ),
        ],
      ),
    );
  }
}

class _RequestResourcesCard extends StatelessWidget {
  const _RequestResourcesCard({required this.request});

  final SiteRequestModel request;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Что требуется', style: AppTypography.h2(context)),
          const SizedBox(height: 16),
          if ((request.materialName ?? '').trim().isNotEmpty) ...[
            _ParamRow(
              icon: Icons.inventory_2_outlined,
              label: 'Материал',
              value: request.materialName!,
            ),
            if (request.materialQuantity != null ||
                (request.materialUnit ?? '').trim().isNotEmpty)
              _ParamRow(
                icon: Icons.format_list_numbered_outlined,
                label: 'Количество',
                value: [
                  request.materialQuantity != null
                      ? _formatQuantity(request.materialQuantity!)
                      : null,
                  request.materialUnit,
                ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' '),
              ),
          ],
          if ((request.personnelTypeLabel ?? '').trim().isNotEmpty ||
              request.personnelCount != null) ...[
            if ((request.personnelTypeLabel ?? '').trim().isNotEmpty)
              _ParamRow(
                icon: Icons.groups_outlined,
                label: 'Персонал',
                value: request.personnelTypeLabel!,
              ),
            if (request.personnelCount != null)
              _ParamRow(
                icon: Icons.person_outline_rounded,
                label: 'Количество',
                value: '${request.personnelCount} чел.',
              ),
          ],
          if ((request.equipmentTypeLabel ?? request.equipmentType ?? '').trim().isNotEmpty) ...[
            _ParamRow(
              icon: Icons.precision_manufacturing_outlined,
              label: 'Техника',
              value: request.equipmentTypeLabel ?? request.equipmentType!,
            ),
            if ((request.rentalStartDate ?? '').trim().isNotEmpty)
              _ParamRow(
                icon: Icons.event_available_outlined,
                label: 'Начало аренды',
                value: request.rentalStartDate!,
              ),
            if ((request.rentalEndDate ?? '').trim().isNotEmpty)
              _ParamRow(
                icon: Icons.event_busy_outlined,
                label: 'Окончание аренды',
                value: request.rentalEndDate!,
              ),
          ],
        ],
      ),
    );
  }
}

class _RequestProcurementCard extends StatelessWidget {
  const _RequestProcurementCard({required this.request});

  final SiteRequestModel request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reserveStatus = request.materialReserved
        ? 'Материал зарезервирован'
        : request.purchaseOrders.isNotEmpty
            ? 'Ожидается резервирование или приемка'
            : 'Закупка еще не запущена';
    final receiptStatus = request.materialsReceived
        ? 'Материалы приняты'
        : request.purchaseOrders.isNotEmpty
            ? 'Ожидается поставка'
            : 'Поставка еще не оформлена';

    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Закупка', style: AppTypography.h2(context)),
          const SizedBox(height: 16),
          _ParamRow(
            icon: Icons.inventory_outlined,
            label: 'Резерв',
            value: reserveStatus,
            valueColor: request.materialReserved ? AppColors.success : null,
          ),
          if (request.reservedQuantity != null)
            _ParamRow(
              icon: Icons.scale_outlined,
              label: 'В резерве',
              value: [
                _formatQuantity(request.reservedQuantity!),
                request.materialUnit,
              ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' '),
            ),
          if (request.reservedAt != null)
            _ParamRow(
              icon: Icons.schedule_outlined,
              label: 'Резерв создан',
              value: _formatDateTime(request.reservedAt!),
            ),
          if (request.warehouseId != null)
            _ParamRow(
              icon: Icons.warehouse_outlined,
              label: 'Склад',
              value: 'ID #${request.warehouseId}',
            ),
          _ParamRow(
            icon: Icons.local_shipping_outlined,
            label: 'Приемка',
            value: receiptStatus,
            valueColor: request.materialsReceived ? AppColors.success : null,
          ),
          if (request.materialsReceivedAt != null)
            _ParamRow(
              icon: Icons.fact_check_outlined,
              label: 'Принято',
              value: _formatDateTime(request.materialsReceivedAt!),
            ),
          if (request.purchaseRequests.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Заявки на закупку',
              style: AppTypography.bodyLarge(context).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...request.purchaseRequests.map(
              (item) => _ProcurementItemTile(
                icon: Icons.request_quote_outlined,
                title: item.number.isNotEmpty ? item.number : 'Заявка #${item.id}',
                subtitle: item.createdAt != null ? _formatDateTime(item.createdAt!) : null,
                badgeLabel: _purchaseRequestStatusLabel(item),
                badgeColor: _statusColor(item.status),
              ),
            ),
          ],
          if (request.purchaseOrders.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Заказы поставщику',
              style: AppTypography.bodyLarge(context).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...request.purchaseOrders.map(
              (item) => _ProcurementItemTile(
                icon: Icons.shopping_cart_checkout_outlined,
                title: item.number.isNotEmpty ? item.number : 'Заказ #${item.id}',
                subtitle: [
                  item.supplierName,
                  if ((item.deliveryDate ?? '').trim().isNotEmpty) item.deliveryDate,
                  if (item.createdAt != null) _formatDateTime(item.createdAt!),
                ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' • '),
                badgeLabel: _purchaseOrderStatusLabel(item),
                badgeColor: _statusColor(item.status),
              ),
            ),
          ],
          if (request.purchaseRequests.isEmpty &&
              request.purchaseOrders.isEmpty &&
              !request.materialReserved &&
              !request.materialsReceived) ...[
            const SizedBox(height: 4),
            Text(
              'Связанных закупок по этой заявке пока нет.',
              style: AppTypography.bodyMedium(context).copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProcurementItemTile extends StatelessWidget {
  const _ProcurementItemTile({
    required this.icon,
    required this.title,
    required this.badgeLabel,
    required this.badgeColor,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String badgeLabel;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLarge(context).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((subtitle ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _StatusBadge(label: badgeLabel, color: badgeColor),
        ],
      ),
    );
  }
}

class _RequestGroupCard extends StatelessWidget {
  const _RequestGroupCard({required this.request});

  final SiteRequestModel request;

  @override
  Widget build(BuildContext context) {
    final items = request.groupItems.isNotEmpty
        ? request.groupItems
        : [
            SiteRequestGroupItem(
              id: request.serverId,
              title: request.title,
              status: request.status,
              statusLabel: _statusLabel(request),
              requestType: request.requestType,
              requestTypeLabel: _requestTypeLabel(request),
              materialName: request.materialName,
              materialQuantity: request.materialQuantity,
              materialUnit: request.materialUnit,
              assignedUserName: request.assignedUserName,
              isCurrent: true,
            ),
          ];

    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Состав заявки', style: AppTypography.h2(context)),
          const SizedBox(height: 8),
          Text(
            request.groupTitle?.trim().isNotEmpty == true
                ? request.groupTitle!
                : 'Группа материалов',
            style: AppTypography.bodyLarge(context).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Позиций в группе: ${request.groupRequestCount > 0 ? request.groupRequestCount : items.length}',
            style: AppTypography.bodyMedium(context),
          ),
          const SizedBox(height: 16),
          ...items.map((item) {
            final subtitle = [
              item.materialName ?? '',
              if (item.materialQuantity != null)
                '${_formatQuantity(item.materialQuantity!)} ${item.materialUnit ?? ''}'.trim(),
              item.assignedUserName ?? '',
            ].where((value) => value.trim().isNotEmpty).join(' • ');

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item.isCurrent
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                      : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: AppTypography.bodyLarge(context).copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (item.isCurrent)
                          _InfoLabel(label: 'Текущая'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle.isEmpty ? (item.requestTypeLabel ?? item.requestType) : subtitle,
                      style: AppTypography.bodyMedium(context),
                    ),
                    const SizedBox(height: 6),
                    _StatusBadge(
                      label: item.statusLabel,
                      color: _statusColor(item.status),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RequestDescriptionCard extends StatelessWidget {
  const _RequestDescriptionCard({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
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
}

class _RequestTextCard extends StatelessWidget {
  const _RequestTextCard({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.h2(context)),
          const SizedBox(height: 12),
          Text(description, style: AppTypography.bodyMedium(context)),
        ],
      ),
    );
  }
}

class _RequestHistoryCard extends StatelessWidget {
  const _RequestHistoryCard({required this.history});

  final List<SiteRequestHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('История обработки', style: AppTypography.h2(context)),
          const SizedBox(height: 16),
          ...history.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final statusChange = [
              item.oldStatusLabel,
              item.newStatusLabel,
            ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();

            return Padding(
              padding: EdgeInsets.only(bottom: index == history.length - 1 ? 0 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.actionLabel,
                          style: AppTypography.bodyLarge(context).copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if ((item.userName ?? '').trim().isNotEmpty ||
                            item.createdAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            [
                              item.userName,
                              if (item.createdAt != null) _formatDateTime(item.createdAt!),
                            ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' • '),
                            style: AppTypography.caption(context).copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (statusChange.length == 2) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${statusChange.first} → ${statusChange.last}',
                            style: AppTypography.bodyMedium(context),
                          ),
                        ],
                        if ((item.notes ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            item.notes!,
                            style: AppTypography.bodyMedium(context).copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SiteRequestActions extends StatelessWidget {
  const _SiteRequestActions({
    required this.transitions,
    required this.isLoading,
    required this.onTransitionSelected,
  });

  final List<SiteRequestTransition> transitions;
  final bool isLoading;
  final ValueChanged<SiteRequestTransition> onTransitionSelected;

  @override
  Widget build(BuildContext context) {
    if (transitions.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final sortedTransitions = [...transitions]..sort(_compareTransitions);
    final primaryTransition = sortedTransitions.first;
    final secondaryTransitions = sortedTransitions.skip(1).toList(growable: false);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.3 : 0.05,
            ),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProButton(
            text: _transitionActionLabel(primaryTransition),
            backgroundColor: _transitionColor(primaryTransition.status),
            isLoading: isLoading,
            onPressed: () => onTransitionSelected(primaryTransition),
          ),
          if (secondaryTransitions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: secondaryTransitions.map((transition) {
                return OutlinedButton(
                  onPressed: isLoading ? null : () => onTransitionSelected(transition),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _transitionColor(transition.status),
                  ),
                  child: Text(_transitionActionLabel(transition)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoLabel extends StatelessWidget {
  const _InfoLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: AppTypography.bodySmall(context)),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.caption(context).copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParamRow extends StatelessWidget {
  const _ParamRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: AppTypography.bodyMedium(context).copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyLarge(context).copyWith(
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<SiteRequestTransition> _resolvedTransitions(SiteRequestModel request) {
  if (request.availableTransitions.isNotEmpty) {
    return request.availableTransitions;
  }

  return switch (request.status.trim().toLowerCase()) {
    'draft' => const [
        SiteRequestTransition(status: 'pending'),
        SiteRequestTransition(status: 'cancelled'),
      ],
    'fulfilled' => const [
        SiteRequestTransition(status: 'completed'),
      ],
    _ => const [],
  };
}

bool _hasResourceSection(SiteRequestModel request) {
  return (request.materialName ?? '').trim().isNotEmpty ||
      request.materialQuantity != null ||
      (request.personnelTypeLabel ?? '').trim().isNotEmpty ||
      request.personnelCount != null ||
      (request.equipmentTypeLabel ?? request.equipmentType ?? '').trim().isNotEmpty;
}

bool _hasProcurementSection(SiteRequestModel request) {
  return request.purchaseRequests.isNotEmpty ||
      request.purchaseOrders.isNotEmpty ||
      request.materialReserved ||
      request.materialsReceived ||
      request.reservedQuantity != null ||
      request.reservedAt != null ||
      request.materialsReceivedAt != null ||
      request.warehouseId != null;
}

bool _hasGroupSection(SiteRequestModel request) {
  return request.groupRequestCount > 1 || request.groupItems.length > 1;
}

String _purchaseRequestStatusLabel(SiteRequestPurchaseRequestSummary item) {
  final label = item.statusLabel?.trim();
  if (label != null && label.isNotEmpty) {
    return label;
  }

  return switch (item.status.trim().toLowerCase()) {
    'draft' => 'Черновик',
    'pending' => 'На рассмотрении',
    'approved' => 'Согласована',
    'rejected' => 'Отклонена',
    'cancelled' => 'Отменена',
    _ => item.status.isNotEmpty ? item.status : 'Без статуса',
  };
}

String _purchaseOrderStatusLabel(SiteRequestPurchaseOrderSummary item) {
  final label = item.statusLabel?.trim();
  if (label != null && label.isNotEmpty) {
    return label;
  }

  return switch (item.status.trim().toLowerCase()) {
    'draft' => 'Черновик',
    'sent' => 'Отправлен поставщику',
    'confirmed' => 'Подтвержден поставщиком',
    'in_delivery' => 'В доставке',
    'delivered' => 'Доставлен',
    'cancelled' => 'Отменен',
    'approved' => 'Подтвержден',
    _ => item.status.isNotEmpty ? item.status : 'Без статуса',
  };
}

String _transitionActionLabel(SiteRequestTransition transition) {
  return switch (transition.status.trim().toLowerCase()) {
    'pending' => 'Отправить на согласование',
    'in_review' => 'Взять на рассмотрение',
    'approved' => 'Согласовать',
    'rejected' => 'Отклонить',
    'in_progress' => 'Запустить в работу',
    'fulfilled' => 'Отметить исполненной',
    'completed' => 'Подтвердить получение',
    'cancelled' => 'Отменить заявку',
    _ => transition.name?.trim().isNotEmpty == true
        ? transition.name!.trim()
        : transition.status,
  };
}

bool _statusRequiresReason(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'cancelled' || normalized == 'rejected';
}

int _compareTransitions(SiteRequestTransition left, SiteRequestTransition right) {
  return _transitionPriority(right.status).compareTo(_transitionPriority(left.status));
}

int _transitionPriority(String status) {
  return switch (status.trim().toLowerCase()) {
    'approved' => 80,
    'in_review' => 70,
    'in_progress' => 60,
    'fulfilled' => 50,
    'completed' => 40,
    'pending' => 30,
    'cancelled' => 20,
    'rejected' => 10,
    _ => 0,
  };
}

String _attentionTitle(SiteRequestModel request) {
  final status = request.status.trim().toLowerCase();

  if (_isUrgent(request.priority)) {
    return 'Срочная заявка';
  }

  return switch (status) {
    'draft' => 'Черновик еще не отправлен',
    'pending' || 'in_review' => 'Ожидает согласования',
    'approved' => 'Можно запускать в работу',
    'in_progress' => 'Заявка в исполнении',
    'fulfilled' => 'Нужно подтвердить получение',
    'completed' => 'Заявка уже закрыта',
    'cancelled' || 'rejected' => 'Заявка завершена без исполнения',
    _ => 'Проверьте текущее состояние заявки',
  };
}

String _attentionDescription(SiteRequestModel request) {
  final status = request.status.trim().toLowerCase();

  if (_isUrgent(request.priority)) {
    return 'Приоритет высокий: желательно быстро подтвердить дальнейшие действия по заявке.';
  }

  return switch (status) {
    'draft' => 'Чтобы заявка попала в работу, отправьте ее на согласование.',
    'pending' || 'in_review' => 'Заявка сейчас ожидает решения или проверки.',
    'approved' => 'Заявка уже согласована и должна перейти к исполнению.',
    'in_progress' => 'Исполнение уже началось, держите срок и обратную связь.',
    'fulfilled' => 'По заявке пришел результат, осталось подтвердить получение.',
    'completed' => 'Все действия по этой заявке завершены.',
    'cancelled' => 'Заявка была отменена и больше не требует действий.',
    'rejected' => 'Заявка отклонена и не пойдет в исполнение.',
    _ => 'Статус не распознан, проверьте карточку заявки вручную.',
  };
}

IconData _attentionIcon(SiteRequestModel request) {
  final status = request.status.trim().toLowerCase();

  if (_isUrgent(request.priority)) {
    return Icons.priority_high_rounded;
  }

  return switch (status) {
    'draft' => Icons.edit_note_rounded,
    'pending' || 'in_review' => Icons.hourglass_top_rounded,
    'approved' => Icons.play_circle_outline_rounded,
    'in_progress' => Icons.sync_rounded,
    'fulfilled' => Icons.inventory_2_outlined,
    'completed' => Icons.check_circle_outline_rounded,
    'cancelled' || 'rejected' => Icons.cancel_outlined,
    _ => Icons.info_outline_rounded,
  };
}

Color _attentionColor(SiteRequestModel request) {
  if (_isUrgent(request.priority)) {
    return AppColors.error;
  }

  return _statusColor(request.status);
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

String _priorityLabel(SiteRequestModel request) {
  final label = request.priorityLabel?.trim();
  if (label != null && label.isNotEmpty) {
    return label;
  }

  return switch (request.priority.trim().toLowerCase()) {
    'urgent' => 'Срочно',
    'high' => 'Высокий',
    'medium' => 'Средний',
    'low' => 'Низкий',
    _ => 'Не указан',
  };
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

String _requestSubtitle(SiteRequestModel request) {
  if ((request.materialName ?? '').trim().isNotEmpty) {
    final parts = <String>[
      request.materialName!,
      if (request.materialQuantity != null) _formatQuantity(request.materialQuantity!),
      if ((request.materialUnit ?? '').trim().isNotEmpty) request.materialUnit!,
    ];
    return parts.join(' ');
  }

  if ((request.personnelTypeLabel ?? '').trim().isNotEmpty) {
    final parts = <String>[
      request.personnelTypeLabel!,
      if (request.personnelCount != null) '${request.personnelCount} чел.',
    ];
    return parts.join(' • ');
  }

  if ((request.equipmentTypeLabel ?? request.equipmentType ?? '').trim().isNotEmpty) {
    return request.equipmentTypeLabel ?? request.equipmentType!;
  }

  return request.description?.trim().isNotEmpty == true
      ? request.description!
      : 'Без дополнительного описания';
}

Color _statusColor(String status) {
  return switch (status.trim().toLowerCase()) {
    'draft' => AppColors.textSecondary,
    'pending' => AppColors.warning,
    'pending_approval' => AppColors.warning,
    'in_review' => AppColors.primary,
    'approved' => AppColors.primary,
    'in_progress' => AppColors.secondary,
    'sent' => AppColors.primary,
    'confirmed' => AppColors.success,
    'in_delivery' => AppColors.warning,
    'fulfilled' => AppColors.success,
    'completed' => AppColors.success,
    'delivered' => AppColors.success,
    'on_hold' => AppColors.warning,
    'cancelled' || 'rejected' => AppColors.error,
    _ => AppColors.textSecondary,
  };
}

Color _priorityColor(String priority) {
  return switch (priority.trim().toLowerCase()) {
    'high' || 'urgent' => AppColors.error,
    'medium' => AppColors.warning,
    'normal' => AppColors.textSecondary,
    'low' => AppColors.success,
    _ => AppColors.textSecondary,
  };
}

Color _transitionColor(String status) {
  return switch (status.trim().toLowerCase()) {
    'approved' || 'completed' || 'fulfilled' => AppColors.success,
    'rejected' || 'cancelled' => AppColors.error,
    'pending' || 'in_review' => AppColors.primary,
    'in_progress' => AppColors.secondary,
    _ => AppColors.primary,
  };
}

bool _isUrgent(String priority) {
  final value = priority.trim().toLowerCase();
  return value == 'high' || value == 'urgent';
}

String _formatQuantity(double value) {
  return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

String _formatDateTime(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$day.$month.${dateTime.year} $hour:$minute';
}
