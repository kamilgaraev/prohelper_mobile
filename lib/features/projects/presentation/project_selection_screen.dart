import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../auth/domain/auth_provider.dart';
import '../domain/projects_provider.dart';
import 'widgets/project_card.dart';

class ProjectSelectionScreen extends ConsumerStatefulWidget {
  const ProjectSelectionScreen({super.key});

  @override
  ConsumerState<ProjectSelectionScreen> createState() => _ProjectSelectionScreenState();
}

class _ProjectSelectionScreenState extends ConsumerState<ProjectSelectionScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch projects on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(projectsProvider.notifier).loadProjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(projectsProvider);
    final user = ref.watch(authProvider).user; // Should be authenticated to be here

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Привет, ${user?.name ?? "User"}', 
                        style: AppTypography.h2.copyWith(color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Выберите объект для работы', 
                        style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () {
                      ref.read(authProvider.notifier).logout();
                    },
                    icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              if (state.isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (state.error != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(
                          'Ошибка загрузки проектов', 
                          style: AppTypography.h2.copyWith(color: theme.colorScheme.onSurface),
                        ),
                        const SizedBox(height: 8),
                         // Limit error text length or make it scrollable/expandable if too long
                        Text(
                          state.error!.length > 100 ? '${state.error!.substring(0, 100)}...' : state.error!, 
                          style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton(
                          onPressed: () => ref.read(projectsProvider.notifier).loadProjects(),
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (state.projects.isEmpty)
                 Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_off_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          'Нет доступных проектов', 
                          style: AppTypography.h2.copyWith(color: theme.colorScheme.onSurface),
                        ),
                         const SizedBox(height: 8),
                        Text(
                          'Обратитесь к администратору', 
                          style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: state.projects.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final project = state.projects[index];
                      return ProjectCard(
                        project: project,
                        onTap: () {
                          ref.read(projectsProvider.notifier).selectProject(project);
                          // Navigation is handled by router logic watching selectedProject
                        },
                        isSelected: state.selectedProject?.id == project.id,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
