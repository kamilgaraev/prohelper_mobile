import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/app_state_view.dart';
import 'package:prohelpers_mobile/core/widgets/mesh_background.dart';
import 'package:prohelpers_mobile/core/widgets/pro_card.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_scope.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_request_detail_screen.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_request_form_screen.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/widgets/site_request_card.dart';

enum _RequestFilter {
  all,
  attention,
  pending,
  review,
  inWork,
  urgent,
  done,
}

class _FilterOption {
  const _FilterOption(this.filter, this.label);

  final _RequestFilter filter;
  final String label;
}

class SiteRequestsScreen extends ConsumerStatefulWidget {
  const SiteRequestsScreen({
    super.key,
    this.scope = SiteRequestsScope.own,
  });

  final SiteRequestsScope scope;

  @override
  ConsumerState<SiteRequestsScreen> createState() => _SiteRequestsScreenState();
}

class _SiteRequestsScreenState extends ConsumerState<SiteRequestsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  _RequestFilter _selectedFilter = _RequestFilter.all;
  String _searchQuery = '';

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
    try {
      var notes = '';
      if (status == 'rejected' || status == 'cancelled') {
        notes = await _askForTransitionComment(context, status) ?? '';
        if (!context.mounted) {
          return;
        }
      }

      await ref
          .read(siteRequestsProvider.notifier)
          .changeStatus(request.serverId, status, notes: notes);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  VoidCallback? _buildActionCallback(
    BuildContext context,
    SiteRequestModel request,
    String? status,
  ) {
    if (status == null) {
      return null;
    }

    return () => _changeRequestStatus(context, request, status);
  }

  Future<String?> _askForTransitionComment(BuildContext context, String status) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(status == 'rejected' ? 'Причина отклонения' : 'Комментарий к отмене'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Добавьте комментарий',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Назад'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(siteRequestsProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;
    final theme = Theme.of(context);
    final filteredRequests = state.requests
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

    ref.listen<SiteRequestsState>(siteRequestsProvider, (previous, next) {
      final shouldShowError =
          next.error != null && next.error != previous?.error && next.requests.isNotEmpty;
      if (!shouldShowError || !mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next.error!)),
      );
    });

    if (state.scope != widget.scope && !state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(siteRequestsProvider.notifier).syncScope(widget.scope);
        ref.read(siteRequestsProvider.notifier).loadRequests(refresh: true);
      });
    }

    if (selectedProject?.serverId != state.projectFilter && !state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(siteRequestsProvider.notifier).syncProject(selectedProject?.serverId);
        ref.read(siteRequestsProvider.notifier).loadRequests(refresh: true);
      });
    }

    final filterOptions = _filterOptionsFor(widget.scope);

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isApprovalsMode ? 'Нуждаются в рассмотрении' : 'Заявки с объекта',
                style: AppTypography.h1(context),
              ),
              if (selectedProject != null)
                Text(
                  selectedProject.name,
                  style: AppTypography.caption(context).copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          centerTitle: false,
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.read(siteRequestsProvider.notifier).syncScope(widget.scope);
            ref.read(siteRequestsProvider.notifier).syncProject(selectedProject?.serverId);
            await ref.read(siteRequestsProvider.notifier).loadRequests(refresh: true);
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (selectedProject == null)
                const SliverFillRemaining(
                  child: AppStateView(
                    icon: Icons.apartment_outlined,
                    title: 'Объект не выбран',
                    description:
                        'Сначала выберите объект, чтобы работать с заявками.',
                  ),
                )
              else if (state.error != null && state.requests.isEmpty)
                SliverFillRemaining(
                  child: AppStateView(
                    icon: Icons.error_outline_rounded,
                    title: _isApprovalsMode
                        ? 'Не удалось загрузить очередь согласования'
                        : 'Не удалось загрузить заявки',
                    description: state.error,
                    action: OutlinedButton(
                      onPressed: () => ref
                          .read(siteRequestsProvider.notifier)
                          .loadRequests(refresh: true),
                      child: const Text('Повторить'),
                    ),
                  ),
                )
              else ...[
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: _RequestsFiltersCard(
                      controller: _searchController,
                      selectedFilter: _selectedFilter,
                      resultCount: filteredRequests.length,
                      totalCount: state.requests.length,
                      options: filterOptions,
                      searchHint: _isApprovalsMode
                          ? 'Поиск по заявкам, материалам и исполнителям'
                          : 'Поиск по заявкам, материалам и статусам',
                      onFilterChanged: (filter) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      onClearSearch: _searchQuery.isEmpty
                          ? null
                          : () {
                              _searchController.clear();
                            },
                    ),
                  ),
                ),
                if (state.requests.isEmpty && !state.isLoading)
                  SliverFillRemaining(
                    child: AppStateView(
                      icon: _isApprovalsMode
                          ? Icons.fact_check_outlined
                          : Icons.inventory_2_outlined,
                      title: _isApprovalsMode
                          ? 'Нет заявок на согласование'
                          : 'Заявок пока нет',
                      description: _isApprovalsMode
                          ? 'Сейчас на этом объекте нет заявок, которые ждут решения.'
                          : 'Создайте первую заявку для текущего объекта.',
                    ),
                  )
                else if (filteredRequests.isEmpty)
                  const SliverFillRemaining(
                    child: AppStateView(
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
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final request = filteredRequests[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: SiteRequestCard(
                              request: request,
                              primaryActionLabel: _primaryActionLabel(request, widget.scope),
                              onPrimaryAction: _buildActionCallback(
                                context,
                                request,
                                _primaryActionStatus(request, widget.scope),
                              ),
                              secondaryActionLabel: _secondaryActionLabel(request, widget.scope),
                              onSecondaryAction: _buildActionCallback(
                                context,
                                request,
                                _secondaryActionStatus(request, widget.scope),
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SiteRequestDetailScreen(
                                      id: request.serverId,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        childCount: filteredRequests.length,
                      ),
                    ),
                  ),
                if (state.isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
        floatingActionButton: _isApprovalsMode
            ? null
            : FloatingActionButton(
                onPressed: () {
                  if (selectedProject == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Сначала выберите объект.')),
                    );
                    return;
                  }

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SiteRequestFormScreen(),
                    ),
                  );
                },
                backgroundColor: theme.colorScheme.primary,
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
              ),
      ),
    );
  }

  bool _matchesSearch(SiteRequestModel request, String query) {
    if (query.isEmpty) {
      return true;
    }

    final normalizedQuery = query.toLowerCase();
    final haystack = [
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
    _RequestFilter.done => scope == SiteRequestsScope.own && _isDone(request.status),
  };
}

String? _primaryActionLabel(SiteRequestModel request, SiteRequestsScope scope) {
  final actions = _quickActions(request, scope);
  if (actions.isEmpty) {
    return null;
  }

  return _actionLabel(actions.first);
}

String? _secondaryActionLabel(SiteRequestModel request, SiteRequestsScope scope) {
  final actions = _quickActions(request, scope);
  if (actions.length < 2) {
    return null;
  }

  return _actionLabel(actions[1]);
}

String? _primaryActionStatus(SiteRequestModel request, SiteRequestsScope scope) {
  final actions = _quickActions(request, scope);
  return actions.isEmpty ? null : actions.first;
}

String? _secondaryActionStatus(SiteRequestModel request, SiteRequestsScope scope) {
  final actions = _quickActions(request, scope);
  return actions.length < 2 ? null : actions[1];
}

List<String> _quickActions(SiteRequestModel request, SiteRequestsScope scope) {
  final statuses = request.availableTransitions
      .map((transition) => transition.status.trim().toLowerCase())
      .where((status) => status.isNotEmpty)
      .toList(growable: false);

  if (statuses.isNotEmpty) {
    final priorities = scope == SiteRequestsScope.approvals
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

    final sorted = [...statuses]..sort(
        (left, right) => (priorities[right] ?? 0).compareTo(priorities[left] ?? 0),
      );

    return sorted.take(2).toList(growable: false);
  }

  final status = request.status.trim().toLowerCase();

  if (scope == SiteRequestsScope.approvals) {
    return switch (status) {
      'pending' => const ['in_review'],
      'in_review' => const ['approved', 'rejected'],
      _ => const [],
    };
  }

  return switch (status) {
    'draft' => const ['pending', 'cancelled'],
    'fulfilled' => const ['completed'],
    _ => const [],
  };
}

String _actionLabel(String status) {
  return switch (status) {
    'pending' => 'Отправить',
    'in_review' => 'Взять в рассмотрение',
    'approved' => 'Согласовать',
    'rejected' => 'Отклонить',
    'in_progress' => 'Запустить в работу',
    'fulfilled' => 'Отметить исполненной',
    'completed' => 'Подтвердить получение',
    'cancelled' => 'Отменить',
    _ => status,
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
    final theme = Theme.of(context);
    final hasAttention =
        pendingCount > 0 || inReviewCount > 0 || urgentCount > 0;

    final title = scope == SiteRequestsScope.approvals
        ? (hasAttention
            ? 'Есть заявки, которые ждут решения'
            : 'Очередь согласования под контролем')
        : (hasAttention
            ? 'Есть заявки, требующие реакции'
            : 'Поток заявок под контролем');

    final description = scope == SiteRequestsScope.approvals
        ? (hasAttention
            ? 'На согласовании: $pendingCount. На рассмотрении: $inReviewCount. Срочных: $urgentCount.'
            : 'Всего заявок в очереди: $totalCount.')
        : (hasAttention
            ? 'На согласовании: $pendingCount. Срочных: $urgentCount. В работе: $inWorkCount.'
            : 'Всего заявок: $totalCount. Активных в работе: $inWorkCount.');

    final accentColor = hasAttention
        ? theme.colorScheme.secondary
        : theme.colorScheme.primary;

    return ProCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              hasAttention ? Icons.priority_high_rounded : Icons.assignment_turned_in,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLarge(context).copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
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

class _RequestsFiltersCard extends StatelessWidget {
  const _RequestsFiltersCard({
    required this.controller,
    required this.selectedFilter,
    required this.resultCount,
    required this.totalCount,
    required this.options,
    required this.searchHint,
    required this.onFilterChanged,
    required this.onClearSearch,
  });

  final TextEditingController controller;
  final _RequestFilter selectedFilter;
  final int resultCount;
  final int totalCount;
  final List<_FilterOption> options;
  final String searchHint;
  final ValueChanged<_RequestFilter> onFilterChanged;
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: searchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: onClearSearch == null
                  ? null
                  : IconButton(
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor:
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((option) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: selectedFilter == option.filter,
                    label: Text(option.label),
                    onSelected: (_) => onFilterChanged(option.filter),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Найдено: $resultCount из $totalCount',
            style: AppTypography.caption(context).copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

int _compareRequests(SiteRequestModel left, SiteRequestModel right) {
  final urgentCompare =
      _boolPriority(_isUrgentRequest(right)).compareTo(_boolPriority(_isUrgentRequest(left)));
  if (urgentCompare != 0) {
    return urgentCompare;
  }

  final attentionCompare =
      _boolPriority(_needsAttention(right)).compareTo(_boolPriority(_needsAttention(left)));
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
  return normalized == 'approved' ||
      normalized == 'in_progress' ||
      normalized == 'fulfilled';
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
