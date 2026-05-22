import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../../core/widgets/pro_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/procurement_model.dart';
import '../domain/procurement_provider.dart';

class ProcurementScreen extends ConsumerStatefulWidget {
  const ProcurementScreen({super.key});

  @override
  ConsumerState<ProcurementScreen> createState() => _ProcurementScreenState();
}

class _ProcurementScreenState extends ConsumerState<ProcurementScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAndLoad();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(procurementProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;
    final projectId = selectedProject?.serverId;

    if (state.projectId != projectId && !state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncAndLoad();
      });
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Закупки'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed:
                  () => ref.read(procurementProvider.notifier).loadSummary(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _buildBody(context, state, selectedProject?.name),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ProcurementState state,
    String? projectName,
  ) {
    if (state.isLoading && state.summary == null) {
      return const AppLoadingState(message: 'Загружаем закупки');
    }

    if (state.error != null && state.summary == null) {
      return AppErrorState(
        title: _errorTitle(state),
        description: _errorDescription(state),
        onRetry: () => ref.read(procurementProvider.notifier).loadSummary(),
      );
    }

    final summary = state.summary;
    if (summary == null) {
      return const AppLoadingState(message: 'Загружаем закупки');
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(procurementProvider.notifier).loadSummary(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _ProcurementHeader(summary: summary, projectName: projectName),
          const SizedBox(height: 12),
          _ProcurementSummaryStrip(counters: summary.counters),
          const SizedBox(height: 12),
          if (summary.isEmpty)
            const AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Закупок нет',
              description:
                  'Для выбранного контекста нет заявок, заказов поставщикам и согласований.',
            ),
          if (summary.assignedApprovals.isNotEmpty) ...[
            _SectionTitle(
              title: 'Согласования',
              count: summary.assignedApprovals.length,
            ),
            const SizedBox(height: 8),
            ...summary.assignedApprovals.map(
              (approval) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ApprovalCard(
                  approval: approval,
                  onApprove:
                      approval.canApprove
                          ? () =>
                              _submitApproval(context, approval, approve: true)
                          : null,
                  onReject:
                      approval.canReject
                          ? () =>
                              _submitApproval(context, approval, approve: false)
                          : null,
                ),
              ),
            ),
          ],
          if (summary.purchaseOrders.isNotEmpty) ...[
            _SectionTitle(
              title: 'Заказы поставщикам',
              count: summary.purchaseOrders.length,
            ),
            const SizedBox(height: 8),
            ...summary.purchaseOrders.map(
              (order) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PurchaseOrderCard(
                  order: order,
                  onTap: () => _openOrder(order.id),
                ),
              ),
            ),
          ],
          if (summary.purchaseRequests.isNotEmpty) ...[
            _SectionTitle(
              title: 'Заявки на закупку',
              count: summary.purchaseRequests.length,
            ),
            const SizedBox(height: 8),
            ...summary.purchaseRequests.map(
              (request) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PurchaseRequestCard(request: request),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _syncAndLoad() {
    final selectedProject = ref.read(projectsProvider).selectedProject;
    final notifier = ref.read(procurementProvider.notifier);
    notifier.syncProject(selectedProject?.serverId);
    notifier.loadSummary();
  }

  void _openOrder(int orderId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProcurementOrderDetailScreen(orderId: orderId),
      ),
    );
  }

  Future<void> _submitApproval(
    BuildContext context,
    ProcurementApprovalModel approval, {
    required bool approve,
  }) async {
    final comment = await _showCommentSheet(
      context,
      title: approve ? 'Согласовать закупку' : 'Отклонить закупку',
      requiredComment: !approve,
      emptyMessage:
          approve
              ? 'Введите комментарий или отправьте без него'
              : 'Укажите причину отклонения',
    );

    if (!context.mounted || comment == null) {
      return;
    }

    try {
      final notifier = ref.read(procurementProvider.notifier);
      if (approve) {
        await notifier.approveApproval(id: approval.id, comment: comment);
      } else {
        await notifier.rejectApproval(id: approval.id, comment: comment);
      }

      if (!context.mounted) {
        return;
      }

      _message(context, approve ? 'Закупка согласована' : 'Закупка отклонена');
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _message(context, _actionErrorMessage(error));
    }
  }
}

class ProcurementOrderDetailScreen extends ConsumerStatefulWidget {
  const ProcurementOrderDetailScreen({required this.orderId, super.key});

  final int orderId;

  @override
  ConsumerState<ProcurementOrderDetailScreen> createState() =>
      _ProcurementOrderDetailScreenState();
}

class _ProcurementOrderDetailScreenState
    extends ConsumerState<ProcurementOrderDetailScreen> {
  late Future<ProcurementOrderDetailModel> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(procurementProvider.notifier).fetchOrder(widget.orderId);
  }

  void _reload() {
    setState(() {
      _future = ref
          .read(procurementProvider.notifier)
          .fetchOrder(widget.orderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Заказ поставщику'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: FutureBuilder<ProcurementOrderDetailModel>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const AppLoadingState(message: 'Загружаем заказ');
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return AppErrorState(
                title: 'Не удалось загрузить заказ',
                description: _detailErrorDescription(snapshot.error),
                onRetry: _reload,
              );
            }

            final detail = snapshot.data!;
            final order = detail.order;

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  _PurchaseOrderCard(order: order),
                  if (order.canReceiveMaterials || order.canComment) ...[
                    const SizedBox(height: 12),
                    _OrderActionBar(
                      order: order,
                      onReceive:
                          order.canReceiveMaterials
                              ? () => _receiveMaterials(detail)
                              : null,
                      onComment:
                          order.canComment ? () => _addComment(order) : null,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _SectionTitle(
                    title: 'Позиции заказа',
                    count: order.items.length,
                  ),
                  const SizedBox(height: 8),
                  if (order.items.isEmpty)
                    const AppEmptyState(
                      icon: Icons.format_list_bulleted_rounded,
                      title: 'Позиции не указаны',
                      description: 'В заказе нет строк для приемки.',
                    )
                  else
                    ProCard(
                      child: Column(
                        children: order.items
                            .map(_OrderItemRow.new)
                            .toList(growable: false),
                      ),
                    ),
                  if (order.receipts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _SectionTitle(
                      title: 'Приемки',
                      count: order.receipts.length,
                    ),
                    const SizedBox(height: 8),
                    ...order.receipts.map(
                      (receipt) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ReceiptCard(receipt: receipt),
                      ),
                    ),
                  ],
                  if (order.comments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _SectionTitle(
                      title: 'Комментарии',
                      count: order.comments.length,
                    ),
                    const SizedBox(height: 8),
                    ...order.comments.map(
                      (comment) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CommentCard(comment: comment),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _receiveMaterials(ProcurementOrderDetailModel detail) async {
    final input = await showModalBottomSheet<_ReceiveMaterialsInput>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReceiveMaterialsSheet(detail: detail),
    );

    if (!mounted || input == null) {
      return;
    }

    try {
      await ref
          .read(procurementProvider.notifier)
          .receiveMaterials(
            orderId: detail.order.id,
            warehouseId: input.warehouseId,
            items: input.items,
            receiptDate: input.receiptDate,
            notes: input.notes,
          );

      if (!mounted) {
        return;
      }

      _reload();
      _message(context, 'Материалы приняты на склад');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _message(context, _actionErrorMessage(error));
    }
  }

  Future<void> _addComment(ProcurementPurchaseOrderModel order) async {
    final comment = await _showCommentSheet(
      context,
      title: 'Комментарий к заказу',
      requiredComment: true,
      emptyMessage: 'Введите комментарий',
    );

    if (!mounted || comment == null) {
      return;
    }

    try {
      await ref
          .read(procurementProvider.notifier)
          .addOrderComment(orderId: order.id, comment: comment);

      if (!mounted) {
        return;
      }

      _reload();
      _message(context, 'Комментарий добавлен');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _message(context, _actionErrorMessage(error));
    }
  }
}

class _ProcurementHeader extends StatelessWidget {
  const _ProcurementHeader({required this.summary, required this.projectName});

  final ProcurementSummaryModel summary;
  final String? projectName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            projectName ?? 'Все объекты',
            style: AppTypography.h2(context).copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Заказы поставщикам, приемка и согласования',
            style: AppTypography.caption(
              context,
            ).copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Согласования',
                  value: summary.counters.pendingApprovalsCount.toString(),
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'К приемке',
                  value: summary.counters.receivableOrdersCount.toString(),
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProcurementSummaryStrip extends StatelessWidget {
  const _ProcurementSummaryStrip({required this.counters});

  final ProcurementSummaryCounters counters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'Заявки',
            value: counters.purchaseRequestsCount.toString(),
            color: theme.colorScheme.secondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            label: 'В работе',
            value: counters.pendingRequestsCount.toString(),
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            label: 'Заказы',
            value: counters.purchaseOrdersCount.toString(),
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.approval,
    required this.onApprove,
    required this.onReject,
  });

  final ProcurementApprovalModel approval;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contextSummary = approval.contextSummary;
    final supplier =
        approval.decisionSummary?.supplierLabel ?? contextSummary.supplierLabel;

    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  approval.reasonLabel ?? approval.statusLabel,
                  style: AppTypography.bodyLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(
                label: approval.statusLabel,
                color: _approvalColor(approval.status, theme),
              ),
            ],
          ),
          if (supplier != null) ...[
            const SizedBox(height: 8),
            Text(
              supplier,
              style: AppTypography.caption(
                context,
              ).copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CompactFact(
                  label: 'Сумма',
                  value: _formatMoney(contextSummary.selectedTotal),
                ),
              ),
              Expanded(
                child: _CompactFact(
                  label: 'Отклонение',
                  value: _formatMoney(contextSummary.deltaAmount),
                ),
              ),
            ],
          ),
          if (approval.resolutionBlockers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              approval.resolutionBlockers
                  .map((blocker) => blocker.message)
                  .whereType<String>()
                  .join('\n'),
              style: AppTypography.caption(
                context,
              ).copyWith(color: AppColors.warning, fontWeight: FontWeight.w700),
            ),
          ],
          if (onReject != null || onApprove != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (onReject != null)
                  OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Отклонить'),
                  ),
                if (onApprove != null)
                  FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Согласовать'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PurchaseOrderCard extends StatelessWidget {
  const _PurchaseOrderCard({required this.order, this.onTap});

  final ProcurementPurchaseOrderModel order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supplierLabel = order.supplier.label ?? 'Поставщик не указан';

    return ProCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNumber,
                  style: AppTypography.bodyLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(
                label: order.statusLabel,
                color: _orderColor(order.status, theme),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            supplierLabel,
            style: AppTypography.caption(
              context,
            ).copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CompactFact(
                  label: 'Сумма',
                  value: _formatMoney(order.totalAmount),
                ),
              ),
              Expanded(
                child: _CompactFact(
                  label: 'Остаток',
                  value: _formatQuantity(order.remainingQuantity),
                ),
              ),
              Expanded(
                child: _CompactFact(
                  label: 'Приемки',
                  value: order.statistics.receiptsCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PurchaseRequestCard extends StatelessWidget {
  const _PurchaseRequestCard({required this.request});

  final ProcurementPurchaseRequestModel request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.title,
                  style: AppTypography.bodyLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w900),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(
                label: request.statusLabel,
                color: _requestColor(request.status, theme),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            request.requestNumber,
            style: AppTypography.caption(
              context,
            ).copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CompactFact(
                  label: 'Строки',
                  value: request.statistics.linesCount.toString(),
                ),
              ),
              Expanded(
                child: _CompactFact(
                  label: 'Заказы',
                  value: request.statistics.purchaseOrdersCount.toString(),
                ),
              ),
              Expanded(
                child: _CompactFact(
                  label: 'Бюджет',
                  value: _formatMoney(request.budgetAmount),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderActionBar extends StatelessWidget {
  const _OrderActionBar({
    required this.order,
    required this.onReceive,
    required this.onComment,
  });

  final ProcurementPurchaseOrderModel order;
  final VoidCallback? onReceive;
  final VoidCallback? onComment;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        if (onReceive != null)
          FilledButton.icon(
            onPressed: onReceive,
            icon: const Icon(Icons.move_to_inbox_rounded),
            label: const Text('Принять'),
          ),
        if (onComment != null)
          OutlinedButton.icon(
            onPressed: onComment,
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Комментарий'),
          ),
      ],
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow(this.item);

  final ProcurementPurchaseOrderItemModel item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.materialName,
                  style: AppTypography.bodyMedium(
                    context,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatQuantity(item.receivedQuantity)} из ${_formatQuantity(item.quantity)} ${item.unit}',
                  style: AppTypography.caption(
                    context,
                  ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatMoney(item.totalPrice),
            style: AppTypography.bodyMedium(
              context,
            ).copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.receipt});

  final ProcurementPurchaseReceiptModel receipt;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            receipt.receiptNumber,
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            [
              if (receipt.receiptDate != null) receipt.receiptDate!,
              if (receipt.warehouse != null) receipt.warehouse!.name,
            ].join(' · '),
            style: AppTypography.caption(context),
          ),
          if (receipt.lines.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...receipt.lines.map(
              (line) => Text(
                '${_formatQuantity(line.quantityReceived)} · ${_formatMoney(line.totalAmount)}',
                style: AppTypography.bodyMedium(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment});

  final ProcurementOrderCommentModel comment;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(comment.comment, style: AppTypography.bodyMedium(context)),
          const SizedBox(height: 8),
          Text(
            [
              if (comment.actorLabel != null) comment.actorLabel!,
              if (comment.occurredAt != null) comment.occurredAt!,
            ].join(' · '),
            style: AppTypography.caption(context),
          ),
        ],
      ),
    );
  }
}

class _ReceiveMaterialsSheet extends StatefulWidget {
  const _ReceiveMaterialsSheet({required this.detail});

  final ProcurementOrderDetailModel detail;

  @override
  State<_ReceiveMaterialsSheet> createState() => _ReceiveMaterialsSheetState();
}

class _ReceiveMaterialsSheetState extends State<_ReceiveMaterialsSheet> {
  final _dateController = TextEditingController();
  final _notesController = TextEditingController();
  final _quantityControllers = <int, TextEditingController>{};
  final _priceControllers = <int, TextEditingController>{};

  int? _warehouseId;
  String? _validationMessage;

  List<ProcurementPurchaseOrderItemModel> get _receivableItems {
    return widget.detail.order.items
        .where((item) => item.remainingQuantity > 0)
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();

    for (final item in _receivableItems) {
      _quantityControllers[item.id] = TextEditingController();
      _priceControllers[item.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _notesController.dispose();
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final warehouses = widget.detail.warehouses;
    final items = _receivableItems;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Приемка материалов', style: AppTypography.h2(context)),
          const SizedBox(height: 12),
          if (warehouses.isEmpty)
            const AppEmptyState(
              icon: Icons.warehouse_outlined,
              title: 'Активных складов нет',
              description: 'Приемка доступна после настройки склада.',
              minHeight: 160,
            )
          else
            DropdownButtonFormField<int>(
              key: const Key('procurement-receive-warehouse'),
              value: _warehouseId,
              decoration: const InputDecoration(
                labelText: 'Склад',
                border: OutlineInputBorder(),
              ),
              items: warehouses
                  .map(
                    (warehouse) => DropdownMenuItem<int>(
                      value: warehouse.id,
                      child: Text(warehouse.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                setState(() {
                  _warehouseId = value;
                  _validationMessage = null;
                });
              },
            ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('procurement-receive-date'),
            controller: _dateController,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: 'Дата приемки',
              hintText: '2026-05-22',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _clearValidation(),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Нет строк к приемке',
              description: 'Все позиции заказа уже приняты.',
              minHeight: 160,
            )
          else ...[
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReceiveItemFields(
                  item: item,
                  quantityController: _quantityControllers[item.id]!,
                  priceController: _priceControllers[item.id]!,
                  onChanged: _clearValidation,
                ),
              ),
            ),
            TextField(
              key: const Key('procurement-receive-notes'),
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Комментарий к приемке',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (_validationMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _validationMessage!,
              style: AppTypography.caption(
                context,
              ).copyWith(color: AppColors.error, fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  warehouses.isEmpty || items.isEmpty ? null : _submitReceive,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Принять материалы'),
            ),
          ),
        ],
      ),
    );
  }

  void _clearValidation() {
    if (_validationMessage == null) {
      return;
    }

    setState(() {
      _validationMessage = null;
    });
  }

  void _submitReceive() {
    final warehouseId = _warehouseId;
    if (warehouseId == null) {
      _setValidation('Выберите склад приемки');
      return;
    }

    final receiptDate = _dateController.text.trim();
    if (!_isDate(receiptDate)) {
      _setValidation('Укажите дату приемки в формате ГГГГ-ММ-ДД');
      return;
    }

    final items = <ProcurementReceiveItemPayload>[];

    for (final item in _receivableItems) {
      final quantityText = _quantityControllers[item.id]!.text.trim();
      final priceText = _priceControllers[item.id]!.text.trim();
      final hasQuantity = quantityText.isNotEmpty;
      final hasPrice = priceText.isNotEmpty;

      if (!hasQuantity && !hasPrice) {
        continue;
      }

      if (!hasQuantity || !hasPrice) {
        _setValidation('Заполните количество и цену для выбранных строк');
        return;
      }

      final quantity = _parseDecimal(quantityText);
      final price = _parseDecimal(priceText);

      if (quantity == null || quantity <= 0) {
        _setValidation('Количество должно быть больше нуля');
        return;
      }

      if (quantity > item.remainingQuantity) {
        _setValidation('Количество не должно превышать остаток по заказу');
        return;
      }

      if (price == null || price < 0) {
        _setValidation('Цена должна быть не меньше нуля');
        return;
      }

      items.add(
        ProcurementReceiveItemPayload(
          itemId: item.id,
          quantityReceived: quantity,
          price: price,
        ),
      );
    }

    if (items.isEmpty) {
      _setValidation('Укажите хотя бы одну позицию для приемки');
      return;
    }

    Navigator.of(context).pop(
      _ReceiveMaterialsInput(
        warehouseId: warehouseId,
        receiptDate: receiptDate,
        items: items,
        notes: _notesController.text.trim(),
      ),
    );
  }

  void _setValidation(String message) {
    setState(() {
      _validationMessage = message;
    });
  }
}

class _ReceiveItemFields extends StatelessWidget {
  const _ReceiveItemFields({
    required this.item,
    required this.quantityController,
    required this.priceController,
    required this.onChanged,
  });

  final ProcurementPurchaseOrderItemModel item;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.materialName,
            style: AppTypography.bodyMedium(
              context,
            ).copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Остаток ${_formatQuantity(item.remainingQuantity)} ${item.unit}',
            style: AppTypography.caption(context),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: Key('procurement-receive-quantity-${item.id}'),
                  controller: quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Количество',
                    suffixText: item.unit,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: Key('procurement-receive-price-${item.id}'),
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Цена',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiveMaterialsInput {
  const _ReceiveMaterialsInput({
    required this.warehouseId,
    required this.receiptDate,
    required this.items,
    required this.notes,
  });

  final int warehouseId;
  final String receiptDate;
  final List<ProcurementReceiveItemPayload> items;
  final String notes;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: AppTypography.caption(
              context,
            ).copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.bodyLarge(context).copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CompactFact extends StatelessWidget {
  const _CompactFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption(
            context,
          ).copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTypography.bodyMedium(
            context,
          ).copyWith(fontWeight: FontWeight.w900),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.caption(
          context,
        ).copyWith(fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        Text(count.toString(), style: AppTypography.caption(context)),
      ],
    );
  }
}

Future<String?> _showCommentSheet(
  BuildContext context, {
  required String title,
  required bool requiredComment,
  required String emptyMessage,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder:
        (_) => _CommentSheet(
          title: title,
          requiredComment: requiredComment,
          emptyMessage: emptyMessage,
        ),
  );
}

class _CommentSheet extends StatefulWidget {
  const _CommentSheet({
    required this.title,
    required this.requiredComment,
    required this.emptyMessage,
  });

  final String title;
  final bool requiredComment;
  final String emptyMessage;

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final _controller = TextEditingController();
  String? _validationMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: AppTypography.h2(context)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText:
                  widget.requiredComment
                      ? 'Комментарий'
                      : 'Комментарий при необходимости',
              border: const OutlineInputBorder(),
              errorText: _validationMessage,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              child: const Text('Отправить'),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final text = _controller.text.trim();
    if (widget.requiredComment && text.isEmpty) {
      setState(() {
        _validationMessage = widget.emptyMessage;
      });
      return;
    }

    Navigator.of(context).pop(text);
  }
}

Color _requestColor(String status, ThemeData theme) {
  return switch (status) {
    'approved' => AppColors.success,
    'pending' => AppColors.warning,
    'rejected' => AppColors.error,
    'cancelled' => AppColors.error,
    'draft' => theme.colorScheme.onSurfaceVariant,
    _ => theme.colorScheme.primary,
  };
}

Color _orderColor(String status, ThemeData theme) {
  return switch (status) {
    'delivered' => AppColors.success,
    'partially_delivered' => AppColors.warning,
    'in_delivery' => AppColors.warning,
    'confirmed' => theme.colorScheme.primary,
    'sent' => theme.colorScheme.secondary,
    'cancelled' => AppColors.error,
    'draft' => theme.colorScheme.onSurfaceVariant,
    _ => theme.colorScheme.primary,
  };
}

Color _approvalColor(String status, ThemeData theme) {
  return switch (status) {
    'approved' => AppColors.success,
    'pending' => AppColors.warning,
    'rejected' => AppColors.error,
    'cancelled' => AppColors.error,
    _ => theme.colorScheme.primary,
  };
}

String _formatMoney(double? value) {
  if (value == null) {
    return 'Не указано';
  }

  final sign = value < 0 ? '-' : '';
  final fixed = value.abs().toStringAsFixed(0);
  final buffer = StringBuffer(sign);
  for (var index = 0; index < fixed.length; index++) {
    final left = fixed.length - index;
    buffer.write(fixed[index]);
    if (left > 1 && left % 3 == 1) {
      buffer.write(' ');
    }
  }

  return '${buffer.toString()} ₽';
}

String _formatQuantity(double value) {
  return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 3);
}

double? _parseDecimal(String value) {
  return double.tryParse(value.replaceAll(',', '.'));
}

bool _isDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return false;
  }

  return DateTime.tryParse(value) != null;
}

String _errorTitle(ProcurementState state) {
  if (state.permissionDenied) {
    return 'Нет доступа к закупкам';
  }

  if (state.malformedContract) {
    return 'Данные закупок требуют проверки';
  }

  return 'Не удалось загрузить закупки';
}

String _errorDescription(ProcurementState state) {
  if (state.permissionDenied) {
    return 'Для вашей роли не открыт просмотр закупок.';
  }

  if (state.malformedContract) {
    return 'Сервер вернул неполные данные для мобильного приложения.';
  }

  return state.error ?? 'Повторите попытку позже.';
}

String _detailErrorDescription(Object? error) {
  if (error is FormatException) {
    return 'Сервер вернул неполные данные для мобильного приложения.';
  }

  return error?.toString() ?? 'Повторите попытку позже.';
}

String _actionErrorMessage(Object error) {
  if (error is ArgumentError || error is FormatException) {
    return 'Проверьте заполненные данные и повторите действие.';
  }

  return error.toString();
}

void _message(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
