import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/mesh_background.dart';
import '../domain/site_requests_provider.dart';
import '../widgets/site_request_card.dart';
import 'site_request_detail_screen.dart';
import 'site_request_form_screen.dart';

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
          title: Text('Заявки с объекта', style: AppTypography.h1),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list_rounded),
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
                        Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Заявок пока нет',
                          style: AppTypography.h2.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Создайте первую заявку, нажав на кнопĸу +',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
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
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}
