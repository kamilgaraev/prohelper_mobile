import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/theme/app_colors.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/mesh_background.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/widgets/site_request_card.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_request_detail_screen.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_request_form_screen.dart';

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
    
    // Первичная загрузка
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(siteRequestsProvider.notifier).loadRequests(refresh: true);
    });
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
    final theme = Theme.of(context);
    
    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Заявки с объекта', style: AppTypography.h1.copyWith(color: theme.colorScheme.onSurface)),
          centerTitle: false,
          actions: [
            IconButton(
              icon: Icon(Icons.filter_list_rounded, color: theme.colorScheme.onSurface),
              onPressed: () {
                // TODO: Показать фильтры
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await ref.read(siteRequestsProvider.notifier).loadRequests(refresh: true);
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (state.requests.isEmpty && !state.isLoading)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Заявок пока нет',
                          style: AppTypography.h2.copyWith(color: theme.colorScheme.onSurface),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Создайте первую заявку, нажав на кнопку +',
                          style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
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
                                  builder: (context) => SiteRequestDetailScreen(id: request.serverId),
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
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
              // Отступ снизу для FAB
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SiteRequestFormScreen(),
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
