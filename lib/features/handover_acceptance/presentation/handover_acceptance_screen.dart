import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../../core/widgets/pro_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/handover_acceptance_model.dart';
import '../domain/handover_acceptance_provider.dart';

class HandoverAcceptanceScreen extends ConsumerStatefulWidget {
  const HandoverAcceptanceScreen({super.key});

  @override
  ConsumerState<HandoverAcceptanceScreen> createState() =>
      _HandoverAcceptanceScreenState();
}

class _HandoverAcceptanceScreenState
    extends ConsumerState<HandoverAcceptanceScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedProject = ref.read(projectsProvider).selectedProject;
      final notifier = ref.read(handoverAcceptanceProvider.notifier);
      notifier.syncProject(selectedProject?.serverId);
      notifier.loadScopes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(handoverAcceptanceProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;

    if (selectedProject?.serverId != state.projectFilter && !state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(handoverAcceptanceProvider.notifier);
        notifier.syncProject(selectedProject?.serverId);
        notifier.loadScopes();
      });
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Приемка зон'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed: () =>
                  ref.read(handoverAcceptanceProvider.notifier).loadScopes(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: state.isLoading && state.scopes.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.error != null && state.scopes.isEmpty
                ? AppStateView(
                    icon: Icons.error_outline_rounded,
                    title: 'Не удалось загрузить приемку',
                    description: state.error,
                    action: OutlinedButton(
                      onPressed: () => ref
                          .read(handoverAcceptanceProvider.notifier)
                          .loadScopes(),
                      child: const Text('Повторить'),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => ref
                        .read(handoverAcceptanceProvider.notifier)
                        .loadScopes(),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: [
                        _SummaryStrip(scopes: state.scopes),
                        const SizedBox(height: 12),
                        if (state.scopes.isEmpty)
                          const AppStateView(
                            icon: Icons.assignment_turned_in_outlined,
                            title: 'Зон приемки нет',
                            description:
                                'Когда зона будет готова к осмотру, она появится в этом списке.',
                          )
                        else
                          ...state.scopes.map(
                            (scope) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ScopeCard(
                                scope: scope,
                                onCreateFinding: () =>
                                    _showFindingSheet(context, scope),
                                onResolveFinding: () =>
                                    _resolveFirstFinding(context, scope),
                                onReadyForReinspection: () => ref
                                    .read(handoverAcceptanceProvider.notifier)
                                    .readyForReinspection(scope.id),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Future<void> _showFindingSheet(
    BuildContext context,
    AcceptanceScopeModel scope,
  ) async {
    final session = scope.sessions.isEmpty ? null : scope.sessions.first;
    if (session == null) {
      return;
    }

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    var createQualityDefect = true;
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
              Text('Новое замечание', style: AppTypography.h2(context)),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Замечание'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Описание'),
                maxLines: 3,
              ),
              SwitchListTile(
                value: createQualityDefect,
                onChanged: (value) =>
                    setSheetState(() => createQualityDefect = value),
                title: const Text('Создать дефект качества'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          if (title.isEmpty) {
                            return;
                          }
                          setSheetState(() => submitting = true);
                          await ref
                              .read(handoverAcceptanceProvider.notifier)
                              .createFinding(session.id, {
                            'title': title,
                            if (descriptionController.text.trim().isNotEmpty)
                              'description':
                                  descriptionController.text.trim(),
                            'severity': 'major',
                            'create_quality_defect': createQualityDefect,
                          });
                          if (context.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                  child: const Text('Добавить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resolveFirstFinding(
    BuildContext context,
    AcceptanceScopeModel scope,
  ) async {
    AcceptanceFindingModel? finding;
    for (final item in scope.findings) {
      if (item.isOpen) {
        finding = item;
        break;
      }
    }

    if (finding == null) {
      return;
    }

    await ref.read(handoverAcceptanceProvider.notifier).resolveFinding(
          finding.id,
          resolutionComment: 'Устранено с объекта',
        );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.scopes});

  final List<AcceptanceScopeModel> scopes;

  @override
  Widget build(BuildContext context) {
    final openFindings = scopes.fold<int>(
      0,
      (total, scope) => total + scope.openFindings,
    );
    final accepted = scopes
        .where((scope) => scope.status == 'accepted' || scope.status == 'handed_over')
        .length;

    return Row(
      children: [
        Expanded(child: _SummaryTile(label: 'Зоны', value: scopes.length)),
        const SizedBox(width: 8),
        Expanded(child: _SummaryTile(label: 'Замечания', value: openFindings)),
        const SizedBox(width: 8),
        Expanded(child: _SummaryTile(label: 'Принято', value: accepted)),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption(context)),
          const SizedBox(height: 4),
          Text(value.toString(), style: AppTypography.h2(context)),
        ],
      ),
    );
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard({
    required this.scope,
    required this.onCreateFinding,
    required this.onResolveFinding,
    required this.onReadyForReinspection,
  });

  final AcceptanceScopeModel scope;
  final VoidCallback onCreateFinding;
  final VoidCallback onResolveFinding;
  final VoidCallback onReadyForReinspection;

  @override
  Widget build(BuildContext context) {
    final package = scope.handoverPackage;

    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  scope.title,
                  style: AppTypography.bodyLarge(context),
                ),
              ),
              _StatusChip(status: scope.status),
            ],
          ),
          if (scope.locationLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(scope.locationLabel, style: AppTypography.bodySmall(context)),
          ],
          const SizedBox(height: 12),
          Text(
            'Открытые замечания: ${scope.openFindings}',
            style: AppTypography.bodyMedium(context),
          ),
          if (package != null)
            Text(
              'Документы: ${package.approvedRequiredDocuments}/${package.requiredDocuments}',
              style: AppTypography.bodyMedium(context),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onCreateFinding,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Замечание'),
              ),
              OutlinedButton.icon(
                onPressed: scope.openFindings > 0 ? onResolveFinding : null,
                icon: const Icon(Icons.task_alt_rounded),
                label: const Text('Устранено'),
              ),
              FilledButton.icon(
                onPressed: scope.openFindings == 0
                    ? onReadyForReinspection
                    : null,
                icon: const Icon(Icons.fact_check_rounded),
                label: const Text('На проверку'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'accepted' || 'handed_over' => AppColors.success,
      'findings_open' || 'reopened' => AppColors.warning,
      _ => AppColors.primary,
    };

    return Chip(
      label: Text(_statusLabel(status)),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'planned' => 'Запланирована',
    'in_progress' => 'Осмотр',
    'findings_open' => 'Замечания',
    'ready_for_reinspection' => 'Проверка',
    'accepted' => 'Принята',
    'handed_over' => 'Передана',
    'reopened' => 'Повторно',
    'rejected' => 'Отклонена',
    _ => status,
  };
}
