import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/providers/module_provider.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/design/pro_design_tokens.dart';
import '../../../core/widgets/pro_section.dart';
import '../../../core/widgets/pro_surface.dart';
import '../../projects/domain/projects_provider.dart';
import '../../quality_control/presentation/quality_defect_detail_screen.dart';
import '../../procurement/presentation/procurement_purchase_request_detail_screen.dart';
import '../../payments/presentation/payments_screen.dart';
import '../../schedule/presentation/schedule_task_detail_screen.dart';
import '../../site_requests/presentation/screens/site_request_detail_screen.dart';
import '../data/my_action.dart';
import '../domain/my_actions_provider.dart';

class MyActionsSection extends ConsumerStatefulWidget {
  const MyActionsSection({super.key});

  @override
  ConsumerState<MyActionsSection> createState() => _MyActionsSectionState();
}

class _MyActionsSectionState extends ConsumerState<MyActionsSection> {
  bool _allProjects = false;

  @override
  Widget build(BuildContext context) {
    final selectedProject = ref.watch(projectsProvider).selectedProject;
    final projectId = _allProjects ? null : selectedProject?.serverId;
    final state = ref.watch(myActionsProvider(projectId));

    return ProSurface(
      tone: ProSurfaceTone.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProSectionHeader(
            title: 'Мои действия',
            subtitle: 'Назначенные записи и ближайшие сроки',
            trailing: IconButton(
              tooltip: 'Обновить мои действия',
              onPressed:
                  () => ref.read(myActionsProvider(projectId).notifier).load(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          Wrap(
            spacing: ProSpacing.xs,
            children: [
              ChoiceChip(
                label: const Text('Объект'),
                selected: !_allProjects,
                onSelected:
                    selectedProject == null
                        ? null
                        : (_) => setState(() => _allProjects = false),
              ),
              ChoiceChip(
                label: const Text('Все доступные'),
                selected: _allProjects || selectedProject == null,
                onSelected: (_) => setState(() => _allProjects = true),
              ),
            ],
          ),
          const SizedBox(height: ProSpacing.sm),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(ProSpacing.sm),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.error != null && state.items.isEmpty)
            TextButton.icon(
              onPressed:
                  () => ref.read(myActionsProvider(projectId).notifier).load(),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(state.error!),
            )
          else if (state.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(ProSpacing.sm),
              child: Text('Назначенных действий пока нет.'),
            )
          else ...[
            for (final action in state.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_iconFor(action.type)),
                title: Text(action.title, maxLines: 2),
                subtitle: Text(_subtitle(action)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _open(context, action),
              ),
            if (state.error != null) Text(state.error!),
            if (state.hasMore)
              TextButton(
                onPressed:
                    state.isLoadingMore
                        ? null
                        : () =>
                            ref
                                .read(myActionsProvider(projectId).notifier)
                                .loadMore(),
                child: Text(
                  state.isLoadingMore ? 'Загружаем…' : 'Показать ещё',
                ),
              ),
          ],
        ],
      ),
    );
  }

  static IconData _iconFor(String type) => switch (type) {
    'site_request' => Icons.assignment_outlined,
    'schedule_task' => Icons.event_note_outlined,
    'quality_defect' => Icons.fact_check_outlined,
    _ => Icons.task_alt_outlined,
  };

  static String _subtitle(MyAction action) {
    final parts = <String>[
      if (action.projectName?.isNotEmpty == true) action.projectName!,
      action.status,
      if (action.dueAt != null)
        'Срок: ${action.dueAt!.day.toString().padLeft(2, '0')}.${action.dueAt!.month.toString().padLeft(2, '0')}.${action.dueAt!.year}',
    ];
    return parts.join(' · ');
  }

  void _open(BuildContext context, MyAction action) {
    if (action.route == 'purchase_request') {
      final permissions = ref.read(permissionServiceProvider);
      if (!permissions.canAccessModule(AppModule.procurement) ||
          !permissions.hasPermission('procurement.purchase_requests.view')) {
        return;
      }
    }
    if (action.route == 'payment_document') {
      final permissions = ref.read(permissionServiceProvider);
      if (!permissions.canAccessModule(AppModule.payments) ||
          !permissions.hasAnyPermission(const [
            'payments.invoice.view',
            'payments.invoice.view_all',
          ])) {
        return;
      }
    }
    final target = myActionTarget(action);
    if (target == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => target));
  }
}

Widget? myActionTarget(MyAction action) => switch (action.route) {
  'site_request' => SiteRequestDetailScreen(id: action.id),
  'schedule_task' => ScheduleTaskDetailScreen(
    taskId: action.id,
    projectId: action.projectId,
    allowedActions: action.allowedActions,
  ),
  'quality_defect' => QualityDefectDetailScreen(defectId: action.id),
  'purchase_request' => ProcurementPurchaseRequestDetailScreen(
    requestId: action.id,
  ),
  'payment_document' => PaymentDocumentDetailScreen(id: action.id),
  _ => null,
};
