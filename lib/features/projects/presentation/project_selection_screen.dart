import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/app_action_buttons.dart';
import 'package:prohelpers_mobile/core/widgets/pro_status_banner.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_session_identity.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/auth/presentation/widgets/logout_confirmation_dialog.dart';
import 'package:prohelpers_mobile/features/auth/presentation/widgets/user_profile_bottom_sheet.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/projects/presentation/widgets/project_card.dart';
import '../../design_management/offline/bim_context_change_dialog.dart';

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

  void _showUserProfile() {
    final user = ref.read(authProvider).user;
    if (user == null) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      barrierLabel: 'Закрыть профиль',
      builder: (_) => UserProfileBottomSheet(user: user),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showLogoutConfirmationDialog(context);
    if (!confirmed || !mounted) {
      return;
    }
    if (!await prepareBimContextChange(context, ref) || !mounted) return;

    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthSessionIdentity?>(
      authProvider.select(
        (state) => state is AuthAuthenticated ? state.sessionIdentity : null,
      ),
      (previous, next) {
        if (previous == next || next == null) {
          return;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadProjectsOnce();
          }
        });
      },
    );

    final theme = Theme.of(context);
    final state = ref.watch(projectsProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshProjects,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  ProSpacing.md,
                  ProSpacing.md,
                  ProSpacing.md,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _ProjectSelectionHeader(
                    user: user,
                    state: state,
                    onRefresh: state.isLoading ? null : _refreshProjects,
                    onProfile: _showUserProfile,
                    onBack:
                        Navigator.canPop(context)
                            ? () => Navigator.pop(context)
                            : null,
                    onLogout: _logout,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: ProSpacing.md)),
              if (state.fromCache)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    ProSpacing.md,
                    0,
                    ProSpacing.md,
                    ProSpacing.md,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: ProStatusBanner(
                      title: 'Сохранённые объекты',
                      description: 'Проверьте обновления при появлении связи.',
                      compact: true,
                      fullText: true,
                    ),
                  ),
                ),
              _buildContent(context, state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProjectsState state) {
    final Widget sliver;
    final compact = MediaQuery.sizeOf(context).width < 360;

    if (state.isLoading && state.projects.isEmpty) {
      sliver = const SliverToBoxAdapter(
        child: _ProjectSelectionStateCard(
          title: 'Загружаем объекты',
          description: 'Проверяем доступные объекты организации.',
          isLoading: true,
        ),
      );
    } else if (state.error != null && state.projects.isEmpty) {
      sliver = SliverToBoxAdapter(
        child: _ProjectSelectionStateCard(
          icon: Icons.error_outline_rounded,
          iconColor: Theme.of(context).colorScheme.error,
          title: 'Не удалось загрузить объекты',
          description: state.error,
          action: AppSecondaryActionButton(
            label: 'Повторить',
            onPressed: _refreshProjects,
            leading: compact ? null : const Icon(Icons.refresh_rounded),
            expanded: false,
          ),
        ),
      );
    } else if (state.projects.isEmpty) {
      sliver = SliverToBoxAdapter(
        child: _ProjectSelectionStateCard(
          icon: Icons.folder_off_outlined,
          title: 'Нет доступных объектов',
          description:
              'Объекты появятся здесь после выдачи доступа администратором организации.',
          action: AppSecondaryActionButton(
            label: compact ? 'Обновить' : 'Обновить список',
            onPressed: _refreshProjects,
            leading: compact ? null : const Icon(Icons.refresh_rounded),
            expanded: false,
          ),
        ),
      );
    } else {
      sliver = SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index.isOdd) {
            return const SizedBox(height: ProSpacing.sm);
          }

          final project = state.projects[index ~/ 2];
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
        }, childCount: state.projects.length * 2 - 1),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        ProSpacing.md,
        0,
        ProSpacing.md,
        ProSpacing.bottomNavSafe,
      ),
      sliver: sliver,
    );
  }
}

class _ProjectSelectionHeader extends StatelessWidget {
  const _ProjectSelectionHeader({
    required this.user,
    required this.state,
    required this.onRefresh,
    required this.onProfile,
    required this.onBack,
    required this.onLogout,
  });

  final User? user;
  final ProjectsState state;
  final Future<void> Function()? onRefresh;
  final VoidCallback onProfile;
  final VoidCallback? onBack;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedProject = state.selectedProject;
    final profileButton = Tooltip(
      message: 'Профиль и организации',
      child: Material(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ProRadius.md),
          side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.18),
          ),
        ),
        child: InkWell(
          onTap: user == null ? null : onProfile,
          borderRadius: BorderRadius.circular(ProRadius.md),
          child: SizedBox(
            width: ProTouchTarget.comfortable,
            height: ProTouchTarget.comfortable,
            child: Icon(
              Icons.engineering_rounded,
              color: theme.colorScheme.primary,
              semanticLabel: 'Открыть профиль и организации',
            ),
          ),
        ),
      ),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
    );
    Widget identity({required bool compact, required bool includePrompt}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Рабочий контекст', style: AppTypography.caption(context)),
          const SizedBox(height: ProSpacing.xxs),
          Text(
            'Привет, ${_displayName(user)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.h2(
              context,
            ).copyWith(fontSize: compact ? 20 : null),
          ),
          if (includePrompt) ...[
            const SizedBox(height: ProSpacing.xxs),
            Text(
              'Выберите объект для работы',
              style: AppTypography.bodyMedium(
                context,
              ).copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      );
    }

    return ProSurface(
      tone: ProSurfaceTone.elevated,
      padding: const EdgeInsets.all(ProSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    profileButton,
                    const SizedBox(width: ProSpacing.sm),
                    Expanded(
                      child: identity(compact: true, includePrompt: false),
                    ),
                  ],
                ),
                const SizedBox(height: ProSpacing.xs),
                Text(
                  'Выберите объект для работы',
                  style: AppTypography.bodyMedium(
                    context,
                  ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                Align(alignment: Alignment.centerRight, child: actions),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    profileButton,
                    const SizedBox(width: ProSpacing.sm),
                    Expanded(
                      child: identity(compact: false, includePrompt: true),
                    ),
                    const SizedBox(width: ProSpacing.xs),
                    actions,
                  ],
                ),
              ],
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
          );
        },
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
    final stateIcon = Container(
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
                child: CircularProgressIndicator(strokeWidth: 3, color: color),
              )
              : Icon(
                icon ?? Icons.info_outline_rounded,
                size: 30,
                color: color,
              ),
    );
    Widget stateContent({required bool compact}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.h2(context).copyWith(fontSize: 18)),
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
            if (compact)
              SizedBox(width: double.infinity, child: action!)
            else
              Align(alignment: Alignment.centerLeft, child: action!),
          ],
        ],
      );
    }

    return ProSurface(
      tone: ProSurfaceTone.elevated,
      padding: const EdgeInsets.all(ProSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stateIcon,
                const SizedBox(height: ProSpacing.sm),
                stateContent(compact: true),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stateIcon,
              const SizedBox(width: ProSpacing.sm),
              Expanded(child: stateContent(compact: false)),
            ],
          );
        },
      ),
    );
  }
}
