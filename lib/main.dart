import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'core/theme/pro_theme.dart';
import 'core/storage/isar_service.dart';
import 'features/auth/domain/auth_provider.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/projects/domain/projects_provider.dart';
import 'features/projects/presentation/project_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Isar
  // We need a Container for ProviderScope, but Isar needs to be initialized before used
  // For simplicity here, just ensuring binding. Real init happens in Provider.
  
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
    // Watch projects state to determine navigation
    final projectsState = ref.watch(projectsProvider);

    return MaterialApp(
      title: 'ProHelper',
      debugShowCheckedModeBanner: false,
      theme: ProHelperTheme.lightTheme,
      darkTheme: ProHelperTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: switch (authState) {
        AuthAuthenticated() => projectsState.selectedProject != null 
            ? const DashboardScreen() 
            : const ProjectSelectionScreen(),
        AuthUnauthenticated() || AuthError() => const LoginScreen(),
        _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
      },
    );
  }
}
