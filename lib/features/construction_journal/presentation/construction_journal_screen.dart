import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/industrial_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../domain/construction_journal_provider.dart';
import 'construction_journal_detail_screen.dart';
import 'journal_form_screen.dart';

class ConstructionJournalScreen extends ConsumerStatefulWidget {
  const ConstructionJournalScreen({super.key});

  @override
  ConsumerState<ConstructionJournalScreen> createState() => _ConstructionJournalScreenState();
}

class _ConstructionJournalScreenState extends ConsumerState<ConstructionJournalScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final projectId = ref.read(projectsProvider).selectedProject?.serverId;
      ref.read(constructionJournalProvider.notifier).load(projectId: projectId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(constructionJournalProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Журнал работ'),
      ),
      floatingActionButton: state.availableActions.contains('create') && selectedProject != null
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const JournalFormScreen()),
                );

                if (created == true && mounted) {
                  await ref.read(constructionJournalProvider.notifier).load(
                        projectId: selectedProject.serverId,
                      );
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Новый журнал'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(constructionJournalProvider.notifier).load(
              projectId: selectedProject?.serverId,
            ),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (selectedProject == null)
              const SliverFillRemaining(
                child: AppStateView(
                  icon: Icons.menu_book_outlined,
                  title: 'Объект не выбран',
                  description: 'Сначала выберите объект, чтобы открыть журнал работ.',
                ),
              )
            else if (state.isLoading && state.items.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.error != null && state.items.isEmpty)
              SliverFillRemaining(
                child: AppStateView(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить журналы работ',
                  description: state.error,
                  action: OutlinedButton(
                    onPressed: () => ref.read(constructionJournalProvider.notifier).load(
                          projectId: selectedProject.serverId,
                        ),
                    child: const Text('Повторить'),
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _HeaderCard(
                    projectName: state.project?.name ?? selectedProject.name,
                    isRefreshing: state.isLoading,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _SummaryGrid(
                    total: state.summary.totalJournals,
                    active: state.summary.activeJournals,
                    archived: state.summary.archivedJournals,
                    closed: state.summary.closedJournals,
                  ),
                ),
              ),
              if (state.items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppStateView(
                    icon: Icons.menu_book_outlined,
                    title: 'Журналы пока не созданы',
                    description: 'Создайте первый журнал работ для выбранного объекта.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final journal = state.items[index];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: IndustrialCard(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ConstructionJournalDetailScreen(journalId: journal.id),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(journal.name, style: AppTypography.h2(context)),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Журнал №${journal.journalNumber.isEmpty ? '-' : journal.journalNumber}',
                                            style: AppTypography.bodyMedium(context).copyWith(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _StatusBadge(status: journal.status),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _Pill(label: 'Всего ${journal.totalEntries}', color: Theme.of(context).colorScheme.primary),
                                    _Pill(label: 'Утверждено ${journal.approvedEntries}', color: AppColors.success),
                                    _Pill(label: 'На проверке ${journal.submittedEntries}', color: AppColors.warning),
                                    _Pill(label: 'Отклонено ${journal.rejectedEntries}', color: AppColors.error),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Старт: ${_formatDate(journal.startDate)}',
                                  style: AppTypography.bodyMedium(context),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: state.items.length,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.projectName,
    required this.isRefreshing,
  });

  final String projectName;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(projectName, style: AppTypography.bodyMedium(context)),
              const SizedBox(height: 4),
              Text('Реестр журналов работ по объекту', style: AppTypography.bodyLarge(context)),
            ],
          ),
        ),
        if (isRefreshing)
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.total,
    required this.active,
    required this.archived,
    required this.closed,
  });

  final int total;
  final int active;
  final int archived;
  final int closed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Всего',
                value: total.toString(),
                color: Theme.of(context).colorScheme.primary,
                icon: Icons.menu_book_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'Активные',
                value: active.toString(),
                color: AppColors.success,
                icon: Icons.play_circle_outline_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Архив',
                value: archived.toString(),
                color: AppColors.warning,
                icon: Icons.archive_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'Закрытые',
                value: closed.toString(),
                color: AppColors.error,
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(value, style: AppTypography.h2(context)),
          const SizedBox(height: 4),
          Text(title, style: AppTypography.caption(context)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => AppColors.success,
      'archived' => AppColors.warning,
      'closed' => AppColors.error,
      _ => Theme.of(context).colorScheme.primary,
    };

    final label = switch (status) {
      'active' => 'Активный',
      'archived' => 'Архив',
      'closed' => 'Закрыт',
      _ => status,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.caption(context).copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTypography.caption(context).copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatDate(String value) {
  if (value.isEmpty) {
    return '-';
  }

  final date = DateTime.tryParse(value);
  if (date == null) {
    return value;
  }

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}
