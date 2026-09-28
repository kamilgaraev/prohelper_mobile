import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/error/user_message.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/app_empty_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_error_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_error_notice.dart';
import 'package:prohelpers_mobile/core/widgets/app_loading_state.dart';
import 'package:prohelpers_mobile/core/widgets/mesh_background.dart';
import 'package:prohelpers_mobile/core/widgets/pro_search_filter_bar.dart';
import 'package:prohelpers_mobile/core/widgets/pro_status_banner.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/presentation/widgets/knowledge_context_help_button.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_scope.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_request_detail_screen.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_request_form_screen.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/widgets/site_request_card.dart';

enum _RequestFilter { all, attention, pending, review, inWork, urgent, done }

class _FilterOption {
  const _FilterOption(this.filter, this.label);

  final _RequestFilter filter;
  final String label;
}

class SiteRequestsScreen extends ConsumerStatefulWidget {
  const SiteRequestsScreen({super.key, this.scope = SiteRequestsScope.all});

  final SiteRequestsScope scope;

  @override
  ConsumerState<SiteRequestsScreen> createState() => _SiteRequestsScreenState();
}

class _SiteRequestsScreenState extends ConsumerState<SiteRequestsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  _RequestFilter _selectedFilter = _RequestFilter.all;
  String _searchQuery = '';
  Timer? _searchDebounce;
  bool _contextSyncScheduled = false;
  final Set<int> _activeStatusRequestIds = {};

  bool get _isApprovalsMode => widget.scope == SiteRequestsScope.approvals;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_handleSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(siteRequestsProvider.notifier);
      final selectedProject = ref.read(projectsProvider).selectedProject;
      notifier.syncScope(widget.scope);
      notifier.syncProject(selectedProject?.serverId);
      notifier.loadRequests(refresh: true);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final nextValue = _searchController.text.trim();
    if (_searchQuery == nextValue) {
      return;
    }

    setState(() {
      _searchQuery = nextValue;
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        ref
            .read(siteRequestsProvider.notifier)
            .setSearchFilter(nextValue.isEmpty ? null : nextValue);
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(siteRequestsProvider.notifier).loadRequests();
    }
  }

  Future<void> _changeRequestStatus(
    BuildContext context,
    SiteRequestModel request,
    String status,
  ) async {
    if (!_activeStatusRequestIds.add(request.serverId)) return;
    setState(() {});

    try {
      if (status == 'rejected' || status == 'cancelled') {
        await _askForTransitionComment(
          context,
          status,
          onSubmit:
              (notes) => ref
                  .read(siteRequestsProvider.notifier)
                  .changeStatus(request.serverId, status, notes: notes),
        );
        return;
      }

      await ref
          .read(siteRequestsProvider.notifier)
          .changeStatus(request.serverId, status);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      AppErrorNotice.show(context, error);
    } finally {
      _activeStatusRequestIds.remove(request.serverId);
      if (mounted) setState(() {});
    }
  }

  VoidCallback? _buildActionCallback(
    BuildContext context,
    SiteRequestModel request,
    String? status,
  ) {
    if (status == null || _activeStatusRequestIds.contains(request.serverId)) {
      return null;
    }

    return () => _changeRequestStatus(context, request, status);
  }

  Future<void> _askForTransitionComment(
    BuildContext context,
    String status, {
    required Future<void> Function(String notes) onSubmit,
  }) {
    return showDialog<void>(
      context: context,
      builder:
          (_) => _SiteRequestInlineTransitionDialog(
            status: status,
            onSubmit: onSubmit,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(siteRequestsProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;
    final isContextChanging =
        state.projectFilter != selectedProject?.serverId ||
        state.scope != widget.scope;
    final theme = Theme.of(context);
    final filteredRequests =
        state.requests
            .where(
              (request) =>
                  _matchesFilter(request, _selectedFilter, widget.scope) &&
                  _matchesSearch(request, _searchQuery),
            )
            .toList()
          ..sort(_compareRequests);

    final urgentCount = state.requests.where(_isUrgentRequest).length;
    final pendingCount = state.requests.where(_isPendingReview).length;
    final inReviewCount = state.requests.where(_isInReview).length;
    final inWorkCount =
        state.requests.where((request) => _isInWork(request.status)).length;
    final canCreateRequest =
        !_isApprovalsMode &&
        selectedProject != null &&
        !state.permissionDenied &&
        !(state.error != null && state.requests.isEmpty);

    ref.listen<SiteRequestsState>(siteRequestsProvider, (previous, next) {
      final shouldShowError =
          next.error != null &&
          next.error != previous?.error &&
          next.requests.isNotEmpty;
      if (!shouldShowError || !mounted) {
        return;
      }

      AppErrorNotice.show(context, next.error!);
    });

    if (isContextChanging && !_contextSyncScheduled) {
      _contextSyncScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _contextSyncScheduled = false;
        if (!mounted) return;
        final notifier = ref.read(siteRequestsProvider.notifier);
        notifier.syncScope(widget.scope);
        notifier.syncProject(
          ref.read(projectsProvider).selectedProject?.serverId,
        );
        notifier.loadRequests(refresh: true);
      });
    }

    final filterOptions = _filterOptionsFor(widget.scope);

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: selectedProject == null ? kToolbarHeight : 72,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isApprovalsMode ? 'Согласование' : 'Заявки',
                style: AppTypography.h1(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (selectedProject != null)
                Text(
                  selectedProject.name,
                  style: AppTypography.caption(
                    context,
                  ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          centerTitle: false,
          actions: [
            if (canCreateRequest)
              IconButton(
                tooltip: 'Новая заявка',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SiteRequestFormScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded),
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.read(siteRequestsProvider.notifier).syncScope(widget.scope);
            ref
                .read(siteRequestsProvider.notifier)
                .syncProject(selectedProject?.serverId);
            await ref
                .read(siteRequestsProvider.notifier)
                .loadRequests(refresh: true);
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (selectedProject == null)
                const SliverFillRemaining(
                  child: AppEmptyState(
                    icon: Icons.apartment_outlined,
                    title: 'Объект не выбран',
                    description:
                        'Сначала выберите объект, чтобы работать с заявками.',
                  ),
                )
              else if (isContextChanging)
                const SliverFillRemaining(
                  child: AppLoadingState(message: 'Загружаем заявки'),
                )
              else ...[
                if (state.fromCache && state.requests.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    sliver: SliverToBoxAdapter(
                      child: ProStatusBanner(
                        title: 'Сохранённые данные',
                        description: 'Данные с устройства.',
                        tone: ProStatusTone.info,
                      ),
                    ),
                  ),
                if (state.requests.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: _RequestsOperationalBanner(
                        scope: widget.scope,
                        totalCount: state.requests.length,
                        pendingCount: pendingCount,
                        inReviewCount: inReviewCount,
                        urgentCount: urgentCount,
                        inWorkCount: inWorkCount,
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: KnowledgeContextHelpButton(
                        contextKey:
                            _isApprovalsMode
                                ? 'site_requests.approvals'
                                : 'site_requests.index',
                        moduleSlug: 'site-requests',
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: _RequestsFiltersCard(
                      controller: _searchController,
                      selectedFilter: _selectedFilter,
                      resultLabel:
                          state.isLoading && state.requests.isEmpty
                              ? null
                              : 'Найдено: ${filteredRequests.length} из ${state.requests.length}',
                      options: filterOptions,
                      searchHint: 'Поиск заявок',
                      onFilterChanged: (filter) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                        ref
                            .read(siteRequestsProvider.notifier)
                            .setUrgentFilter(filter == _RequestFilter.urgent);
                      },
                      onClearSearch:
                          _searchQuery.isEmpty
                              ? null
                              : () {
                                _searchController.clear();
                              },
                    ),
                  ),
                ),
                if (state.error != null && state.requests.isEmpty)
                  SliverFillRemaining(
                    child: AppErrorState(
                      title:
                          state.permissionDenied
                              ? (_isApprovalsMode
                                  ? 'Нет доступа к согласованию заявок'
                                  : 'Нет доступа к заявкам объекта')
                              : _isApprovalsMode
                              ? 'Не удалось загрузить очередь согласования'
                              : 'Не удалось загрузить заявки',
                      description: UserMessage.fromError(state.error!),
                      onRetry:
                          () => ref
                              .read(siteRequestsProvider.notifier)
                              .loadRequests(refresh: true),
                    ),
                  )
                else if (state.isLoading && state.requests.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Загружаем заявки',
                            style: AppTypography.caption(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  )
                else if (state.requests.isEmpty && !state.isLoading)
                  SliverFillRemaining(
                    child: AppEmptyState(
                      icon:
                          _isApprovalsMode
                              ? Icons.fact_check_outlined
                              : Icons.inventory_2_outlined,
                      title:
                          _isApprovalsMode
                              ? 'Нет заявок на согласование'
                              : 'Заявок пока нет',
                      description:
                          _isApprovalsMode
                              ? 'Сейчас на этом объекте нет заявок, которые ждут решения.'
                              : 'Создайте первую заявку для текущего объекта.',
                    ),
                  )
                else if (filteredRequests.isEmpty)
                  const SliverFillRemaining(
                    child: AppEmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'По фильтру ничего не найдено',
                      description:
                          'Снимите часть ограничений или попробуйте другой запрос.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final request = filteredRequests[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SiteRequestCard(
                            request: request,
                            primaryActionLabel: _primaryActionLabel(
                              request,
                              widget.scope,
                            ),
                            onPrimaryAction: _buildActionCallback(
                              context,
                              request,
                              _primaryActionStatus(request, widget.scope),
                            ),
                            secondaryActionLabel: _secondaryActionLabel(
                              request,
                              widget.scope,
                            ),
                            onSecondaryAction: _buildActionCallback(
                              context,
                              request,
                              _secondaryActionStatus(request, widget.scope),
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) => SiteRequestDetailScreen(
                                        id: request.serverId,
                                      ),
                                ),
                              );
                            },
                          ),
                        );
                      }, childCount: filteredRequests.length),
                    ),
                  ),
                if (state.isLoading && state.requests.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: AppLoadingState(
                        message: 'Загружаем заявки',
                        compact: true,
                      ),
                    ),
                  ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesSearch(SiteRequestModel request, String query) {
    if (query.isEmpty) {
      return true;
    }

    final normalizedQuery = query.toLowerCase();
    final haystack =
        [
          request.title,
          request.description ?? '',
          request.notes ?? '',
          request.projectName ?? '',
          request.userName ?? '',
          request.assignedUserName ?? '',
          request.groupTitle ?? '',
          request.materialName ?? '',
          request.requestTypeLabel ?? request.requestType,
          request.statusLabel ?? request.status,
          request.priorityLabel ?? request.priority,
          request.personnelTypeLabel ?? '',
          request.equipmentTypeLabel ?? request.equipmentType ?? '',
        ].join(' ').toLowerCase();

    return haystack.contains(normalizedQuery);
  }
}

class _SiteRequestInlineTransitionDialog extends StatefulWidget {
  const _SiteRequestInlineTransitionDialog({
    required this.status,
    required this.onSubmit,
  });

  final String status;
  final Future<void> Function(String notes) onSubmit;

  @override
  State<_SiteRequestInlineTransitionDialog> createState() =>
      _SiteRequestInlineTransitionDialogState();
}

class _SiteRequestInlineTransitionDialogState
    extends State<_SiteRequestInlineTransitionDialog> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final notes = _controller.text.trim();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onSubmit(notes);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = UserMessage.fromError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRejection = widget.status == 'rejected';

    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        title: Text(
          isRejection ? 'Причина отклонения' : 'Комментарий к отмене',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('site-request-inline-transition-comment'),
              controller: _controller,
              enabled: !_isSubmitting,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Добавьте комментарий',
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Назад'),
          ),
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: Text(_isSubmitting ? 'Сохраняем…' : 'Подтвердить'),
          ),
        ],
      ),
    );
  }
}

List<_FilterOption> _filterOptionsFor(SiteRequestsScope scope) {
  if (scope == SiteRequestsScope.approvals) {
    return const [
      _FilterOption(_RequestFilter.all, 'Все'),
      _FilterOption(_RequestFilter.pending, 'На согласовании'),
      _FilterOption(_RequestFilter.review, 'На рассмотрении'),
      _FilterOption(_RequestFilter.urgent, 'Срочные'),
    ];
  }

  return const [
    _FilterOption(_RequestFilter.all, 'Все'),
    _FilterOption(_RequestFilter.attention, 'Требуют внимания'),
    _FilterOption(_RequestFilter.inWork, 'В работе'),
    _FilterOption(_RequestFilter.urgent, 'Срочные'),
    _FilterOption(_RequestFilter.done, 'Закрытые'),
  ];
}

bool _matchesFilter(
  SiteRequestModel request,
  _RequestFilter filter,
  SiteRequestsScope scope,
) {
  return switch (filter) {
    _RequestFilter.all => true,
    _RequestFilter.attention => _needsAttention(request),
    _RequestFilter.pending => _isPendingReview(request),
    _RequestFilter.review => _isInReview(request),
    _RequestFilter.inWork => _isInWork(request.status),
    _RequestFilter.urgent => _isUrgentRequest(request),
    _RequestFilter.done =>
      scope != SiteRequestsScope.approvals && _isDone(request.status),
  };
}

String? _primaryActionLabel(SiteRequestModel request, SiteRequestsScope scope) {
  final actions = _quickActions(request, scope);
  if (actions.isEmpty) {
    return null;
  }

  return _actionLabel(actions.first);
}

String? _secondaryActionLabel(
  SiteRequestModel request,
  SiteRequestsScope scope,
) {
  final actions = _quickActions(request, scope);
  if (actions.length < 2) {
    return null;
  }

  return _actionLabel(actions[1]);
}

String? _primaryActionStatus(
  SiteRequestModel request,
  SiteRequestsScope scope,
) {
  final actions = _quickActions(request, scope);
  return actions.isEmpty ? null : actions.first.status;
}

String? _secondaryActionStatus(
  SiteRequestModel request,
  SiteRequestsScope scope,
) {
  final actions = _quickActions(request, scope);
  return actions.length < 2 ? null : actions[1].status;
}

List<SiteRequestTransition> _quickActions(
  SiteRequestModel request,
  SiteRequestsScope scope,
) {
  final priorities =
      scope == SiteRequestsScope.approvals
          ? <String, int>{
            'in_review': 100,
            'approved': 90,
            'rejected': 80,
            'in_progress': 70,
            'fulfilled': 60,
            'completed': 50,
            'cancelled': 40,
            'pending': 30,
          }
          : <String, int>{
            'pending': 100,
            'completed': 90,
            'cancelled': 80,
            'in_progress': 70,
            'fulfilled': 60,
          };

  final sorted = [...request.availableTransitions]..sort(
    (left, right) => (priorities[right.status.trim().toLowerCase()] ?? 0)
        .compareTo(priorities[left.status.trim().toLowerCase()] ?? 0),
  );

  return sorted.take(2).toList(growable: false);
}

String _actionLabel(SiteRequestTransition transition) {
  final status = transition.status.trim().toLowerCase();

  return switch (status) {
    'pending' => 'Отправить',
    'in_review' => 'Взять в рассмотрение',
    'approved' => 'Согласовать',
    'rejected' => 'Отклонить',
    'in_progress' => 'Запустить в работу',
    'fulfilled' => 'Отметить исполненной',
    'completed' => 'Подтвердить получение',
    'cancelled' => 'Отменить',
    _ => transition.name ?? 'Выполнить',
  };
}

class _RequestsOperationalBanner extends StatelessWidget {
  const _RequestsOperationalBanner({
    required this.scope,
    required this.totalCount,
    required this.pendingCount,
    required this.inReviewCount,
    required this.urgentCount,
    required this.inWorkCount,
  });

  final SiteRequestsScope scope;
  final int totalCount;
  final int pendingCount;
  final int inReviewCount;
  final int urgentCount;
  final int inWorkCount;

  @override
  Widget build(BuildContext context) {
    final hasAttention =
        pendingCount > 0 || inReviewCount > 0 || urgentCount > 0;

    final title =
        scope == SiteRequestsScope.approvals
            ? (hasAttention
                ? 'Ждут решения'
                : 'Очередь согласования под контролем')
            : (hasAttention ? 'Ждут решения' : 'Заявки объекта');

    final description =
        scope == SiteRequestsScope.approvals
            ? (hasAttention
                ? 'На согласовании: $pendingCount. На рассмотрении: $inReviewCount. Срочных: $urgentCount.'
                : 'Всего заявок в очереди: $totalCount.')
            : (hasAttention
                ? 'На согласовании: $pendingCount. Срочных: $urgentCount. В работе: $inWorkCount.'
                : 'Всего заявок: $totalCount. Активных в работе: $inWorkCount.');

    return ProStatusBanner(
      title: title,
      description: description,
      tone: hasAttention ? ProStatusTone.warning : ProStatusTone.success,
    );
  }
}

class _RequestsFiltersCard extends StatelessWidget {
  const _RequestsFiltersCard({
    required this.controller,
    required this.selectedFilter,
    required this.resultLabel,
    required this.options,
    required this.searchHint,
    required this.onFilterChanged,
    required this.onClearSearch,
  });

  final TextEditingController controller;
  final _RequestFilter selectedFilter;
  final String? resultLabel;
  final List<_FilterOption> options;
  final String searchHint;
  final ValueChanged<_RequestFilter> onFilterChanged;
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    return ProSearchFilterBar<_RequestFilter>(
      controller: controller,
      hintText: searchHint,
      options: options
          .map(
            (option) => ProFilterOption<_RequestFilter>(
              value: option.filter,
              label: option.label,
            ),
          )
          .toList(growable: false),
      selectedValue: selectedFilter,
      onFilterChanged: onFilterChanged,
      onClearSearch: onClearSearch,
      resultLabel: resultLabel,
    );
  }
}

int _compareRequests(SiteRequestModel left, SiteRequestModel right) {
  final urgentCompare = _boolPriority(
    _isUrgentRequest(right),
  ).compareTo(_boolPriority(_isUrgentRequest(left)));
  if (urgentCompare != 0) {
    return urgentCompare;
  }

  final attentionCompare = _boolPriority(
    _needsAttention(right),
  ).compareTo(_boolPriority(_needsAttention(left)));
  if (attentionCompare != 0) {
    return attentionCompare;
  }

  final leftDate = left.createdAt ?? DateTime(1970);
  final rightDate = right.createdAt ?? DateTime(1970);
  final dateCompare = rightDate.compareTo(leftDate);
  if (dateCompare != 0) {
    return dateCompare;
  }

  return left.title.toLowerCase().compareTo(right.title.toLowerCase());
}

bool _needsAttention(SiteRequestModel request) {
  final status = request.status.trim().toLowerCase();
  return status == 'pending' ||
      status == 'in_review' ||
      status == 'approved' ||
      _isUrgentRequest(request);
}

bool _isPendingReview(SiteRequestModel request) {
  return request.status.trim().toLowerCase() == 'pending';
}

bool _isInReview(SiteRequestModel request) {
  return request.status.trim().toLowerCase() == 'in_review';
}

bool _isInWork(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'in_progress';
}

bool _isDone(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'completed' ||
      normalized == 'cancelled' ||
      normalized == 'rejected';
}

bool _isUrgentRequest(SiteRequestModel request) {
  final priority = request.priority.trim().toLowerCase();
  return priority == 'high' || priority == 'urgent';
}

int _boolPriority(bool value) => value ? 1 : 0;
