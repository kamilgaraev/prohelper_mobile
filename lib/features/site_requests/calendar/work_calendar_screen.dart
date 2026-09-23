import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/providers/module_provider.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../../core/widgets/pro_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../../schedule/data/schedule_model.dart';
import '../../schedule/presentation/schedule_details_screen.dart';
import '../../site_requests/data/site_request_model.dart';
import '../../site_requests/presentation/screens/site_request_detail_screen.dart';
import 'work_calendar_provider.dart';

class WorkCalendarScreen extends ConsumerStatefulWidget {
  const WorkCalendarScreen({super.key});

  @override
  ConsumerState<WorkCalendarScreen> createState() => _WorkCalendarScreenState();
}

class _WorkCalendarScreenState extends ConsumerState<WorkCalendarScreen> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectsProvider).selectedProject;
    final permissions = ref.watch(permissionServiceProvider);
    final canLoadRequests =
        permissions.canAccessModule(AppModule.siteRequests) &&
        permissions.hasPermission('site_requests.calendar.view');
    final canLoadSchedule = permissions.canProcessAction('view_schedule');
    final query =
        project == null
            ? null
            : WorkCalendarQuery(
              projectId: project.serverId,
              date: _date,
              loadRequests: canLoadRequests,
              loadSchedule: canLoadSchedule,
            );

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Календарь работ'),
        ),
        body:
            project == null
                ? const AppEmptyState(
                  icon: Icons.apartment_rounded,
                  title: 'Выберите проект',
                  description:
                      'Календарь показывает записи выбранного проекта.',
                )
                : !canLoadRequests && !canLoadSchedule
                ? const AppEmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Календарь недоступен',
                  description: 'Для просмотра календаря нет нужных прав.',
                )
                : _buildCalendar(context, query!, project.name),
      ),
    );
  }

  Widget _buildCalendar(
    BuildContext context,
    WorkCalendarQuery query,
    String projectName,
  ) {
    final dayState = ref.watch(workCalendarDayProvider(query));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(workCalendarDayProvider(query)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ProCard(
            child: Row(
              children: [
                const Icon(Icons.apartment_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Выбранный проект',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        projectName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DateSelector(
            date: _date,
            onPrevious: () => _moveDate(-1),
            onNext: () => _moveDate(1),
            onPick: () => _pickDate(context),
          ),
          const SizedBox(height: 12),
          dayState.when(
            loading:
                () =>
                    const AppLoadingState(message: 'Загружаем заявки и график'),
            error:
                (error, _) => AppErrorState(
                  title: 'Не удалось загрузить календарь',
                  description: UserMessage.fromError(error),
                  onRetry: () => ref.invalidate(workCalendarDayProvider(query)),
                ),
            data:
                (day) => _DayEvents(
                  day: day,
                  onOpenRequest: (request) => _openRequest(context, request),
                  onOpenSchedule:
                      (schedule) => _openSchedule(context, schedule),
                ),
          ),
        ],
      ),
    );
  }

  void _moveDate(int days) {
    setState(() => _date = _date.add(Duration(days: days)));
  }

  Future<void> _pickDate(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
      setState(() => _date = DateUtils.dateOnly(selected));
    }
  }

  void _openRequest(BuildContext context, SiteRequestModel request) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SiteRequestDetailScreen(id: request.serverId),
      ),
    );
  }

  void _openSchedule(BuildContext context, ScheduleItemModel schedule) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScheduleDetailsScreen(scheduleId: schedule.id),
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.date,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ProCard(
      child: Row(
        children: [
          IconButton(
            tooltip: 'Предыдущий день',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                _dateLabel(date),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Следующий день',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _DayEvents extends StatelessWidget {
  const _DayEvents({
    required this.day,
    required this.onOpenRequest,
    required this.onOpenSchedule,
  });

  final WorkCalendarDay day;
  final ValueChanged<SiteRequestModel> onOpenRequest;
  final ValueChanged<ScheduleItemModel> onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    if (day.requests.isEmpty && day.schedules.isEmpty) {
      return const AppEmptyState(
        icon: Icons.event_available_outlined,
        title: 'На эту дату записей нет',
        description: 'Выберите другой день или обновите календарь.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (day.requests.isNotEmpty) ...[
          Text(
            'Заявки · ${day.requests.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...day.requests.map(
            (request) => _CalendarEventCard(
              icon: Icons.assignment_outlined,
              title: request.title,
              details: [
                if (request.requestTypeLabel?.isNotEmpty == true)
                  request.requestTypeLabel!,
                if (request.statusLabel?.isNotEmpty == true)
                  request.statusLabel!,
                if (request.assignedUserName?.isNotEmpty == true)
                  request.assignedUserName!,
              ],
              onTap: () => onOpenRequest(request),
            ),
          ),
        ],
        if (day.schedules.isNotEmpty) ...[
          if (day.requests.isNotEmpty) const SizedBox(height: 16),
          Text(
            'График работ · ${day.schedules.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...day.schedules.map(
            (schedule) => _CalendarEventCard(
              icon: Icons.account_tree_outlined,
              title: schedule.name,
              details: [
                schedule.statusLabel,
                '${schedule.overallProgressPercent.toStringAsFixed(0)}% выполнено',
              ],
              onTap: () => onOpenSchedule(schedule),
            ),
          ),
        ],
      ],
    );
  }
}

class _CalendarEventCard extends StatelessWidget {
  const _CalendarEventCard({
    required this.icon,
    required this.title,
    required this.details,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final List<String> details;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ProCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(title),
          subtitle: details.isEmpty ? null : Text(details.join(' · ')),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}

String _dateLabel(DateTime date) {
  final days = const [
    'понедельник',
    'вторник',
    'среда',
    'четверг',
    'пятница',
    'суббота',
    'воскресенье',
  ];
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '${days[date.weekday - 1]}, $day.$month.${date.year}';
}
