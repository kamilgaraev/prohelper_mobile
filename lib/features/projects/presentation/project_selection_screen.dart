import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/app_action_buttons.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/auth/presentation/widgets/logout_confirmation_dialog.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/projects/presentation/widgets/project_card.dart';

class ProjectSelectionScreen extends ConsumerStatefulWidget {
  const ProjectSelectionScreen({super.key});

  @override
  ConsumerState<ProjectSelectionScreen> createState() =>
      _ProjectSelectionScreenState();
}

class _ProjectSelectionScreenState
    extends ConsumerState<ProjectSelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProjectsOnce());
  }

  void _loadProjectsOnce() {
    if (!mounted) {
      return;
    }

    final state = ref.read(projectsProvider);
    if (state.isLoading ||
        state.hasLoaded ||
        state.projects.isNotEmpty ||
        state.error != null) {
      return;
    }

    ref.read(projectsProvider.notifier).loadProjects();
  }

  Future<void> _refreshProjects() {
    return ref.read(projectsProvider.notifier).loadProjects();
  }

  Future<void> _logout() async {
    final confirmed = await showLogoutConfirmationDialog(context);
    if (!confirmed || !mounted) {
      return;
    }

    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(projectsProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ProSpacing.md,
            ProSpacing.md,
            ProSpacing.md,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProjectSelectionHeader(
                user: user,
                state: state,
                onRefresh: state.isLoading ? null : _refreshProjects,
                onBack:
                    Navigator.canPop(context)
                        ? () => Navigator.pop(context)
                        : null,
                onLogout: _logout,
              ),
              const SizedBox(height: ProSpacing.md),
              Expanded(child: _buildContent(context, state)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProjectsState state) {
    if (state.isLoading && state.projects.isEmpty) {
      return _buildStateList(
        child: const _ProjectSelectionStateCard(
          title: 'Загружаем объекты',
          description: 'Проверяем доступные объекты организации.',
          isLoading: true,
        ),
      );
    }

    if (state.error != null && state.projects.isEmpty) {
      return _buildStateList(
        child: _ProjectSelectionStateCard(
          icon: Icons.error_outline_rounded,
          iconColor: Theme.of(context).colorScheme.error,
          title: 'Не удалось загрузить объекты',
          description: state.error,
          action: AppSecondaryActionButton(
            label: 'Повторить',
            onPressed: _refreshProjects,
            leading: const Icon(Icons.refresh_rounded),
            expanded: false,
          ),
        ),
      );
    }

    if (state.projects.isEmpty) {
      return _buildStateList(
        child: _ProjectSelectionStateCard(
          icon: Icons.folder_off_outlined,
          title: 'Нет доступных объектов',
          description:
              'Объекты появятся здесь после выдачи доступа администратором организации.',
          action: AppSecondaryActionButton(
            label: 'Обновить список',
            onPressed: _refreshProjects,
            leading: const Icon(Icons.refresh_rounded),
            expanded: false,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshProjects,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: ProSpacing.bottomNavSafe),
        itemCount: state.projects.length,
        separatorBuilder: (_, _) => const SizedBox(height: ProSpacing.sm),
        itemBuilder: (context, index) {
          final project = state.projects[index];

          return ProjectCard(
            project: project,
            isSelected: state.selectedProject?.serverId == project.serverId,
            onTap: () {
              ref.read(projectsProvider.notifier).selectProject(project);
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildStateList({required Widget child}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: ProSpacing.bottomNavSafe),
      children: [child],
    );
  }
}

class _ProjectSelectionHeader extends StatelessWidget {
  const _ProjectSelectionHeader({
    required this.user,
    required this.state,
    required this.onRefresh,
    required this.onBack,
    required this.onLogout,
  });

  final User? user;
  final ProjectsState state;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onBack;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedProject = state.selectedProject;

    return ProSurface(
      tone: ProSurfaceTone.elevated,
      padding: const EdgeInsets.all(ProSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: ProTouchTarget.comfortable,
                height: ProTouchTarget.comfortable,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ProRadius.md),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(
                  Icons.engineering_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: ProSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Рабочий контекст',
                      style: AppTypography.caption(context),
                    ),
                    const SizedBox(height: ProSpacing.xxs),
                    Text(
                      'Привет, ${_displayName(user)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h2(context),
                    ),
                    const SizedBox(height: ProSpacing.xxs),
                    Text(
                      'Выберите объект для работы',
                      style: AppTypography.bodyMedium(
                        context,
                      ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ProSpacing.xs),
              IconButton(
                tooltip: 'Обновить список объектов',
                onPressed: onRefresh,
                icon: const Icon(
                  Icons.refresh_rounded,
                  semanticLabel: 'Обновить список объектов',
                ),
              ),
              if (onBack == null)
                IconButton(
                  tooltip: 'Выйти из аккаунта',
                  onPressed: onLogout,
                  icon: Icon(
                    Icons.logout_rounded,
                    semanticLabel: 'Выйти из аккаунта',
                    color: theme.colorScheme.error,
                  ),
                )
              else
                IconButton(
                  tooltip: 'Вернуться к обзору',
                  onPressed: onBack,
                  icon: const Icon(
                    Icons.close_rounded,
                    semanticLabel: 'Вернуться к обзору',
                  ),
                ),
            ],
          ),
          const SizedBox(height: ProSpacing.md),
          Wrap(
            spacing: ProSpacing.xs,
            runSpacing: ProSpacing.xs,
            children: [
              _ContextBadge(
                icon: Icons.business_rounded,
                label: _organizationName(user),
              ),
              _ContextBadge(
                icon: Icons.apartment_rounded,
                label: _objectCountLabel(state.projects.length),
              ),
              _ContextBadge(
                icon:
                    selectedProject == null
                        ? Icons.rule_folder_outlined
                        : Icons.check_circle_rounded,
                label:
                    selectedProject == null
                        ? 'Объект не выбран'
                        : 'Выбран: ${selectedProject.name}',
                emphasized: selectedProject != null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _displayName(User? user) {
    final name = user?.name.trim();
    if (name == null || name.isEmpty) {
      return 'пользователь';
    }

    return name;
  }

  static String _organizationName(User? user) {
    final organizationName = user?.organizationName?.trim();
    if (organizationName == null || organizationName.isEmpty) {
      return 'Организация не указана';
    }

    return organizationName;
  }

  static String _objectCountLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;

    if (mod10 == 1 && mod100 != 11) {
      return '$count объект';
    }

    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return '$count объекта';
    }

    return '$count объектов';
  }
}

class _ContextBadge extends StatelessWidget {
  const _ContextBadge({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground =
        emphasized ? theme.colorScheme.primary : theme.colorScheme.onSurface;
    final background =
        emphasized
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHigh;

    return Container(
      constraints: const BoxConstraints(minHeight: ProTouchTarget.min),
      padding: const EdgeInsets.symmetric(
        horizontal: ProSpacing.sm,
        vertical: ProSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ProRadius.sm),
        border: Border.all(
          color:
              emphasized
                  ? theme.colorScheme.primary.withValues(alpha: 0.26)
                  : theme.colorScheme.outline.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: ProSpacing.xs),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall(context).copyWith(
                  color: foreground,
                  fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectSelectionStateCard extends StatelessWidget {
  const _ProjectSelectionStateCard({
    required this.title,
    this.description,
    this.icon,
    this.iconColor,
    this.action,
    this.isLoading = false,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final Color? iconColor;
  final Widget? action;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.colorScheme.primary;

    return ProSurface(
      tone: ProSurfaceTone.elevated,
      padding: const EdgeInsets.all(ProSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: ProTouchTarget.comfortable,
            height: ProTouchTarget.comfortable,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(ProRadius.md),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child:
                isLoading
                    ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: color,
                      ),
                    )
                    : Icon(
                      icon ?? Icons.info_outline_rounded,
                      size: 30,
                      color: color,
                    ),
          ),
          const SizedBox(width: ProSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.h2(context).copyWith(fontSize: 18),
                ),
                if (description != null) ...[
                  const SizedBox(height: ProSpacing.xxs),
                  Text(
                    description!,
                    style: AppTypography.bodyMedium(
                      context,
                    ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: ProSpacing.sm),
                  Align(alignment: Alignment.centerLeft, child: action!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
