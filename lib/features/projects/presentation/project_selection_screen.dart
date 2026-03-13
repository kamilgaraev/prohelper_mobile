import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/theme/app_colors.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/app_state_view.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/projects/presentation/widgets/project_card.dart';

class ProjectSelectionScreen extends ConsumerWidget {
  const ProjectSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(projectsProvider);
    final user = ref.watch(authProvider).user;

    if (!state.isLoading && state.projects.isEmpty && state.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(projectsProvider.notifier).loadProjects();
      });
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Привет, ${user?.name ?? 'пользователь'}',
                          style: AppTypography.h2(context),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Выберите объект для работы',
                          style: AppTypography.bodyMedium(context).copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => ref.read(authProvider.notifier).logout(),
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Expanded(
                child: switch ((state.isLoading, state.error, state.projects.isEmpty)) {
                  (true, _, _) => const Center(child: CircularProgressIndicator()),
                  (_, final String error, true) => AppStateView(
                      icon: Icons.error_outline_rounded,
                      iconColor: AppColors.error,
                      title: 'Не удалось загрузить объекты',
                      description: error,
                      action: OutlinedButton(
                        onPressed: () =>
                            ref.read(projectsProvider.notifier).loadProjects(),
                        child: const Text('Повторить'),
                      ),
                    ),
                  (_, _, true) => const AppStateView(
                      icon: Icons.folder_off_outlined,
                      title: 'Нет доступных объектов',
                      description:
                          'Попросите администратора выдать вам доступ к проекту.',
                    ),
                  _ => ListView.separated(
                      itemCount: state.projects.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final project = state.projects[index];
                        return ProjectCard(
                          project: project,
                          isSelected:
                              state.selectedProject?.serverId == project.serverId,
                          onTap: () => ref
                              .read(projectsProvider.notifier)
                              .selectProject(project),
                        );
                      },
                    ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
