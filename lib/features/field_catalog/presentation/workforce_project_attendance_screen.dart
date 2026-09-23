import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/widgets/app_empty_state.dart';
import '../../projects/domain/projects_provider.dart';
import 'field_catalog_screen.dart';

class WorkforceProjectAttendanceScreen extends ConsumerStatefulWidget {
  const WorkforceProjectAttendanceScreen({super.key});

  @override
  ConsumerState<WorkforceProjectAttendanceScreen> createState() =>
      _WorkforceProjectAttendanceScreenState();
}

class _WorkforceProjectAttendanceScreenState
    extends ConsumerState<WorkforceProjectAttendanceScreen> {
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final projectId = ref.watch(
      projectsProvider.select((value) => value.selectedProject?.serverId),
    );
    if (projectId == null) {
      return const Scaffold(
        body: AppEmptyState(
          icon: Icons.domain_disabled_outlined,
          title: 'Выберите объект',
          description: 'Явка сотрудников доступна по выбранному объекту.',
        ),
      );
    }

    final date = _dateKey(_date);
    return FieldCatalogScreen(
      key: ValueKey('$projectId:$date'),
      title: 'Явка за $date',
      catalog: 'workforce-attendance',
      apiPrefix: '/field-admin/personnel',
      icon: Icons.how_to_reg_outlined,
      projectScoped: true,
      allowSearch: false,
      extraQueryParameters: {'work_date': date},
      entities: const [
        FieldCatalogOption(
          'attendance',
          'Сотрудники объекта',
          hasDetail: false,
          supportsSearch: false,
        ),
      ],
      appBarAction: IconButton(
        tooltip: 'Выбрать дату явки',
        icon: const Icon(Icons.event_outlined),
        onPressed: _pickDate,
      ),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (selected != null && mounted) {
      setState(() => _date = selected);
    }
  }
}

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
