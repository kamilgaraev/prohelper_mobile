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

final GlobalKey<NavigatorState> mostNavigatorKey = GlobalKey<NavigatorState>();

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

class _MostAppState extends ConsumerState<MostApp> {
  late final MobilePushService _pushService;
  StreamSubscription<PushMessage>? _foregroundPushSubscription;
  StreamSubscription<PushMessage>? _openedPushSubscription;
  PushMessage? _pendingOpenedMessage;
  bool _pushNavigationScheduled = false;
  final Set<String> _handledPushMessages = <String>{};

  @override
  void initState() {
    super.initState();
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
    if (_pushNavigationScheduled) return;
    _pushNavigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pushNavigationScheduled = false;
      final message = _pendingOpenedMessage;
      final context = mostNavigatorKey.currentContext;
      if (message == null || context == null) return;
      _pendingOpenedMessage = null;
      final target = PushMessageTarget.fromData(message.data);
      final destination =
          target.notificationId?.isNotEmpty == true
              ? NotificationDetailScreen(notificationId: target.notificationId!)
              : const NotificationsScreen();
      unawaited(
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => destination)),
      );
      final notifier = ref.read(notificationsProvider.notifier);
      unawaited(notifier.load(refresh: true));
      unawaited(notifier.refreshUnreadCount());
    });
  }

  @override
  void dispose() {
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
