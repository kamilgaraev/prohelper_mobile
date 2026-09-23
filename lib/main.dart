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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EncryptedLocalFileCache().clearTemporaryPlaintext();

  runApp(const ProviderScope(child: MostApp()));
}

class MostApp extends ConsumerStatefulWidget {
  const MostApp({super.key});

  @override
  ConsumerState<MostApp> createState() => _MostAppState();
}

class _MostAppState extends ConsumerState<MostApp> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(authProvider.notifier).checkAuth());
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
