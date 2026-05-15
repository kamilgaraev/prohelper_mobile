import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../../core/widgets/pro_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/safety_model.dart';
import '../domain/safety_provider.dart';

class SafetyScreen extends ConsumerStatefulWidget {
  const SafetyScreen({super.key});

  @override
  ConsumerState<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends ConsumerState<SafetyScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedProject = ref.read(projectsProvider).selectedProject;
      final notifier = ref.read(safetyProvider.notifier);
      notifier.syncProject(selectedProject?.serverId);
      notifier.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(safetyProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;

    if (selectedProject?.serverId != state.projectFilter && !state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(safetyProvider.notifier);
        notifier.syncProject(selectedProject?.serverId);
        notifier.load();
      });
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Охрана труда'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed: () => ref.read(safetyProvider.notifier).load(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton:
            selectedProject == null
                ? null
                : FloatingActionButton.extended(
                  onPressed: () => _showCreateSheet(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Запись'),
                ),
        body:
            state.isLoading &&
                    state.activePermits.isEmpty &&
                    state.incidents.isEmpty &&
                    state.violations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.error != null &&
                    state.activePermits.isEmpty &&
                    state.incidents.isEmpty &&
                    state.violations.isEmpty
                ? AppStateView(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Не удалось загрузить охрану труда',
                  description: state.error,
                  action: OutlinedButton(
                    onPressed: () => ref.read(safetyProvider.notifier).load(),
                    child: const Text('Повторить'),
                  ),
                )
                : RefreshIndicator(
                  onRefresh: () => ref.read(safetyProvider.notifier).load(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      _SummaryStrip(state: state),
                      const SizedBox(height: 12),
                      _PermitsSection(permits: state.activePermits),
                      const SizedBox(height: 12),
                      _IncidentsSection(incidents: state.incidents),
                      const SizedBox(height: 12),
                      _ViolationsSection(
                        violations: state.violations,
                        onResolve:
                            (violation) =>
                                _showResolveSheet(context, violation),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Future<void> _showCreateSheet(BuildContext context) async {
    final selectedProject = ref.read(projectsProvider).selectedProject;
    if (selectedProject == null) {
      return;
    }

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    var mode = 'incident';
    var severity = 'major';
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
                        'Новая запись охраны труда',
                        style: AppTypography.h2(context),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'incident',
                            label: Text('Происшествие'),
                            icon: Icon(Icons.report_problem_outlined),
                          ),
                          ButtonSegment(
                            value: 'violation',
                            label: Text('Нарушение'),
                            icon: Icon(Icons.gpp_bad_outlined),
                          ),
                        ],
                        selected: {mode},
                        onSelectionChanged:
                            (value) => setSheetState(() => mode = value.first),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Название',
                        ),
                      ),
                      TextField(
                        controller: locationController,
                        decoration: const InputDecoration(labelText: 'Локация'),
                      ),
                      DropdownButtonFormField<String>(
                        value: severity,
                        decoration: const InputDecoration(labelText: 'Тяжесть'),
                        items: const [
                          DropdownMenuItem(
                            value: 'minor',
                            child: Text('Низкая'),
                          ),
                          DropdownMenuItem(
                            value: 'major',
                            child: Text('Серьезная'),
                          ),
                          DropdownMenuItem(
                            value: 'high',
                            child: Text('Высокая'),
                          ),
                          DropdownMenuItem(
                            value: 'critical',
                            child: Text('Критичная'),
                          ),
                        ],
                        onChanged:
                            (value) => setSheetState(
                              () => severity = value ?? 'major',
                            ),
                      ),
                      TextField(
                        controller: descriptionController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Описание',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed:
                            submitting
                                ? null
                                : () async {
                                  final title = titleController.text.trim();
                                  if (title.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Укажите название'),
                                      ),
                                    );
                                    return;
                                  }

                                  setSheetState(() => submitting = true);
                                  try {
                                    final data = {
                                      'project_id': selectedProject.serverId,
                                      'title': title,
                                      'severity': severity,
                                      if (locationController.text
                                          .trim()
                                          .isNotEmpty)
                                        'location_name':
                                            locationController.text.trim(),
                                      if (descriptionController.text
                                          .trim()
                                          .isNotEmpty)
                                        'description':
                                            descriptionController.text.trim(),
                                    };

                                    if (mode == 'incident') {
                                      await ref
                                          .read(safetyProvider.notifier)
                                          .createIncident({
                                            ...data,
                                            'incident_type': 'unsafe_condition',
                                            'occurred_at':
                                                DateTime.now()
                                                    .toIso8601String(),
                                          });
                                    } else {
                                      await ref
                                          .read(safetyProvider.notifier)
                                          .createViolation(data);
                                    }

                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setSheetState(() => submitting = false);
                                    }
                                  }
                                },
                        child: Text(submitting ? 'Сохранение...' : 'Сохранить'),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Future<void> _showResolveSheet(
    BuildContext context,
    SafetyViolationModel violation,
  ) async {
    final commentController = TextEditingController();
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
                        'Устранить нарушение',
                        style: AppTypography.h2(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        violation.title,
                        style: AppTypography.bodyMedium(context),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: commentController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Что сделано',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed:
                            submitting
                                ? null
                                : () async {
                                  final comment = commentController.text.trim();
                                  if (comment.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Укажите результат устранения',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  setSheetState(() => submitting = true);
                                  try {
                                    await ref
                                        .read(safetyProvider.notifier)
                                        .resolveViolation(
                                          violation.id,
                                          comment,
                                        );
                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setSheetState(() => submitting = false);
                                    }
                                  }
                                },
                        child: Text(submitting ? 'Сохранение...' : 'Сохранить'),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.state});

  final SafetyState state;

  @override
  Widget build(BuildContext context) {
    final openIncidents =
        state.incidents.where((incident) => incident.status != 'closed').length;
    final openViolations =
        state.violations
            .where((violation) => violation.status == 'open')
            .length;

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Допуски',
            value: state.activePermits.length.toString(),
            icon: Icons.assignment_turned_in_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'Происшествия',
            value: openIncidents.toString(),
            icon: Icons.report_problem_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'Нарушения',
            value: openViolations.toString(),
            icon: Icons.gpp_bad_outlined,
          ),
        ),
      ],
    );
  }
}

class _PermitsSection extends StatelessWidget {
  const _PermitsSection({required this.permits});

  final List<SafetyWorkPermitModel> permits;

  @override
  Widget build(BuildContext context) {
    if (permits.isEmpty) {
      return const _EmptySection(
        title: 'Активные наряды-допуски',
        icon: Icons.assignment_turned_in_outlined,
        message: 'Активных нарядов-допусков нет',
      );
    }

    return _Section(
      title: 'Активные наряды-допуски',
      children: permits.map((permit) => _PermitCard(permit: permit)).toList(),
    );
  }
}

class _IncidentsSection extends StatelessWidget {
  const _IncidentsSection({required this.incidents});

  final List<SafetyIncidentModel> incidents;

  @override
  Widget build(BuildContext context) {
    if (incidents.isEmpty) {
      return const _EmptySection(
        title: 'Происшествия',
        icon: Icons.report_problem_outlined,
        message: 'Происшествий пока нет',
      );
    }

    return _Section(
      title: 'Происшествия',
      children:
          incidents
              .map((incident) => _IncidentCard(incident: incident))
              .toList(),
    );
  }
}

class _ViolationsSection extends StatelessWidget {
  const _ViolationsSection({required this.violations, required this.onResolve});

  final List<SafetyViolationModel> violations;
  final ValueChanged<SafetyViolationModel> onResolve;

  @override
  Widget build(BuildContext context) {
    if (violations.isEmpty) {
      return const _EmptySection(
        title: 'Нарушения',
        icon: Icons.gpp_bad_outlined,
        message: 'Нарушений пока нет',
      );
    }

    return _Section(
      title: 'Нарушения',
      children:
          violations
              .map(
                (violation) =>
                    _ViolationCard(violation: violation, onResolve: onResolve),
              )
              .toList(),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.h2(context)),
        const SizedBox(height: 8),
        ...children.map(
          (child) =>
              Padding(padding: const EdgeInsets.only(bottom: 8), child: child),
        ),
      ],
    );
  }
}

class _PermitCard extends StatelessWidget {
  const _PermitCard({required this.permit});

  final SafetyWorkPermitModel permit;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: permit.title,
            label: permit.statusLabel,
            icon: Icons.assignment_turned_in_outlined,
          ),
          const SizedBox(height: 8),
          Text(permit.permitNumber, style: AppTypography.caption(context)),
          if (permit.locationName != null)
            Text(
              permit.locationName!,
              style: AppTypography.bodyMedium(context),
            ),
          Text(
            'Действует до: ${_formatDate(permit.validUntil)}',
            style: AppTypography.bodyMedium(context),
          ),
        ],
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident});

  final SafetyIncidentModel incident;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: incident.title,
            label: incident.statusLabel,
            icon: Icons.report_problem_outlined,
          ),
          const SizedBox(height: 8),
          Text(incident.incidentNumber, style: AppTypography.caption(context)),
          Text(
            'Дата: ${_formatDate(incident.occurredAt)}',
            style: AppTypography.bodyMedium(context),
          ),
          if (incident.description != null)
            Text(
              incident.description!,
              style: AppTypography.bodyMedium(context),
            ),
        ],
      ),
    );
  }
}

class _ViolationCard extends StatelessWidget {
  const _ViolationCard({required this.violation, required this.onResolve});

  final SafetyViolationModel violation;
  final ValueChanged<SafetyViolationModel> onResolve;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: violation.title,
            label: violation.statusLabel,
            icon: Icons.gpp_bad_outlined,
          ),
          const SizedBox(height: 8),
          Text(
            violation.violationNumber,
            style: AppTypography.caption(context),
          ),
          if (violation.dueDate != null)
            Text(
              'Срок: ${_formatDate(violation.dueDate!)}',
              style: AppTypography.bodyMedium(context),
            ),
          if (violation.correctiveAction != null)
            Text(
              violation.correctiveAction!,
              style: AppTypography.bodyMedium(context),
            ),
          if (violation.availableActions.contains('resolve')) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => onResolve(violation),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Устранить'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.title,
    required this.label,
    required this.icon,
  });

  final String title;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 8),
        Chip(label: Text(label), visualDensity: VisualDensity.compact),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.h2(context)),
          Text(label, style: AppTypography.caption(context)),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.h2(context)),
        const SizedBox(height: 8),
        AppStateView(icon: icon, title: message),
      ],
    );
  }
}

String _formatDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }

  return '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
}
