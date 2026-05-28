import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/features/ai_assistant/presentation/ai_assistant_home_screen.dart';
import 'package:prohelpers_mobile/features/brigades/presentation/brigades_screen.dart';
import 'package:prohelpers_mobile/features/budget_estimates/presentation/budget_estimates_screen.dart';
import 'package:prohelpers_mobile/features/catalog_management/presentation/catalog_management_screen.dart';
import 'package:prohelpers_mobile/features/change_management/presentation/change_management_screen.dart';
import 'package:prohelpers_mobile/features/construction_journal/presentation/construction_journal_screen.dart';
import 'package:prohelpers_mobile/features/contract_management/presentation/contract_management_screen.dart';
import 'package:prohelpers_mobile/features/executive_documentation/presentation/executive_documentation_screen.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/presentation/handover_acceptance_screen.dart';
import 'package:prohelpers_mobile/features/machinery_operations/presentation/machinery_operations_screen.dart';
import 'package:prohelpers_mobile/features/production_labor/presentation/production_labor_screen.dart';
import 'package:prohelpers_mobile/features/procurement/presentation/procurement_screen.dart';
import 'package:prohelpers_mobile/features/project_management/presentation/project_management_screen.dart';
import 'package:prohelpers_mobile/features/quality_control/presentation/quality_control_screen.dart';
import 'package:prohelpers_mobile/features/safety/presentation/safety_screen.dart';
import 'package:prohelpers_mobile/features/schedule/presentation/schedule_screen.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_scope.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_requests_screen.dart';
import 'package:prohelpers_mobile/features/time_tracking/presentation/time_tracking_screen.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/warehouse_screen.dart';
import 'package:prohelpers_mobile/features/video_monitoring/presentation/video_monitoring_screen.dart';
import 'package:prohelpers_mobile/features/workflow_management/presentation/workflow_management_screen.dart';
import 'package:prohelpers_mobile/features/workforce/presentation/workforce_attendance_screen.dart';

import 'mobile_destination.dart';

class MobileNavigationRegistry {
  const MobileNavigationRegistry._();

  static final List<MobileModuleDestination> destinations =
      <MobileModuleDestination>[
        MobileModuleDestination(
          route: 'site_requests',
          slug: 'site_requests',
          title: 'Заявки объекта',
          shortTitle: 'Заявки',
          icon: Icons.add_task_rounded,
          group: MobileModuleGroup.fieldWork,
          isPrimaryAction: true,
          appModule: AppModule.siteRequests,
          actionId: 'create_site_request',
          basePriority: 180,
          recommendedReason: 'Быстро создать заявку',
          preferredContexts: <UserContext>{UserContext.field},
          builder: (_) => const SiteRequestsScreen(),
          aliases: <String>['site-requests'],
        ),
        MobileModuleDestination(
          route: 'site_request_approvals',
          slug: 'site_request_approvals',
          title: 'Согласование заявок',
          shortTitle: 'Согласования',
          icon: Icons.fact_check_rounded,
          group: MobileModuleGroup.approvalsAndDocs,
          isPrimaryAction: true,
          appModule: AppModule.siteRequests,
          actionId: 'approve_request',
          basePriority: 220,
          recommendedReason: 'Есть решения на согласование',
          preferredContexts: <UserContext>{UserContext.office},
          builder:
              (_) =>
                  const SiteRequestsScreen(scope: SiteRequestsScope.approvals),
        ),
        MobileModuleDestination(
          route: 'warehouse',
          slug: 'warehouse',
          title: 'Склад',
          shortTitle: 'Склад',
          icon: Icons.warehouse_outlined,
          group: MobileModuleGroup.warehouseAndSupply,
          isPrimaryAction: true,
          appModule: AppModule.basicWarehouse,
          actionId: 'receive_material',
          basePriority: 170,
          recommendedReason: 'Приемка и складские операции',
          preferredContexts: <UserContext>{UserContext.field},
          builder: (_) => const WarehouseScreen(),
          aliases: <String>['basic-warehouse'],
        ),
        MobileModuleDestination(
          route: 'schedule',
          slug: 'schedule',
          title: 'График работ',
          shortTitle: 'График',
          icon: Icons.timeline_rounded,
          group: MobileModuleGroup.fieldWork,
          appModule: AppModule.scheduleManagement,
          actionId: 'view_schedule',
          basePriority: 150,
          recommendedReason: 'Проверить сроки и дневные планы',
          builder: (_) => const ScheduleScreen(),
          aliases: <String>['schedule-management'],
        ),
        MobileModuleDestination(
          route: 'quality_control',
          slug: 'quality_control',
          title: 'Контроль качества',
          shortTitle: 'Качество',
          icon: Icons.verified_outlined,
          group: MobileModuleGroup.fieldWork,
          isPrimaryAction: true,
          appModule: AppModule.qualityControl,
          actionId: 'quality_control',
          basePriority: 145,
          recommendedReason: 'Зафиксировать или проверить замечание',
          preferredContexts: <UserContext>{UserContext.field},
          builder: (_) => const QualityControlScreen(),
          aliases: <String>['quality-control'],
        ),
        MobileModuleDestination(
          route: 'safety_management',
          slug: 'safety_management',
          title: 'Охрана труда',
          shortTitle: 'Безопасность',
          icon: Icons.health_and_safety_rounded,
          group: MobileModuleGroup.fieldWork,
          appModule: AppModule.safetyManagement,
          actionId: 'view_safety',
          basePriority: 135,
          recommendedReason: 'Проверить риски и наряды',
          builder: (_) => const SafetyScreen(),
          aliases: <String>['safety', 'safety-management'],
        ),
        MobileModuleDestination(
          route: 'machinery_operations',
          slug: 'machinery_operations',
          title: 'Техника',
          shortTitle: 'Техника',
          icon: Icons.precision_manufacturing_rounded,
          group: MobileModuleGroup.fieldWork,
          appModule: AppModule.machineryOperations,
          actionId: 'record_machinery_shift',
          basePriority: 125,
          recommendedReason: 'Сменные рапорты и простои',
          preferredContexts: <UserContext>{UserContext.field},
          builder: (_) => const MachineryOperationsScreen(),
          aliases: <String>['machinery-operations'],
        ),
        MobileModuleDestination(
          route: 'production_labor',
          slug: 'production_labor',
          title: 'Выработка',
          shortTitle: 'Выработка',
          icon: Icons.assignment_turned_in_rounded,
          group: MobileModuleGroup.fieldWork,
          appModule: AppModule.productionLabor,
          actionId: 'record_labor_output',
          basePriority: 128,
          recommendedReason: 'Наряды и выработка',
          preferredContexts: <UserContext>{UserContext.field},
          builder: (_) => const ProductionLaborScreen(),
          aliases: <String>['production-labor'],
        ),
        MobileModuleDestination(
          route: 'workforce_management',
          slug: 'workforce_management',
          title: 'Явка сотрудников',
          shortTitle: 'Явка',
          icon: Icons.badge_rounded,
          group: MobileModuleGroup.fieldWork,
          isPrimaryAction: true,
          appModule: AppModule.workforceManagement,
          actionId: 'confirm_workforce_attendance',
          basePriority: 160,
          recommendedReason: 'Отметить или подтвердить явку',
          preferredContexts: <UserContext>{UserContext.field},
          builder: (_) => const WorkforceAttendanceScreen(),
          aliases: <String>['workforce', 'workforce-management'],
        ),
        MobileModuleDestination(
          route: 'time_tracking',
          slug: 'time_tracking',
          title: 'Учет времени',
          shortTitle: 'Время',
          icon: Icons.timer_outlined,
          group: MobileModuleGroup.fieldWork,
          appModule: AppModule.timeTracking,
          actionId: 'track_time',
          basePriority: 130,
          recommendedReason: 'Запустить таймер или добавить запись',
          builder: (_) => const TimeTrackingScreen(),
          aliases: <String>['time-tracking'],
        ),
        MobileModuleDestination(
          route: 'procurement',
          slug: 'procurement',
          title: 'Снабжение',
          shortTitle: 'Снабжение',
          icon: Icons.inventory_2_outlined,
          group: MobileModuleGroup.warehouseAndSupply,
          appModule: AppModule.procurement,
          actionId: 'view_procurement',
          basePriority: 118,
          recommendedReason: 'Поставки и закупки',
          builder: (_) => const ProcurementScreen(),
        ),
        MobileModuleDestination(
          route: 'budget_estimates',
          slug: 'budget_estimates',
          title: 'Сметы',
          shortTitle: 'Сметы',
          icon: Icons.calculate_outlined,
          group: MobileModuleGroup.approvalsAndDocs,
          appModule: AppModule.budgetEstimates,
          actionId: 'view_budget',
          basePriority: 120,
          recommendedReason: 'Проверить сметы и изменения',
          builder: (_) => const BudgetEstimatesScreen(),
          aliases: <String>['budget-estimates'],
        ),
        MobileModuleDestination(
          route: 'handover_acceptance',
          slug: 'handover_acceptance',
          title: 'Сдача-приемка',
          shortTitle: 'Приемка',
          icon: Icons.handshake_rounded,
          group: MobileModuleGroup.approvalsAndDocs,
          appModule: AppModule.handoverAcceptance,
          actionId: 'view_handover',
          basePriority: 115,
          recommendedReason: 'Проверить зоны приемки',
          builder: (_) => const HandoverAcceptanceScreen(),
          aliases: <String>['handover-acceptance'],
        ),
        MobileModuleDestination(
          route: 'construction_journal',
          slug: 'construction_journal',
          title: 'Журнал работ',
          shortTitle: 'Журнал',
          icon: Icons.menu_book_rounded,
          group: MobileModuleGroup.approvalsAndDocs,
          appModule: AppModule.constructionJournal,
          actionId: 'view_construction_journal',
          basePriority: 112,
          recommendedReason: 'Записи и дневные отчеты',
          builder: (_) => const ConstructionJournalScreen(),
          aliases: <String>['construction-journal'],
        ),
        MobileModuleDestination(
          route: 'workflow_management',
          slug: 'workflow_management',
          title: 'Рабочие процессы',
          shortTitle: 'Процессы',
          icon: Icons.hub_outlined,
          group: MobileModuleGroup.approvalsAndDocs,
          appModule: AppModule.workflowManagement,
          actionId: 'view_workflow',
          basePriority: 140,
          recommendedReason: 'Проверить согласования',
          preferredContexts: <UserContext>{UserContext.office},
          builder: (_) => const WorkflowManagementScreen(),
          aliases: <String>['workflow-management'],
        ),
        MobileModuleDestination(
          route: 'ai_assistant',
          slug: 'ai_assistant',
          title: 'AI-ассистент',
          shortTitle: 'Ассистент',
          icon: Icons.smart_toy_outlined,
          group: MobileModuleGroup.management,
          appModule: AppModule.aiAssistant,
          basePriority: 110,
          builder: (_) => const AiAssistantHomeScreen(),
          aliases: <String>['ai-assistant'],
          requiresProject: false,
        ),
        MobileModuleDestination(
          route: 'project_overview',
          slug: 'project_overview',
          title: 'Проект',
          shortTitle: 'Проект',
          icon: Icons.domain_rounded,
          group: MobileModuleGroup.management,
          appModule: AppModule.projectManagement,
          basePriority: 100,
          builder: (_) => const ProjectManagementScreen(),
          aliases: <String>[
            'project-overview',
            'project_selection',
            'project-management',
            'project_management',
          ],
        ),
        MobileModuleDestination(
          route: 'contract_management',
          slug: 'contract_management',
          title: 'Договоры',
          shortTitle: 'Договоры',
          icon: Icons.assignment_outlined,
          group: MobileModuleGroup.management,
          appModule: AppModule.contractManagement,
          basePriority: 90,
          builder: (_) => const ContractManagementScreen(),
          aliases: <String>['contract-management'],
        ),
        MobileModuleDestination(
          route: 'change_management',
          slug: 'change_management',
          title: 'Изменения',
          shortTitle: 'Изменения',
          icon: Icons.change_circle_outlined,
          group: MobileModuleGroup.management,
          appModule: AppModule.changeManagement,
          basePriority: 92,
          builder: (_) => const ChangeManagementScreen(),
          aliases: <String>['change-management'],
        ),
        MobileModuleDestination(
          route: 'executive_documentation',
          slug: 'executive_documentation',
          title: 'Исполнительная документация',
          shortTitle: 'Документы',
          icon: Icons.description_outlined,
          group: MobileModuleGroup.approvalsAndDocs,
          appModule: AppModule.executiveDocumentation,
          basePriority: 105,
          builder: (_) => const ExecutiveDocumentationScreen(),
          aliases: <String>['executive-documentation'],
        ),
        MobileModuleDestination(
          route: 'catalog_management',
          slug: 'catalog_management',
          title: 'Справочники',
          shortTitle: 'Справочники',
          icon: Icons.category_outlined,
          group: MobileModuleGroup.management,
          appModule: AppModule.catalogManagement,
          basePriority: 70,
          builder: (_) => const CatalogManagementScreen(),
          aliases: <String>['catalog-management'],
          requiresProject: false,
        ),
        MobileModuleDestination(
          route: 'brigades',
          slug: 'brigades',
          title: 'Бригады',
          shortTitle: 'Бригады',
          icon: Icons.groups_2_outlined,
          group: MobileModuleGroup.management,
          appModule: AppModule.brigades,
          basePriority: 86,
          builder: (_) => const BrigadesScreen(),
        ),
        MobileModuleDestination(
          route: 'video_monitoring',
          slug: 'video_monitoring',
          title: 'Видеонаблюдение',
          shortTitle: 'Видео',
          icon: Icons.videocam_outlined,
          group: MobileModuleGroup.management,
          appModule: AppModule.videoMonitoring,
          basePriority: 72,
          builder: (_) => const VideoMonitoringScreen(),
          aliases: <String>['video-monitoring'],
        ),
      ];

  static MobileModuleDestination? destinationForRoute(String? route) {
    if (route == null || route.trim().isEmpty) {
      return null;
    }

    final normalized = route.trim();
    for (final destination in destinations) {
      if (destination.matches(normalized)) {
        return destination;
      }
    }

    return null;
  }

  static Widget? screenForRoute(String? route, BuildContext context) {
    final destination = destinationForRoute(route);
    return destination?.builder(context);
  }

  static List<MobileModuleDestination> byGroup(MobileModuleGroup group) {
    return destinations
        .where((destination) => destination.group == group)
        .toList(growable: false);
  }
}
