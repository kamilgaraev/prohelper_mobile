import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/widgets/app_empty_state.dart';
import '../../projects/domain/projects_provider.dart';

import 'field_catalog_screen.dart';
import 'workforce_calendar_screen.dart';
import 'workforce_project_attendance_screen.dart';

class WorkforceRosterScreen extends ConsumerWidget {
  const WorkforceRosterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ref.watch(
      projectsProvider.select((value) => value.selectedProject?.serverId),
    );
    if (projectId == null) {
      return const Scaffold(
        body: AppEmptyState(
          icon: Icons.domain_disabled_outlined,
          title: 'Выберите объект',
          description: 'Состав сотрудников доступен по выбранному объекту.',
        ),
      );
    }

    return FieldCatalogScreen(
      key: ValueKey(projectId),
      title: 'Персонал и явка',
      catalog: 'workforce-personnel',
      apiPrefix: '/field-admin/personnel',
      icon: Icons.badge_outlined,
      projectScoped: true,
      appBarAction: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Явка на объекте',
            icon: const Icon(Icons.how_to_reg_outlined),
            onPressed:
                () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const WorkforceProjectAttendanceScreen(),
                  ),
                ),
          ),
          IconButton(
            tooltip: 'Календарь состава',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed:
                () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const WorkforceCalendarScreen(),
                  ),
                ),
          ),
        ],
      ),
      entities: const [
        FieldCatalogOption('employees', 'Сотрудники'),
        FieldCatalogOption('absences', 'Отсутствия', hasDetail: false),
        FieldCatalogOption(
          'orders',
          'Наряды',
          hasDetail: false,
          supportsSearch: false,
        ),
      ],
    );
  }
}
