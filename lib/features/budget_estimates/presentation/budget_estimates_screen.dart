import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../../core/widgets/pro_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/budget_estimate_model.dart';
import '../domain/budget_estimates_provider.dart';

class BudgetEstimatesScreen extends ConsumerStatefulWidget {
  const BudgetEstimatesScreen({super.key});

  @override
  ConsumerState<BudgetEstimatesScreen> createState() =>
      _BudgetEstimatesScreenState();
}

class _BudgetEstimatesScreenState extends ConsumerState<BudgetEstimatesScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAndLoad();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(budgetEstimatesProvider);
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
          title: const Text('Сметы и бюджет'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed:
                  projectId == null
                      ? null
                      : () =>
                          ref
                              .read(budgetEstimatesProvider.notifier)
                              .loadSummary(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _buildBody(context, state, projectId),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    BudgetEstimatesState state,
    int? projectId,
  ) {
    if (projectId == null) {
      return const AppEmptyState(
        icon: Icons.domain_disabled_outlined,
        title: 'Выберите объект',
        description:
            'Сметная сводка открывается по выбранному объекту. Выберите объект на главном экране.',
      );
    }

    if (state.isLoading && state.summary == null) {
      return const AppLoadingState(message: 'Загружаем сметы');
    }

    if (state.error != null && state.summary == null) {
      return AppErrorState(
        title: _errorTitle(state),
        description: _errorDescription(state),
        onRetry: () => ref.read(budgetEstimatesProvider.notifier).loadSummary(),
      );
    }

    final summary = state.summary;
    if (summary == null) {
      return const AppLoadingState(message: 'Загружаем сметы');
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(budgetEstimatesProvider.notifier).loadSummary(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _BudgetHeader(summary: summary),
          const SizedBox(height: 12),
          _BudgetSummaryStrip(summary: summary),
          const SizedBox(height: 12),
          if (summary.assignedApprovals.isNotEmpty) ...[
            _SectionTitle(
              title: 'На согласовании',
              count: summary.assignedApprovals.length,
            ),
            const SizedBox(height: 8),
            ...summary.assignedApprovals.map(
              (estimate) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ApprovalCard(
                  estimate: estimate,
                  onApprove:
                      estimate.canApprove
                          ? () =>
                              _submitApproval(context, estimate, approve: true)
                          : null,
                  onRequestChanges:
                      estimate.canRequestChanges
                          ? () =>
                              _submitApproval(context, estimate, approve: false)
                          : null,
                ),
              ),
            ),
          ],
          _SectionTitle(
            title: 'Сметы объекта',
            count: summary.estimates.length,
          ),
          const SizedBox(height: 8),
          if (summary.estimates.isEmpty)
            const AppEmptyState(
              icon: Icons.calculate_outlined,
              title: 'Смет пока нет',
              description:
                  'По выбранному объекту еще нет сметных данных для просмотра.',
            )
          else
            ...summary.estimates.map(
              (estimate) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BudgetEstimateCard(
                  estimate: estimate,
                  onTap: () => _openDetail(estimate.id),
                ),
              ),
            ),
          if (summary.linkedChangeRequests.isNotEmpty) ...[
            const SizedBox(height: 4),
            _SectionTitle(
              title: 'Изменения бюджета',
              count: summary.linkedChangeRequests.length,
            ),
            const SizedBox(height: 8),
            ...summary.linkedChangeRequests.map(
              (change) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BudgetChangeCard(change: change),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _syncAndLoad() {
    final selectedProject = ref.read(projectsProvider).selectedProject;
    final notifier = ref.read(budgetEstimatesProvider.notifier);
    notifier.syncProject(selectedProject?.serverId);

    if (selectedProject?.serverId != null) {
      notifier.loadSummary();
    }
  }

  void _openDetail(int estimateId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BudgetEstimateDetailScreen(estimateId: estimateId),
      ),
    );
  }

  Future<void> _submitApproval(
    BuildContext context,
    BudgetEstimateModel estimate, {
    required bool approve,
  }) async {
    final comment = await _showCommentSheet(
      context,
      title: approve ? 'Согласовать смету' : 'Вернуть на доработку',
      requiredComment: !approve,
    );

    if (!context.mounted || comment == null) {
      return;
    }

    try {
      final notifier = ref.read(budgetEstimatesProvider.notifier);
      if (approve) {
        await notifier.approveEstimate(id: estimate.id, comment: comment);
      } else {
        await notifier.requestChanges(id: estimate.id, comment: comment);
      }

      if (!context.mounted) {
        return;
      }

      _message(context, approve ? 'Смета согласована' : 'Смета возвращена');
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _message(context, _actionErrorMessage(error));
    }
  }
}

class BudgetEstimateDetailScreen extends ConsumerStatefulWidget {
  const BudgetEstimateDetailScreen({required this.estimateId, super.key});

  final int estimateId;

  @override
  ConsumerState<BudgetEstimateDetailScreen> createState() =>
      _BudgetEstimateDetailScreenState();
}

class _BudgetEstimateDetailScreenState
    extends ConsumerState<BudgetEstimateDetailScreen> {
  late Future<BudgetEstimateDetailModel> _future;

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(budgetEstimatesProvider.notifier)
        .fetchEstimate(widget.estimateId);
  }

  void _reload() {
    setState(() {
      _future = ref
          .read(budgetEstimatesProvider.notifier)
          .fetchEstimate(widget.estimateId);
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
          title: const Text('Смета'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: FutureBuilder<BudgetEstimateDetailModel>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const AppLoadingState(message: 'Загружаем смету');
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return AppErrorState(
                title: 'Не удалось загрузить смету',
                description: _detailErrorDescription(snapshot.error),
                onRetry: _reload,
              );
            }

            final detail = snapshot.data!;
            final estimate = detail.estimate;

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  _BudgetEstimateCard(estimate: estimate),
                  if (estimate.canApprove || estimate.canRequestChanges) ...[
                    const SizedBox(height: 12),
                    _DetailActions(
                      estimate: estimate,
                      onApprove: () => _submitApproval(estimate, approve: true),
                      onRequestChanges:
                          () => _submitApproval(estimate, approve: false),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _SectionTitle(
                    title: 'Строки сметы',
                    count:
                        estimate.lineGroups.fold<int>(
                          0,
                          (sum, group) => sum + group.items.length,
                        ) +
                        estimate.unsectionedItems.length,
                  ),
                  const SizedBox(height: 8),
                  if (estimate.lineGroups.isEmpty &&
                      estimate.unsectionedItems.isEmpty)
                    const AppEmptyState(
                      icon: Icons.format_list_bulleted_rounded,
                      title: 'Строк нет',
                      description: 'В этой смете нет строк для просмотра.',
                    )
                  else ...[
                    ...estimate.lineGroups.map(
                      (group) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _LineGroupCard(group: group),
                      ),
                    ),
                    if (estimate.unsectionedItems.isNotEmpty)
                      _LineItemsCard(
                        title: 'Без раздела',
                        items: estimate.unsectionedItems,
                      ),
                  ],
                  if (detail.linkedChangeRequests.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _SectionTitle(
                      title: 'Связанные изменения',
                      count: detail.linkedChangeRequests.length,
                    ),
                    const SizedBox(height: 8),
                    ...detail.linkedChangeRequests.map(
                      (change) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BudgetChangeCard(change: change),
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

  Future<void> _submitApproval(
    BudgetEstimateModel estimate, {
    required bool approve,
  }) async {
    final comment = await _showCommentSheet(
      context,
      title: approve ? 'Согласовать смету' : 'Вернуть на доработку',
      requiredComment: !approve,
    );

    if (!mounted || comment == null) {
      return;
    }

    try {
      final notifier = ref.read(budgetEstimatesProvider.notifier);
      if (approve) {
        await notifier.approveEstimate(id: estimate.id, comment: comment);
      } else {
        await notifier.requestChanges(id: estimate.id, comment: comment);
      }
      _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _message(context, _actionErrorMessage(error));
    }
  }
}

class _BudgetHeader extends StatelessWidget {
  const _BudgetHeader({required this.summary});

  final BudgetEstimateSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.project.name,
            style: AppTypography.h2(context).copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Бюджет',
                  value: _formatMoney(summary.budget.projectBudgetAmount),
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Остаток',
                  value: _formatMoney(summary.budget.budgetRemaining),
                  color:
                      (summary.budget.budgetRemaining ?? 0) < 0
                          ? AppColors.error
                          : AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetSummaryStrip extends StatelessWidget {
  const _BudgetSummaryStrip({required this.summary});

  final BudgetEstimateSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'Сметы',
            value: summary.totals.estimatesCount.toString(),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            label: 'Согласовано',
            value: _formatMoney(summary.totals.approvedAmountWithVat),
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            label: 'Изменения',
            value: _formatMoney(summary.budget.pendingChangeDelta),
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }
}

class _BudgetEstimateCard extends StatelessWidget {
  const _BudgetEstimateCard({required this.estimate, this.onTap});

  final BudgetEstimateModel estimate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor(estimate.status, theme);

    return ProCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  estimate.name,
                  style: AppTypography.bodyLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w900),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(label: estimate.statusLabel, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            estimate.number,
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
                  value: _formatMoney(estimate.totals.amountWithVat),
                ),
              ),
              Expanded(
                child: _CompactFact(
                  label: 'Разделы',
                  value: estimate.statistics.sectionsCount.toString(),
                ),
              ),
              Expanded(
                child: _CompactFact(
                  label: 'Строки',
                  value: estimate.statistics.itemsCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.estimate,
    required this.onApprove,
    required this.onRequestChanges,
  });

  final BudgetEstimateModel estimate;
  final VoidCallback? onApprove;
  final VoidCallback? onRequestChanges;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            estimate.name,
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(_formatMoney(estimate.totals.amountWithVat)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (onRequestChanges != null)
                OutlinedButton.icon(
                  onPressed: onRequestChanges,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Доработка'),
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
      ),
    );
  }
}

class _DetailActions extends StatelessWidget {
  const _DetailActions({
    required this.estimate,
    required this.onApprove,
    required this.onRequestChanges,
  });

  final BudgetEstimateModel estimate;
  final VoidCallback onApprove;
  final VoidCallback onRequestChanges;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        if (estimate.canRequestChanges)
          OutlinedButton.icon(
            onPressed: onRequestChanges,
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Доработка'),
          ),
        if (estimate.canApprove)
          FilledButton.icon(
            onPressed: onApprove,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Согласовать'),
          ),
      ],
    );
  }
}

class _LineGroupCard extends StatelessWidget {
  const _LineGroupCard({required this.group});

  final BudgetEstimateLineGroupModel group;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${group.sectionNumber} ${group.name}',
                  style: AppTypography.bodyLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 10),
              Text(_formatMoney(group.totalAmount)),
            ],
          ),
          const SizedBox(height: 10),
          if (group.items.isEmpty)
            Text('В разделе нет строк', style: AppTypography.caption(context))
          else
            ...group.items.take(8).map(_LineItemRow.new),
          if (group.items.length > 8)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Еще ${group.items.length - 8} строк',
                style: AppTypography.caption(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _LineItemsCard extends StatelessWidget {
  const _LineItemsCard({required this.title, required this.items});

  final String title;
  final List<BudgetEstimateLineItemModel> items;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ...items.map(_LineItemRow.new),
        ],
      ),
    );
  }
}

class _LineItemRow extends StatelessWidget {
  const _LineItemRow(this.item);

  final BudgetEstimateLineItemModel item;

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
                  item.name,
                  style: AppTypography.bodyMedium(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (item.positionNumber != null) item.positionNumber!,
                    _quantityLabel(item),
                  ].where((part) => part.isNotEmpty).join(' · '),
                  style: AppTypography.caption(
                    context,
                  ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatMoney(item.currentTotalAmount ?? item.totalAmount),
            style: AppTypography.bodyMedium(
              context,
            ).copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _BudgetChangeCard extends StatelessWidget {
  const _BudgetChangeCard({required this.change});

  final BudgetChangeRequestModel change;

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
                  change.title,
                  style: AppTypography.bodyLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(
                label: change.statusLabel,
                color: _changeColor(change.status, theme),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            change.changeNumber,
            style: AppTypography.caption(
              context,
            ).copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CompactFact(
                  label: 'Влияние',
                  value: _formatMoney(change.costDelta),
                ),
              ),
              Expanded(
                child: _CompactFact(
                  label: 'Срок',
                  value:
                      change.scheduleDeltaDays == null
                          ? 'Не указан'
                          : '${change.scheduleDeltaDays} дн.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder:
        (_) => _CommentSheet(title: title, requiredComment: requiredComment),
  );
}

class _CommentSheet extends StatefulWidget {
  const _CommentSheet({required this.title, required this.requiredComment});

  final String title;
  final bool requiredComment;

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
        _validationMessage = 'Укажите, что нужно доработать';
      });
      return;
    }

    Navigator.of(context).pop(text);
  }
}

Color _statusColor(String status, ThemeData theme) {
  return switch (status) {
    'draft' => theme.colorScheme.onSurfaceVariant,
    'in_review' => AppColors.warning,
    'approved' => AppColors.success,
    'cancelled' => AppColors.error,
    _ => throw ArgumentError.value(status, 'status'),
  };
}

Color _changeColor(String status, ThemeData theme) {
  return switch (status) {
    'approved' => AppColors.success,
    'implemented' => AppColors.success,
    'closed' => AppColors.success,
    'rejected' => AppColors.error,
    'cancelled' => AppColors.error,
    'submitted' => AppColors.warning,
    'impact_assessment' => AppColors.warning,
    'internal_review' => AppColors.warning,
    'customer_review' => AppColors.warning,
    'draft' => theme.colorScheme.onSurfaceVariant,
    _ => throw ArgumentError.value(status, 'status'),
  };
}

String _formatMoney(double? value) {
  if (value == null) {
    return 'Не указан';
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

String _quantityLabel(BudgetEstimateLineItemModel item) {
  final quantity = item.quantityTotal ?? item.quantity;
  if (quantity == null) {
    return '';
  }

  final unit = item.measurementUnitLabel;
  final value = quantity.toStringAsFixed(
    quantity.truncateToDouble() == quantity ? 0 : 2,
  );

  return unit == null ? value : '$value $unit';
}

String _errorTitle(BudgetEstimatesState state) {
  if (state.permissionDenied) {
    return 'Нет доступа к сметам';
  }

  if (state.malformedContract) {
    return 'Данные смет требуют проверки';
  }

  return 'Не удалось загрузить сметы';
}

String _errorDescription(BudgetEstimatesState state) {
  if (state.permissionDenied) {
    return 'Для вашей роли не открыт просмотр смет выбранного объекта.';
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
    return 'Не удалось выполнить действие. Проверьте данные и повторите попытку.';
  }

  return error.toString();
}

void _message(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
