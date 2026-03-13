import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'core/theme/pro_theme.dart';
import 'features/auth/domain/auth_provider.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/projects/domain/projects_provider.dart';
import 'features/projects/presentation/project_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: ProHelperApp(),
    ),
  );
}

class ProHelperApp extends ConsumerWidget {
  const ProHelperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final projectsState = ref.watch(projectsProvider);
    final Widget home;

    if (authState is AuthAuthenticated) {
      home = projectsState.selectedProject != null
          ? const DashboardScreen()
          : const ProjectSelectionScreen();
    } else if (authState is AuthInitial) {
      home = const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else {
      home = const LoginScreen();
    }

    return MaterialApp(
      title: 'ProHelper',
      debugShowCheckedModeBanner: false,
      theme: ProHelperTheme.lightTheme,
      darkTheme: ProHelperTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: home,
    );
  }
}
