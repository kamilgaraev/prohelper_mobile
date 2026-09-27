import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/providers/module_provider.dart';
import '../../../core/widgets/app_permission_state.dart';
import '../../projects/domain/projects_provider.dart';
import '../domain/machinery_operations_provider.dart';
import 'foreman/foreman_machinery_screen.dart';
import 'mechanic/maintenance_queue_screen.dart';
import 'operator/operator_shift_screen.dart';

class MachineryOperationsScreen extends ConsumerStatefulWidget {
  const MachineryOperationsScreen({super.key});

  @override
  ConsumerState<MachineryOperationsScreen> createState() =>
      _MachineryOperationsScreenState();
}

class _MachineryOperationsScreenState
    extends ConsumerState<MachineryOperationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final projectId = ref.read(projectsProvider).selectedProject?.serverId;
    final notifier = ref.read(machineryOperationsProvider.notifier);
    notifier.syncProject(projectId);
    notifier.load();
  }

  @override
  Widget build(BuildContext context) {
    final modules =
        ref
            .watch(supportedMobileModulesProvider)
            .where((item) => item.slug == 'machinery-operations')
            .toList();
    final module = modules.isEmpty ? null : modules.first;
    final permissions =
        module?.permissions.map((value) => value.toLowerCase()).toSet() ??
        const <String>{};
    final destinations =
        machineryOperationsDestinationsFor(
          permissions,
        ).map(_buildDestination).toList();
    if (destinations.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Техника на объекте')),
        body: const AppPermissionState(),
      );
    }
    if (destinations.length == 1) return destinations.single.builder();
    return Scaffold(
      appBar: AppBar(title: const Text('Техника на объекте')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Доступные действия',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          for (final destination in destinations)
            Card(
              child: ListTile(
                title: Text(destination.title),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => destination.builder(),
                      ),
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

enum MachineryOperationsDestination {
  fleet,
  fleetAndReview,
  shift,
  maintenance,
  shiftReview,
}

@visibleForTesting
List<MachineryOperationsDestination> machineryOperationsDestinationsFor(
  Iterable<String> permissions,
) {
  final grants =
      permissions.map((permission) => permission.toLowerCase()).toSet();
  final canView =
      grants.contains('*') ||
      grants.contains('view') ||
      grants.contains('machinery-operations.view') ||
      grants.contains('machinery-operations.*');
  final canReview = grants.contains('machinery-operations.shifts.approve');

  return [
    if (canView && canReview)
      MachineryOperationsDestination.fleetAndReview
    else if (canView)
      MachineryOperationsDestination.fleet
    else if (canReview)
      MachineryOperationsDestination.shiftReview,
    if (grants.contains('machinery-operations.shifts.create'))
      MachineryOperationsDestination.shift,
    if (grants.contains('machinery-operations.downtime.manage'))
      MachineryOperationsDestination.maintenance,
  ];
}

_MachineryDestination _buildDestination(
  MachineryOperationsDestination destination,
) => switch (destination) {
  MachineryOperationsDestination.fleet => _MachineryDestination(
    'Парк техники',
    () => const ForemanMachineryScreen(),
  ),
  MachineryOperationsDestination.fleetAndReview => _MachineryDestination(
    'Парк техники и рапорты',
    () => const ForemanMachineryScreen(),
  ),
  MachineryOperationsDestination.shift => _MachineryDestination(
    'Сменный рапорт',
    () => const OperatorShiftScreen(),
  ),
  MachineryOperationsDestination.maintenance => _MachineryDestination(
    'ТО и дефекты',
    () => const MaintenanceQueueScreen(),
  ),
  MachineryOperationsDestination.shiftReview => _MachineryDestination(
    'Проверка рапортов',
    () => const ForemanMachineryScreen(),
  ),
};

class _MachineryDestination {
  const _MachineryDestination(this.title, this.builder);
  final String title;
  final Widget Function() builder;
}
