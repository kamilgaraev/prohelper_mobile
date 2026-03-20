import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/industrial_card.dart';
import '../data/construction_journal_repository.dart';
import '../domain/construction_journal_provider.dart';
import 'journal_entry_form_screen.dart';

class JournalEntryDetailScreen extends ConsumerWidget {
  const JournalEntryDetailScreen({
    super.key,
    required this.journalId,
    required this.entryId,
  });

  final int journalId;
  final int entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(constructionJournalEntryDetailProvider(entryId));
    final notifier = ref.read(constructionJournalEntryDetailProvider(entryId).notifier);

    if (state.isLoading && state.entry == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error != null && state.entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Запись журнала')),
        body: AppStateView(
          icon: Icons.error_outline_rounded,
          title: 'Не удалось загрузить запись',
          description: state.error,
          action: OutlinedButton(
            onPressed: notifier.load,
            child: const Text('Повторить'),
          ),
        ),
      );
    }

    if (state.entry == null) {
      return const Scaffold(
        body: AppStateView(
          icon: Icons.event_note_outlined,
          title: 'Запись не найдена',
        ),
      );
    }

    final entry = state.entry!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Запись №${entry.entryNumber}'),
        actions: [
          IconButton(onPressed: notifier.load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: notifier.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            IndustrialCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Запись №${entry.entryNumber}', style: AppTypography.h2(context)),
                            const SizedBox(height: 4),
                            Text(_formatDate(entry.entryDate), style: AppTypography.caption(context)),
                          ],
                        ),
                      ),
                      _StatusBadge(status: entry.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(entry.workDescription, style: AppTypography.bodyMedium(context)),
                  if ((entry.problemsDescription ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Section(title: 'Проблемы', value: entry.problemsDescription!),
                  ],
                  if ((entry.safetyNotes ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Section(title: 'Безопасность', value: entry.safetyNotes!),
                  ],
                  if ((entry.visitorsNotes ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Section(title: 'Замечания посетителей', value: entry.visitorsNotes!),
                  ],
                  if ((entry.qualityNotes ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Section(title: 'Качество', value: entry.qualityNotes!),
                  ],
                  if ((entry.rejectionReason ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Причина отклонения',
                      value: entry.rejectionReason!,
                      color: AppColors.error,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (entry.availableActions.contains('update'))
                  OutlinedButton.icon(
                    onPressed: () async {
                      final updated = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => JournalEntryFormScreen(
                            journalId: journalId,
                            initialEntry: entry,
                          ),
                        ),
                      );

                      if (updated == true) {
                        await notifier.load();
                      }
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Редактировать'),
                  ),
                if (entry.availableActions.contains('submit'))
                  ElevatedButton.icon(
                    onPressed: () async {
                      await ref.read(constructionJournalRepositoryProvider).submitEntry(entryId);
                      await notifier.load();
                    },
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Отправить'),
                  ),
                if (entry.availableActions.contains('approve'))
                  ElevatedButton.icon(
                    onPressed: () async {
                      await ref.read(constructionJournalRepositoryProvider).approveEntry(entryId);
                      await notifier.load();
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Утвердить'),
                  ),
                if (entry.availableActions.contains('reject'))
                  OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(context, ref, notifier, entryId),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Отклонить'),
                  ),
                if (entry.availableActions.contains('delete'))
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(constructionJournalRepositoryProvider).deleteEntry(entryId);
                      if (context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Удалить'),
                  ),
                if (entry.availableActions.contains('export_daily_report'))
                  OutlinedButton.icon(
                    onPressed: () async {
                      final url = await ref.read(constructionJournalRepositoryProvider).exportDailyReport(entryId);
                      if (url.isNotEmpty) {
                        await Clipboard.setData(ClipboardData(text: url));
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ссылка на дневной отчет скопирована в буфер.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Дневной отчет'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.value,
    this.color,
  });

  final String title;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.caption(context).copyWith(
            color: resolvedColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: AppTypography.bodyMedium(context).copyWith(color: resolvedColor)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => AppColors.success,
      'submitted' => AppColors.warning,
      'rejected' => AppColors.error,
      _ => Theme.of(context).colorScheme.primary,
    };
    final label = switch (status) {
      'approved' => 'Утверждена',
      'submitted' => 'На проверке',
      'rejected' => 'Отклонена',
      _ => 'Черновик',
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

Future<void> _showRejectDialog(
  BuildContext context,
  WidgetRef ref,
  ConstructionJournalEntryDetailNotifier notifier,
  int entryId,
) async {
  final controller = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Отклонить запись'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Причина отклонения',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(constructionJournalRepositoryProvider).rejectEntry(
                    entryId,
                    controller.text.trim(),
                  );
              if (context.mounted) {
                Navigator.of(context).pop();
              }
              await notifier.load();
            },
            child: const Text('Отклонить'),
          ),
        ],
      );
    },
  );

  controller.dispose();
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
