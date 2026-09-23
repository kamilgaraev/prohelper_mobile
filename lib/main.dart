import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'core/localization/most_localizations.dart';
import 'core/storage/encrypted_local_file_cache.dart';
import 'core/widgets/app_loading_state.dart';
import 'core/widgets/mobile_app_shell.dart';
import 'core/theme/pro_theme.dart';
import 'features/auth/domain/auth_provider.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/projects/domain/projects_provider.dart';
import 'features/projects/presentation/project_selection_screen.dart';
import 'features/notifications/data/mobile_push_service.dart';
import 'features/notifications/data/push_message.dart';
import 'features/notifications/data/push_message_target.dart';
import 'features/notifications/domain/notifications_provider.dart';
import 'features/notifications/presentation/notification_detail_screen.dart';
import 'features/notifications/presentation/notifications_screen.dart';
import 'features/site_requests/data/site_requests_repository.dart';
import 'features/site_requests/presentation/screens/site_request_detail_screen.dart';
import 'features/construction_journal/data/construction_journal_repository.dart';
import 'features/construction_journal/presentation/journal_entry_detail_screen.dart';
import 'features/schedule/data/schedule_repository.dart';
import 'features/schedule/presentation/schedule_details_screen.dart';
import 'features/warehouse/data/warehouse_repository.dart';
import 'features/warehouse/presentation/warehouse_tasks_screen.dart';

final GlobalKey<NavigatorState> mostNavigatorKey = GlobalKey<NavigatorState>();

enum _PushContextResult { ready, waiting, unavailable }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EncryptedLocalFileCache().clearTemporaryPlaintext();
  final pushReady = await MobilePushService.initialize();
  runApp(ProviderScope(child: MostApp(pushReady: pushReady)));
}

class MostApp extends ConsumerStatefulWidget {
  const MostApp({super.key, this.pushReady = false});

  final bool pushReady;

  @override
  ConsumerState<MostApp> createState() => _MostAppState();
}

class _MostAppState extends ConsumerState<MostApp> with WidgetsBindingObserver {
  late final MobilePushService _pushService;
  StreamSubscription<PushMessage>? _foregroundPushSubscription;
  StreamSubscription<PushMessage>? _openedPushSubscription;
  PushMessage? _pendingOpenedMessage;
  bool _pushNavigationScheduled = false;
  bool _pushNavigationInProgress = false;
  final Set<String> _handledPushMessages = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(ref.read(authProvider.notifier).checkAuth());
    _pushService = ref.read(mobilePushServiceProvider);
    _foregroundPushSubscription = _pushService.foregroundMessages.listen(
      _onForegroundPush,
    );
    _openedPushSubscription = _pushService.openedMessages.listen(_onOpenedPush);
    ref.listenManual<AuthState>(authProvider, (_, state) {
      unawaited(_pushService.setAuthenticated(state is AuthAuthenticated));
      if (state is AuthAuthenticated) _scheduleOpenPendingPush();
    });
    ref.listenManual<ProjectsState>(projectsProvider, (_, state) {
      if (state.selectedProject != null) _scheduleOpenPendingPush();
    });
    unawaited(_pushService.start(pushReady: widget.pushReady));
  }

  void _onForegroundPush(PushMessage message) {
    if (ref.read(authProvider) is! AuthAuthenticated) return;
    final notifier = ref.read(notificationsProvider.notifier);
    unawaited(notifier.load(refresh: true));
    unawaited(notifier.refreshUnreadCount());
  }

  void _onOpenedPush(PushMessage message) {
    final messageId = message.messageId;
    if (messageId != null && !_handledPushMessages.add(messageId)) return;
    _pendingOpenedMessage = message;
    if (ref.read(authProvider) is AuthAuthenticated) _scheduleOpenPendingPush();
  }

  void _scheduleOpenPendingPush() {
    if (_pushNavigationScheduled || _pushNavigationInProgress) return;
    _pushNavigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pushNavigationScheduled = false;
      final message = _pendingOpenedMessage;
      final context = mostNavigatorKey.currentContext;
      if (message == null || context == null) return;
      _pushNavigationInProgress = true;
      unawaited(
        _openPendingPush(message, context).whenComplete(() {
          _pushNavigationInProgress = false;
        }),
      );
    });
  }

  Future<void> _openPendingPush(
    PushMessage message,
    BuildContext context,
  ) async {
    final pushTarget = PushMessageTarget.fromData(message.data);
    if (ref.read(authProvider) is! AuthAuthenticated) return;
    final contextResult = await _preparePushContext(pushTarget);
    if (contextResult == _PushContextResult.waiting) return;
    final projectsAtStart = ref.read(projectsProvider);
    final authAtStart = ref.read(authProvider);
    if (authAtStart is! AuthAuthenticated) return;
    final sessionIdentity = authAtStart.sessionIdentity;
    final projectId = projectsAtStart.selectedProject?.serverId;

    Widget? destination;
    final target = pushTarget.destination;
    if (target != null) {
      try {
        destination = switch (target.type) {
          PushDestinationType.siteRequest => await _siteRequestDestination(
            target.id,
          ),
          PushDestinationType.journalEntry => await _journalDestination(
            target.id,
          ),
          PushDestinationType.schedule => await _scheduleDestination(target.id),
          PushDestinationType.warehouseTask => await _warehouseDestination(
            target.parentId!,
            target.id,
          ),
        };
      } catch (_) {
        destination = null;
      }
    }

    final currentAuth = ref.read(authProvider);
    final currentProject = ref.read(projectsProvider).selectedProject;
    if (!context.mounted ||
        currentAuth is! AuthAuthenticated ||
        currentAuth.sessionIdentity != sessionIdentity ||
        currentProject?.serverId != projectId) {
      _pendingOpenedMessage = message;
      return;
    }
    destination ??=
        pushTarget.notificationId?.isNotEmpty == true
            ? NotificationDetailScreen(
              notificationId: pushTarget.notificationId!,
            )
            : const NotificationsScreen();
    _pendingOpenedMessage = null;
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => destination!)),
    );
    final notifier = ref.read(notificationsProvider.notifier);
    unawaited(notifier.load(refresh: true));
    unawaited(notifier.refreshUnreadCount());
  }

  Future<_PushContextResult> _preparePushContext(
    PushMessageTarget target,
  ) async {
    var auth = ref.read(authProvider);
    if (auth is! AuthAuthenticated) return _PushContextResult.waiting;

    if (target.organizationId != null &&
        target.organizationId != auth.user.currentOrganizationId) {
      final hasOrganization = auth.user.organizations.any(
        (organization) =>
            int.tryParse(organization['id']?.toString() ?? '') ==
            target.organizationId,
      );
      if (!hasOrganization) return _PushContextResult.unavailable;
      try {
        await ref
            .read(authProvider.notifier)
            .switchOrganization(target.organizationId!);
      } catch (_) {
        return _PushContextResult.waiting;
      }
      final updatedAuth = ref.read(authProvider);
      if (updatedAuth is! AuthAuthenticated ||
          updatedAuth.user.currentOrganizationId != target.organizationId) {
        return _PushContextResult.waiting;
      }
    }

    var projects = ref.read(projectsProvider);
    if (!projects.hasLoaded) {
      await ref.read(projectsProvider.notifier).loadProjects();
      projects = ref.read(projectsProvider);
    }

    final projectId = target.projectId;
    if (projectId == null) {
      return projects.selectedProject == null
          ? _PushContextResult.waiting
          : _PushContextResult.ready;
    }
    final accessibleProjects = projects.projects
        .where((project) => project.serverId == projectId)
        .toList(growable: false);
    if (accessibleProjects.isEmpty) return _PushContextResult.unavailable;
    final accessibleProject = accessibleProjects.first;
    if (projects.selectedProject?.serverId != projectId) {
      ref.read(projectsProvider.notifier).selectProject(accessibleProject);
    }
    return _PushContextResult.ready;
  }

  Future<Widget> _siteRequestDestination(int id) async {
    await ref.read(siteRequestsRepositoryProvider).fetchSiteRequestDetails(id);
    return SiteRequestDetailScreen(id: id);
  }

  Future<Widget> _journalDestination(int entryId) async {
    final entry = await ref
        .read(constructionJournalRepositoryProvider)
        .fetchEntryDetail(entryId);
    return JournalEntryDetailScreen(
      journalId: entry.journalId,
      entryId: entryId,
    );
  }

  Future<Widget> _scheduleDestination(int id) async {
    await ref.read(scheduleRepositoryProvider).fetchScheduleDetails(id);
    return ScheduleDetailsScreen(scheduleId: id);
  }

  Future<Widget> _warehouseDestination(int warehouseId, int taskId) async {
    final repository = ref.read(warehouseRepositoryProvider);
    await repository.fetchTask(warehouseId, taskId);
    final summary = await repository.fetchWarehouseSummary();
    return WarehouseTasksScreen(
      summary: summary,
      initialWarehouseId: warehouseId,
      initialEntityType: 'task',
      initialEntityId: taskId,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_pushService.start(pushReady: widget.pushReady));
      if (ref.read(authProvider) is AuthAuthenticated) {
        unawaited(_pushService.setAuthenticated(true));
      }
      _scheduleOpenPendingPush();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_foregroundPushSubscription?.cancel());
    unawaited(_openedPushSubscription?.cancel());
    unawaited(_pushService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final projectsState = ref.watch(projectsProvider);
    final Widget home;

    if (authState is AuthAuthenticated) {
      home =
          projectsState.selectedProject != null
              ? const MobileAppShell()
              : const ProjectSelectionScreen();
    } else if (authState is AuthInitial) {
      home = const Scaffold(
        body: AppLoadingState(message: 'Проверяем сессию', minHeight: 156),
      );
    } else {
      home = const LoginScreen();
    }

    return MaterialApp(
      navigatorKey: mostNavigatorKey,
      title: 'МОСТ',
      debugShowCheckedModeBanner: false,
      theme: MostTheme.lightTheme,
      darkTheme: MostTheme.darkTheme,
      themeMode: ThemeMode.system,
      locale: MostLocalizations.ru,
      localizationsDelegates: MostLocalizations.delegates,
      supportedLocales: MostLocalizations.supportedLocales,
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: MostTheme.systemUiOverlayStyleFor(
            Theme.of(context).brightness,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: home,
    );
  }
}
