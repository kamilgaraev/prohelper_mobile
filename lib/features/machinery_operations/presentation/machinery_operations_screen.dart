import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/providers/module_provider.dart';
import '../../../core/widgets/app_permission_state.dart';
import '../../projects/domain/projects_provider.dart';
import '../domain/machinery_operations_provider.dart';
import 'foreman/foreman_machinery_screen.dart';
import 'mechanic/maintenance_queue_screen.dart';
import 'operator/operator_shift_screen.dart';
import 'storekeeper/asset_scan_screen.dart';

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
    final destinations = <_MachineryDestination>[
      if (_matches(permissions, const [
        'shift.create',
        'shift.create-own',
        'create_shift_report',
        'record_shift',
      ]))
        _MachineryDestination(
          'Сменный рапорт',
          () => const OperatorShiftScreen(),
        ),
      if (_matches(permissions, const [
        'asset.scan',
        'scan_asset',
        'warehouse.scan',
        'scan',
      ]))
        _MachineryDestination(
          'Сканирование техники',
          () => const AssetScanScreen(),
        ),
      if (_matches(permissions, const [
        'maintenance.view',
        'maintenance.manage',
        'machinery.maintenance',
        'maintenance',
      ]))
        _MachineryDestination(
          'ТО и дефекты',
          () => const MaintenanceQueueScreen(),
        ),
      if (_matches(permissions, const [
        'shift.review',
        'shift.approve',
        'review_shift',
        'machinery.review',
      ]))
        _MachineryDestination(
          'Проверка рапортов',
          () => const ForemanMachineryScreen(),
        ),
    ];
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

bool _matches(Set<String> permissions, List<String> candidates) =>
    permissions.any((permission) => candidates.any(permission.contains));

class _MachineryDestination {
  const _MachineryDestination(this.title, this.builder);
  final String title;
  final Widget Function() builder;
}
