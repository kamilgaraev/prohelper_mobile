import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../../core/widgets/pro_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/workflow_task_model.dart';
import '../domain/workflow_provider.dart';

class WorkflowManagementScreen extends ConsumerStatefulWidget {
  const WorkflowManagementScreen({super.key});

  @override
  ConsumerState<WorkflowManagementScreen> createState() =>
      _WorkflowManagementScreenState();
}

class _WorkflowManagementScreenState
    extends ConsumerState<WorkflowManagementScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedProject = ref.read(projectsProvider).selectedProject;
      final notifier = ref.read(workflowProvider.notifier);
      notifier.syncProject(selectedProject?.serverId);
      notifier.loadTasks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workflowProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;

    if (selectedProject?.serverId != state.projectFilter && !state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(workflowProvider.notifier);
        notifier.syncProject(selectedProject?.serverId);
        notifier.loadTasks();
      });
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Согласования'),
          actions: [
            IconButton(
              tooltip: 'Обновить согласования',
              onPressed: () => ref.read(workflowProvider.notifier).loadTasks(),
              icon: const Icon(
                Icons.refresh_rounded,
                semanticLabel: 'Обновить согласования',
              ),
            ),
          ],
        ),
        body: _WorkflowSafeBody(
          child:
              state.isLoading && state.tasks.isEmpty
                  ? const AppLoadingState(message: 'Загружаем согласования')
                  : state.error != null && state.tasks.isEmpty
                  ? AppErrorState(
                    title:
                        state.permissionDenied
                            ? 'Нет доступа к согласованиям'
                            : state.malformedContract
                            ? 'Данные согласований требуют проверки'
                            : 'Не удалось загрузить согласования',
                    description: state.error,
                    onRetry:
                        () => ref.read(workflowProvider.notifier).loadTasks(),
                  )
                  : RefreshIndicator(
                    onRefresh:
                        () => ref.read(workflowProvider.notifier).loadTasks(),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: [
                        _WorkflowSummaryStrip(state: state),
                        const SizedBox(height: 12),
                        _WorkflowFilterPanel(
                          state: state,
                          searchController: _searchController,
                          onAssignedChanged: _changeAssignedFilter,
                          onStatusChanged: _changeStatusFilter,
                          onSearchSubmitted: _changeSearch,
                        ),
                        const SizedBox(height: 12),
                        if (state.tasks.isEmpty)
                          const AppEmptyState(
                            icon: Icons.hub_outlined,
                            title: 'Согласований нет',
                            description:
                                'По текущим фильтрам нет выполненных работ для согласования.',
                          )
                        else
                          ...state.tasks.map(
                            (task) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _WorkflowTaskCard(
                                task: task,
                                onOpen: () => _openDetail(task),
                                onApprove:
                                    () => _submitAction(
                                      context,
                                      task,
                                      _WorkflowAction.approve,
                                    ),
                                onReject:
                                    () => _submitAction(
                                      context,
                                      task,
                                      _WorkflowAction.reject,
                                    ),
                                onRequestChanges:
                                    () => _submitAction(
                                      context,
                                      task,
                                      _WorkflowAction.requestChanges,
                                    ),
                                onComment:
                                    () => _submitAction(
                                      context,
                                      task,
                                      _WorkflowAction.comment,
                                    ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
        ),
      ),
    );
  }

  void _changeAssignedFilter(bool assignedToMe) {
    final notifier = ref.read(workflowProvider.notifier);
    notifier.setAssignedToMe(assignedToMe);
    notifier.loadTasks();
  }

  void _changeStatusFilter(String? status) {
    final notifier = ref.read(workflowProvider.notifier);
    notifier.setStatusFilter(status);
    notifier.loadTasks();
  }

  void _changeSearch(String? value) {
    final notifier = ref.read(workflowProvider.notifier);
    notifier.setSearch(value);
    notifier.loadTasks();
  }

  void _openDetail(WorkflowTaskModel task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkflowTaskDetailScreen(taskId: task.id),
      ),
    );
  }

  Future<void> _submitAction(
    BuildContext context,
    WorkflowTaskModel task,
    _WorkflowAction action,
  ) async {
    await _showWorkflowActionSheet(
      context: context,
      ref: ref,
      task: task,
      action: action,
    );
  }
}

class _WorkflowSafeBody extends StatelessWidget {
  const _WorkflowSafeBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(top: false, left: false, right: false, child: child);
  }
}

class WorkflowTaskDetailScreen extends ConsumerStatefulWidget {
  const WorkflowTaskDetailScreen({required this.taskId, super.key});

  final int taskId;

  @override
  ConsumerState<WorkflowTaskDetailScreen> createState() =>
      _WorkflowTaskDetailScreenState();
}

class _WorkflowTaskDetailScreenState
    extends ConsumerState<WorkflowTaskDetailScreen> {
  late Future<WorkflowTaskModel> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(workflowProvider.notifier).fetchTask(widget.taskId);
  }

  void _reload() {
    setState(() {
      _future = ref.read(workflowProvider.notifier).fetchTask(widget.taskId);
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
          title: const Text('Детали согласования'),
          actions: [
            IconButton(
              tooltip: 'Обновить согласование',
              onPressed: _reload,
              icon: const Icon(
                Icons.refresh_rounded,
                semanticLabel: 'Обновить согласование',
              ),
            ),
          ],
        ),
        body: _WorkflowSafeBody(
          child: FutureBuilder<WorkflowTaskModel>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const AppLoadingState(message: 'Загружаем согласование');
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return AppErrorState(
                  title: 'Не удалось загрузить согласование',
                  description:
                      snapshot.error == null
                          ? null
                          : UserMessage.fromError(snapshot.error!),
                  onRetry: _reload,
                );
              }

              final task = snapshot.data!;

              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    _WorkflowTaskDetail(task: task),
                    const SizedBox(height: 16),
                    _WorkflowActionPanel(
                      task: task,
                      onApprove:
                          () => _showWorkflowActionSheet(
                            context: context,
                            ref: ref,
                            task: task,
                            action: _WorkflowAction.approve,
                            onDone: _reload,
                          ),
                      onReject:
                          () => _showWorkflowActionSheet(
                            context: context,
                            ref: ref,
                            task: task,
                            action: _WorkflowAction.reject,
                            onDone: _reload,
                          ),
                      onRequestChanges:
                          () => _showWorkflowActionSheet(
                            context: context,
                            ref: ref,
                            task: task,
                            action: _WorkflowAction.requestChanges,
                            onDone: _reload,
                          ),
                      onComment:
                          () => _showWorkflowActionSheet(
                            context: context,
                            ref: ref,
                            task: task,
                            action: _WorkflowAction.comment,
                            onDone: _reload,
                          ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

Future<void> _showWorkflowActionSheet({
  required BuildContext context,
  required WidgetRef ref,
  required WorkflowTaskModel task,
  required _WorkflowAction action,
  VoidCallback? onDone,
}) async {
  final controller = TextEditingController();
  var submitting = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder:
        (sheetContext) => StatefulBuilder(
          builder:
              (context, setSheetState) => Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _actionTitle(action),
                      style: AppTypography.h2(context),
                    ),
                    const SizedBox(height: 8),
                    Text(task.title, style: AppTypography.bodyLarge(context)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: _inputLabel(action),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed:
                          submitting
                              ? null
                              : () async {
                                final text = controller.text.trim();
                                if (_requiresText(action) && text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _requiredTextMessage(action),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setSheetState(() => submitting = true);
                                try {
                                  final notifier = ref.read(
                                    workflowProvider.notifier,
                                  );

                                  switch (action) {
                                    case _WorkflowAction.approve:
                                      await notifier.approveTask(
                                        task.id,
                                        comment: text.isEmpty ? null : text,
                                      );
                                    case _WorkflowAction.reject:
                                      await notifier.rejectTask(
                                        id: task.id,
                                        reason: text,
                                      );
                                    case _WorkflowAction.requestChanges:
                                      await notifier.requestChanges(
                                        id: task.id,
                                        comment: text,
                                      );
                                    case _WorkflowAction.comment:
                                      await notifier.addComment(
                                        id: task.id,
                                        comment: text,
                                      );
                                  }

                                  onDone?.call();
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                } finally {
                                  if (context.mounted) {
                                    setSheetState(() => submitting = false);
                                  }
                                }
                              },
                      icon: Icon(_actionIcon(action)),
                      label: Text(
                        submitting ? 'Выполняем...' : _actionButton(action),
                      ),
                    ),
                  ],
                ),
              ),
        ),
  );
}

class _WorkflowSummaryStrip extends StatelessWidget {
  const _WorkflowSummaryStrip({required this.state});

  final WorkflowState state;

  @override
  Widget build(BuildContext context) {
    final pending =
        state.summary?.byStatus['pending'] ??
        state.tasks.where((task) => task.status == 'pending').length;
    final inReview =
        state.summary?.byStatus['in_review'] ??
        state.tasks.where((task) => task.status == 'in_review').length;
    final confirmed =
        state.summary?.byStatus['confirmed'] ??
        state.tasks.where((task) => task.status == 'confirmed').length;

    return Row(
      children: [
        Expanded(child: _SummaryTile(label: 'Ожидают', value: '$pending')),
        const SizedBox(width: 8),
        Expanded(child: _SummaryTile(label: 'Доработка', value: '$inReview')),
        const SizedBox(width: 8),
        Expanded(child: _SummaryTile(label: 'Готово', value: '$confirmed')),
      ],
    );
  }
}

class _WorkflowFilterPanel extends StatefulWidget {
  const _WorkflowFilterPanel({
    required this.state,
    required this.searchController,
    required this.onAssignedChanged,
    required this.onStatusChanged,
    required this.onSearchSubmitted,
  });

  final WorkflowState state;
  final TextEditingController searchController;
  final ValueChanged<bool> onAssignedChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onSearchSubmitted;

  @override
  State<_WorkflowFilterPanel> createState() => _WorkflowFilterPanelState();
}

class _WorkflowFilterPanelState extends State<_WorkflowFilterPanel> {
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_handleSearchChanged);
    _searchFocusNode.addListener(_handleSearchChanged);
  }

  @override
  void didUpdateWidget(covariant _WorkflowFilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController == widget.searchController) {
      return;
    }

    oldWidget.searchController.removeListener(_handleSearchChanged);
    widget.searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_handleSearchChanged);
    _searchFocusNode
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _setSearchText(String value) {
    widget.searchController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    if ((widget.state.search ?? '') != widget.searchController.text.trim()) {
      widget.searchController.removeListener(_handleSearchChanged);
      widget.searchController.text = widget.state.search ?? '';
      widget.searchController.addListener(_handleSearchChanged);
    }
    final hasSearch = widget.searchController.text.isNotEmpty;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: ProCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: AlignmentDirectional.centerEnd,
              children: [
                Semantics(
                  container: true,
                  excludeSemantics: true,
                  label: 'Поиск по согласованиям',
                  value: widget.searchController.text,
                  textField: true,
                  enabled: true,
                  focusable: true,
                  focused: _searchFocusNode.hasFocus,
                  onTap: _searchFocusNode.requestFocus,
                  onSetText: _setSearchText,
                  child: TextField(
                    focusNode: _searchFocusNode,
                    controller: widget.searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      labelText: 'Поиск',
                      suffixIcon:
                          hasSearch
                              ? const SizedBox(width: kMinInteractiveDimension)
                              : null,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: widget.onSearchSubmitted,
                  ),
                ),
                if (hasSearch)
                  PositionedDirectional(
                    top: 0,
                    end: 0,
                    bottom: 0,
                    child: Center(
                      child: Semantics(
                        container: true,
                        button: true,
                        enabled: true,
                        label: 'Очистить поиск',
                        onTap: () {
                          widget.searchController.clear();
                          widget.onSearchSubmitted(null);
                        },
                        child: ExcludeSemantics(
                          child: IconButton(
                            tooltip: 'Очистить поиск',
                            onPressed: () {
                              widget.searchController.clear();
                              widget.onSearchSubmitted(null);
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              container: true,
              explicitChildNodes: true,
              label: 'Фильтры согласований',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Мне'),
                    selected: widget.state.assignedToMe,
                    onSelected: widget.onAssignedChanged,
                    avatar: const Icon(
                      Icons.person_pin_circle_outlined,
                      size: 16,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  ..._workflowStatusFilters.map(
                    (option) => ChoiceChip(
                      label: Text(option.label),
                      selected: widget.state.statusFilter == option.value,
                      onSelected: (_) => widget.onStatusChanged(option.value),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowTaskCard extends StatelessWidget {
  const _WorkflowTaskCard({
    required this.task,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
    required this.onRequestChanges,
    required this.onComment,
  });

  final WorkflowTaskModel task;
  final VoidCallback onOpen;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRequestChanges;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSecondaryActions = task.canRequestChanges || task.canComment;
    final actionContext = '${task.title}, задача ${task.id}';

    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: AppTypography.bodyLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              _StatusBadge(status: task.status, label: task.statusLabel),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (task.projectLabel != null)
                _InfoChip(
                  icon: Icons.domain_outlined,
                  label: task.projectLabel!,
                ),
              if (task.assignedUserLabel != null)
                _InfoChip(
                  icon: Icons.person_outline_rounded,
                  label: task.assignedUserLabel!,
                ),
              if (task.completionDate != null)
                _InfoChip(
                  icon: Icons.event_available_outlined,
                  label: _formatDate(task.completionDate!),
                ),
            ],
          ),
          if (task.notes != null) ...[
            const SizedBox(height: 8),
            Text(
              task.notes!,
              style: AppTypography.bodyMedium(
                context,
              ).copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _WorkflowCardActionButton(
                semanticsLabel: 'Открыть согласование: $actionContext',
                onTap: onOpen,
                child: TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Подробнее'),
                ),
              ),
              if (task.canApprove)
                _WorkflowCardActionButton(
                  semanticsLabel: 'Согласовать: $actionContext',
                  onTap: onApprove,
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Согласовать'),
                  ),
                ),
              if (task.canReject)
                _WorkflowCardActionButton(
                  semanticsLabel: 'Отклонить: $actionContext',
                  onTap: onReject,
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Отклонить'),
                  ),
                ),
              if (hasSecondaryActions)
                Builder(
                  builder: (context) {
                    void showActions() => _showSecondaryActions(context);

                    return _WorkflowCardActionButton(
                      semanticsLabel:
                          'Показать дополнительные действия: $actionContext',
                      onTap: showActions,
                      child: OutlinedButton.icon(
                        onPressed: showActions,
                        icon: const Icon(Icons.more_horiz_rounded),
                        label: const Text('Ещё'),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showSecondaryActions(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        void closeAndRun(VoidCallback callback) {
          Navigator.of(sheetContext).pop();
          callback();
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Дополнительные действия',
                  style: AppTypography.h2(sheetContext),
                ),
                const SizedBox(height: 8),
                if (task.canRequestChanges)
                  ListTile(
                    leading: const Icon(Icons.edit_note_rounded),
                    title: const Text('Запросить изменения'),
                    onTap: () => closeAndRun(onRequestChanges),
                  ),
                if (task.canComment)
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline_rounded),
                    title: const Text('Комментарий'),
                    onTap: () => closeAndRun(onComment),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WorkflowTaskDetail extends StatelessWidget {
  const _WorkflowTaskDetail({required this.task});

  final WorkflowTaskModel task;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.title, style: AppTypography.h2(context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusBadge(status: task.status, label: task.statusLabel),
              if (task.workOriginLabel != null)
                _InfoChip(
                  icon: Icons.source_outlined,
                  label: task.workOriginLabel!,
                ),
              if (task.planningStatusLabel != null)
                _InfoChip(
                  icon: Icons.timeline_outlined,
                  label: task.planningStatusLabel!,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (task.projectLabel != null)
            _DetailLine(label: 'Объект', value: task.projectLabel!),
          if (task.contractLabel != null)
            _DetailLine(label: 'Договор', value: task.contractLabel!),
          if (task.contractorLabel != null)
            _DetailLine(label: 'Подрядчик', value: task.contractorLabel!),
          if (task.assignedUserLabel != null)
            _DetailLine(label: 'Ответственный', value: task.assignedUserLabel!),
          if (task.scheduleTaskLabel != null)
            _DetailLine(label: 'Задача', value: task.scheduleTaskLabel!),
          if (task.estimateItemLabel != null)
            _DetailLine(label: 'Позиция сметы', value: task.estimateItemLabel!),
          if (task.completionDate != null)
            _DetailLine(
              label: 'Дата',
              value: _formatDate(task.completionDate!),
            ),
          if (task.quantity != null)
            _DetailLine(
              label: 'Объем',
              value: _quantityText(task.quantity!, task.measurementUnitLabel),
            ),
          if (task.completedQuantity != null)
            _DetailLine(
              label: 'Выполнено',
              value: _quantityText(
                task.completedQuantity!,
                task.measurementUnitLabel,
              ),
            ),
          if (task.totalAmount != null)
            _DetailLine(label: 'Сумма', value: _moneyText(task.totalAmount!)),
          if (task.notes != null) ...[
            const SizedBox(height: 8),
            Text('Примечание', style: AppTypography.caption(context)),
            const SizedBox(height: 4),
            Text(task.notes!, style: AppTypography.bodyMedium(context)),
          ],
          if (task.statusHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('История', style: AppTypography.h2(context)),
            const SizedBox(height: 8),
            ...task.statusHistory.map(
              (entry) => _WorkflowEntryRow(entry: entry),
            ),
          ],
          if (task.comments.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Комментарии', style: AppTypography.h2(context)),
            const SizedBox(height: 8),
            ...task.comments.map((entry) => _WorkflowEntryRow(entry: entry)),
          ],
        ],
      ),
    );
  }
}

class _WorkflowCardActionButton extends StatelessWidget {
  const _WorkflowCardActionButton({
    required this.semanticsLabel,
    required this.onTap,
    required this.child,
  });

  final String semanticsLabel;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: true,
      excludeSemantics: true,
      label: semanticsLabel,
      onTap: onTap,
      child: child,
    );
  }
}

class _WorkflowActionPanel extends StatelessWidget {
  const _WorkflowActionPanel({
    required this.task,
    required this.onApprove,
    required this.onReject,
    required this.onRequestChanges,
    required this.onComment,
  });

  final WorkflowTaskModel task;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRequestChanges;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    if (task.availableActions.isEmpty) {
      return const SizedBox.shrink();
    }

    final actionContext = '${task.title}, задача ${task.id}';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (task.canApprove)
          _WorkflowCardActionButton(
            semanticsLabel: 'Согласовать: $actionContext',
            onTap: onApprove,
            child: FilledButton.icon(
              onPressed: onApprove,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Согласовать'),
            ),
          ),
        if (task.canReject)
          _WorkflowCardActionButton(
            semanticsLabel: 'Отклонить: $actionContext',
            onTap: onReject,
            child: OutlinedButton.icon(
              onPressed: onReject,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Отклонить'),
            ),
          ),
        if (task.canRequestChanges)
          _WorkflowCardActionButton(
            semanticsLabel: 'Запросить изменения: $actionContext',
            onTap: onRequestChanges,
            child: OutlinedButton.icon(
              onPressed: onRequestChanges,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Запросить изменения'),
            ),
          ),
        if (task.canComment)
          _WorkflowCardActionButton(
            semanticsLabel: 'Добавить комментарий: $actionContext',
            onTap: onComment,
            child: OutlinedButton.icon(
              onPressed: onComment,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Комментарий'),
            ),
          ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption(context)),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.h2(context)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'confirmed' => AppColors.success,
      'rejected' => AppColors.error,
      'in_review' => AppColors.warning,
      'cancelled' => Theme.of(context).colorScheme.onSurfaceVariant,
      _ => Theme.of(context).colorScheme.primary,
    };

    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.2)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: Text(label, style: AppTypography.caption(context)),
          ),
          Expanded(
            child: Text(value, style: AppTypography.bodyMedium(context)),
          ),
        ],
      ),
    );
  }
}

class _WorkflowEntryRow extends StatelessWidget {
  const _WorkflowEntryRow({required this.entry});

  final WorkflowTaskEntryModel entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_entryIcon(entry.action), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _entryLabel(entry),
                  style: AppTypography.bodyMedium(context),
                ),
                if (entry.comment != null)
                  Text(entry.comment!, style: AppTypography.caption(context)),
                Text(
                  _formatDate(entry.createdAt),
                  style: AppTypography.caption(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _entryIcon(String action) {
  return switch (action) {
    'approve' => Icons.check_circle_outline_rounded,
    'reject' => Icons.cancel_outlined,
    'request_changes' => Icons.edit_note_rounded,
    'comment' => Icons.chat_bubble_outline_rounded,
    _ => throw ArgumentError.value(action, 'action'),
  };
}

String _entryLabel(WorkflowTaskEntryModel entry) {
  return switch (entry.action) {
    'approve' => 'Согласовано',
    'reject' => 'Отклонено',
    'request_changes' => 'Запрошены изменения',
    'comment' => 'Комментарий',
    _ => throw ArgumentError.value(entry.action, 'action'),
  };
}

String _formatDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }

  return '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
}

String _quantityText(double value, String? unit) {
  final text = value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  return unit == null ? text : '$text $unit';
}

String _moneyText(double value) {
  return '${value.toStringAsFixed(2)} ₽';
}

String _actionTitle(_WorkflowAction action) {
  return switch (action) {
    _WorkflowAction.approve => 'Согласовать работу',
    _WorkflowAction.reject => 'Отклонить работу',
    _WorkflowAction.requestChanges => 'Запросить изменения',
    _WorkflowAction.comment => 'Добавить комментарий',
  };
}

String _actionButton(_WorkflowAction action) {
  return switch (action) {
    _WorkflowAction.approve => 'Согласовать',
    _WorkflowAction.reject => 'Отклонить',
    _WorkflowAction.requestChanges => 'Отправить',
    _WorkflowAction.comment => 'Добавить',
  };
}

String _inputLabel(_WorkflowAction action) {
  return switch (action) {
    _WorkflowAction.approve => 'Комментарий',
    _WorkflowAction.reject => 'Причина',
    _WorkflowAction.requestChanges => 'Что нужно изменить',
    _WorkflowAction.comment => 'Комментарий',
  };
}

IconData _actionIcon(_WorkflowAction action) {
  return switch (action) {
    _WorkflowAction.approve => Icons.check_rounded,
    _WorkflowAction.reject => Icons.close_rounded,
    _WorkflowAction.requestChanges => Icons.edit_note_rounded,
    _WorkflowAction.comment => Icons.chat_bubble_outline_rounded,
  };
}

bool _requiresText(_WorkflowAction action) {
  return switch (action) {
    _WorkflowAction.approve => false,
    _WorkflowAction.reject ||
    _WorkflowAction.requestChanges ||
    _WorkflowAction.comment => true,
  };
}

String _requiredTextMessage(_WorkflowAction action) {
  return switch (action) {
    _WorkflowAction.reject => 'Укажите причину отклонения',
    _WorkflowAction.requestChanges => 'Укажите, что нужно изменить',
    _WorkflowAction.comment => 'Введите комментарий',
    _WorkflowAction.approve => 'Введите комментарий',
  };
}

enum _WorkflowAction { approve, reject, requestChanges, comment }

class _WorkflowFilterOption {
  const _WorkflowFilterOption(this.value, this.label);

  final String? value;
  final String label;
}

const _workflowStatusFilters = [
  _WorkflowFilterOption(null, 'Все'),
  _WorkflowFilterOption('pending', 'Ожидают'),
  _WorkflowFilterOption('in_review', 'Доработка'),
  _WorkflowFilterOption('confirmed', 'Согласовано'),
  _WorkflowFilterOption('rejected', 'Отклонено'),
];
