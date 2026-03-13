import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/app_state_view.dart';
import 'package:prohelpers_mobile/core/widgets/mesh_background.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_request_detail_screen.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_request_form_screen.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/widgets/site_request_card.dart';

class SiteRequestsScreen extends ConsumerStatefulWidget {
  const SiteRequestsScreen({super.key});

  @override
  ConsumerState<SiteRequestsScreen> createState() => _SiteRequestsScreenState();
}

class _SiteRequestsScreenState extends ConsumerState<SiteRequestsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(siteRequestsProvider.notifier).loadRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(siteRequestsProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;
    final theme = Theme.of(context);

    ref.listen<SiteRequestsState>(siteRequestsProvider, (previous, next) {
      final shouldShowError = next.error != null &&
          next.error != previous?.error &&
          next.requests.isNotEmpty;
      if (!shouldShowError || !mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next.error!)),
      );
    });

    if (selectedProject != null &&
        !state.isLoading &&
        state.requests.isEmpty &&
        state.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(siteRequestsProvider.notifier).syncProject(selectedProject?.serverId);
        ref.read(siteRequestsProvider.notifier).loadRequests(refresh: true);
      });
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Заявки с объекта', style: AppTypography.h1(context)),
              if (selectedProject != null)
                Text(
                  selectedProject.name,
                  style: AppTypography.caption(context).copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          centerTitle: false,
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            if (selectedProject == null) {
              return;
            }

            ref.read(siteRequestsProvider.notifier).syncProject(selectedProject?.serverId);
            await ref.read(siteRequestsProvider.notifier).loadRequests(refresh: true);
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (state.error != null && state.requests.isEmpty)
                SliverFillRemaining(
                  child: AppStateView(
                    icon: Icons.error_outline_rounded,
                    title: 'Не удалось загрузить заявки',
                    description: state.error,
                    action: OutlinedButton(
                      onPressed: () => ref.read(siteRequestsProvider.notifier).loadRequests(refresh: true),
                      child: const Text('Повторить'),
                    ),
                  ),
                )
              else if (state.requests.isEmpty && !state.isLoading)
                SliverFillRemaining(
                  child: AppStateView(
                    icon: Icons.inventory_2_outlined,
                    title: 'Заявок пока нет',
                    description: selectedProject == null
                        ? 'Сначала выберите объект.'
                        : 'Создайте первую заявку для текущего объекта.',
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final request = state.requests[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SiteRequestCard(
                            request: request,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SiteRequestDetailScreen(id: request.serverId),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      childCount: state.requests.length,
                    ),
                  ),
                ),
                if (state.isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (selectedProject == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Сначала выберите объект.')),
              );
              return;
            }

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SiteRequestFormScreen(),
              ),
            );
          },
          backgroundColor: theme.colorScheme.primary,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}
