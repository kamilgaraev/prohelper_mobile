import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/industrial_card.dart';
import '../data/construction_journal_repository.dart';
import '../domain/construction_journal_provider.dart';
import 'journal_entry_detail_screen.dart';
import 'journal_entry_form_screen.dart';
import 'journal_form_screen.dart';

class ConstructionJournalDetailScreen extends ConsumerWidget {
  const ConstructionJournalDetailScreen({
    super.key,
    required this.journalId,
  });

  final int journalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(constructionJournalDetailProvider(journalId));
    final notifier = ref.read(constructionJournalDetailProvider(journalId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Карточка журнала'),
        actions: [
          IconButton(onPressed: notifier.load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: notifier.load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (state.isLoading && state.journal == null)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.error != null && state.journal == null)
              SliverFillRemaining(
                child: AppStateView(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить журнал',
                  description: state.error,
                  action: OutlinedButton(
                    onPressed: notifier.load,
                    child: const Text('Повторить'),
                  ),
                ),
              )
            else if (state.journal == null)
              const SliverFillRemaining(
                child: AppStateView(
                  icon: Icons.menu_book_outlined,
                  title: 'Журнал не найден',
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: IndustrialCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(state.journal!.name, style: AppTypography.h2(context)),
                        const SizedBox(height: 6),
                        Text(
                          'Журнал №${state.journal!.journalNumber.isEmpty ? '-' : state.journal!.journalNumber}',
                          style: AppTypography.bodyMedium(context).copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Badge(label: 'Всего ${state.journal!.totalEntries}', color: Theme.of(context).colorScheme.primary),
                            _Badge(label: 'Утверждено ${state.journal!.approvedEntries}', color: AppColors.success),
                            _Badge(label: 'На проверке ${state.journal!.submittedEntries}', color: AppColors.warning),
                            _Badge(label: 'Отклонено ${state.journal!.rejectedEntries}', color: AppColors.error),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (state.availableActions.contains('create_entry'))
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final created = await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) => JournalEntryFormScreen(journalId: journalId),
                                    ),
                                  );

                                  if (created == true) {
                                    await notifier.load();
                                  }
                                },
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Новая запись'),
                              ),
                            if (state.availableActions.contains('update'))
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final updated = await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) => JournalFormScreen(initialJournal: state.journal),
                                    ),
                                  );

                                  if (updated == true) {
                                    await notifier.load();
                                  }
                                },
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Редактировать'),
                              ),
                            if (state.availableActions.contains('export'))
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final url = await ref.read(constructionJournalRepositoryProvider).exportJournal(journalId);
                                  await _showExportDialog(context, url);
                                },
                                icon: const Icon(Icons.download_rounded),
                                label: const Text('Экспорт КС-6'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'Всего записей',
                          value: state.entriesSummary.totalEntries.toString(),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          title: 'Утверждено',
                          value: state.entriesSummary.approvedEntries.toString(),
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text('Записи журнала', style: AppTypography.h2(context)),
                ),
              ),
              if (state.entries.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppStateView(
                    icon: Icons.event_note_outlined,
                    title: 'Записей пока нет',
                    description: 'Добавьте первую запись по выполненным работам.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final entry = state.entries[index];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: IndustrialCard(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => JournalEntryDetailScreen(
                                  journalId: journalId,
                                  entryId: entry.id,
                                ),
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
                                          Text('Запись №${entry.entryNumber}', style: AppTypography.bodyLarge(context)),
                                          const SizedBox(height: 4),
                                          Text(_formatDate(entry.entryDate), style: AppTypography.caption(context)),
                                        ],
                                      ),
                                    ),
                                    _Badge(
                                      label: _entryStatusLabel(entry.status),
                                      color: _entryStatusColor(entry.status),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(entry.workDescription, style: AppTypography.bodyMedium(context)),
                                if ((entry.rejectionReason ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Причина отклонения: ${entry.rejectionReason}',
                                    style: AppTypography.caption(context).copyWith(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: state.entries.length,
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.caption(context)),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.h2(context).copyWith(color: color)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
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

Color _entryStatusColor(String status) {
  return switch (status) {
    'approved' => AppColors.success,
    'submitted' => AppColors.warning,
    'rejected' => AppColors.error,
    _ => AppColors.secondary,
  };
}

String _entryStatusLabel(String status) {
  return switch (status) {
    'approved' => 'Утверждена',
    'submitted' => 'На проверке',
    'rejected' => 'Отклонена',
    _ => 'Черновик',
  };
}

String _formatDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) {
    return value;
  }

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

Future<void> _showExportDialog(BuildContext context, String url) async {
  if (url.isNotEmpty) {
    await Clipboard.setData(ClipboardData(text: url));
  }

  if (!context.mounted) {
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Ссылка на экспорт готова'),
        content: SelectableText(
          url.isEmpty ? 'Ссылка не получена от сервера.' : '$url\n\nСсылка уже скопирована в буфер обмена.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      );
    },
  );
}
