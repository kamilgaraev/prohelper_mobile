import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_navigation_registry.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/pro_action_tile.dart';
import 'package:prohelpers_mobile/core/widgets/pro_page_scaffold.dart';
import 'package:prohelpers_mobile/core/widgets/pro_section.dart';
import 'package:prohelpers_mobile/core/widgets/pro_status_banner.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/actions/presentation/mobile_action_search.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/auth/presentation/widgets/user_profile_bottom_sheet.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/projects/presentation/project_selection_screen.dart';

class MobileMoreScreen extends ConsumerWidget {
  const MobileMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectsProvider).selectedProject;
    final authState = ref.watch(authProvider);
    final modules = ref.watch(supportedMobileModulesProvider);
    final hasSelectedProject = project != null;
    final managementDestinations = uniqueDestinations(
          modules.map(
            (module) =>
                MobileNavigationRegistry.destinationForRoute(module.route) ??
                MobileNavigationRegistry.destinationForRoute(module.slug),
          ),
        )
        .where(
          (destination) =>
              destination.group == MobileModuleGroup.management &&
              (!destination.requiresProject || hasSelectedProject),
        )
        .toList(growable: false);

    final user = authState is AuthAuthenticated ? authState.user : null;

    return ProPageScaffold(
      title: 'Ещё',
      subtitle: 'Управление, справочники и профиль',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user != null) ...[
            ProSurface(
              onTap:
                  () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => UserProfileBottomSheet(user: user),
                  ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    child: Text(_initials(user.name)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyLarge(
                            context,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(context),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          ProStatusBanner(
            title: project?.name ?? 'Объект не выбран',
            description:
                project?.address ?? 'Выберите объект для рабочих разделов.',
            tone: project == null ? ProStatusTone.warning : ProStatusTone.info,
            action: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProjectSelectionScreen(),
                      ),
                    ),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Сменить объект'),
              ),
            ),
          ),
          if (managementDestinations.isNotEmpty) ...[
            const SizedBox(height: 20),
            ProSectionBlock(
              title: 'Управление',
              subtitle: 'Вторичные разделы, настройки данных и контроль.',
              children: [
                for (final destination in managementDestinations)
                  ProActionTile(
                    title: destination.shortTitle,
                    subtitle:
                        destination.title == destination.shortTitle
                            ? destination.recommendedReason
                            : '${destination.title} · ${destination.recommendedReason}',
                    icon: destination.icon,
                    onTap:
                        () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: destination.builder)),
                  ),
              ],
            ),
          ],
          if (user != null) ...[
            const SizedBox(height: 20),
            ProSectionBlock(
              title: 'Аккаунт',
              children: [
                ProActionTile(
                  title: 'Профиль',
                  subtitle: 'Данные пользователя и организации',
                  icon: Icons.person_outline_rounded,
                  onTap:
                      () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => UserProfileBottomSheet(user: user),
                      ),
                ),
                ProActionTile(
                  title: 'Выйти',
                  subtitle: 'Завершить текущую сессию',
                  icon: Icons.logout_rounded,
                  tone: ProStatusTone.danger,
                  onTap: () => ref.read(authProvider.notifier).logout(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  if (parts.isEmpty) {
    return 'P';
  }

  return parts.take(2).map((part) => part.substring(0, 1)).join();
}
