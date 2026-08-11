import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../auth/domain/auth_provider.dart';
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
    final roles = ref.watch(authProvider).user?.roles ?? const <String>[];
    if (roles.contains('machine_operator')) {
      return const OperatorShiftScreen();
    }
    if (roles.contains('storekeeper')) {
      return const AssetScanScreen();
    }
    if (roles.contains('mechanic')) {
      return const MaintenanceQueueScreen();
    }
    return const ForemanMachineryScreen();
  }
}
