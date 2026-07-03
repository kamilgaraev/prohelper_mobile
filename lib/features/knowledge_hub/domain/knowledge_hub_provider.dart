import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/data/knowledge_article_model.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/data/knowledge_hub_repository.dart';

const _knowledgeHubSentinel = Object();

class KnowledgeHubState {
  const KnowledgeHubState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.articles = const <KnowledgeArticleModel>[],
    this.tree = const <KnowledgeArticleModel>[],
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.query = '',
    this.error,
  });

  final bool isLoading;
  final bool isLoadingMore;
  final List<KnowledgeArticleModel> articles;
  final List<KnowledgeArticleModel> tree;
  final int currentPage;
  final int lastPage;
  final int total;
  final String query;
  final String? error;

  bool get hasMore => currentPage < lastPage;

  KnowledgeHubState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<KnowledgeArticleModel>? articles,
    List<KnowledgeArticleModel>? tree,
    int? currentPage,
    int? lastPage,
    int? total,
    String? query,
    Object? error = _knowledgeHubSentinel,
  }) {
    return KnowledgeHubState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      articles: articles ?? this.articles,
      tree: tree ?? this.tree,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      total: total ?? this.total,
      query: query ?? this.query,
      error:
          identical(error, _knowledgeHubSentinel)
              ? this.error
              : error as String?,
    );
  }
}

final knowledgeHubProvider =
    StateNotifierProvider<KnowledgeHubNotifier, KnowledgeHubState>((ref) {
      return KnowledgeHubNotifier(ref.read(knowledgeHubRepositoryProvider));
    });

class KnowledgeHubNotifier extends StateNotifier<KnowledgeHubState> {
  KnowledgeHubNotifier(this._repository) : super(const KnowledgeHubState()) {
    load(refresh: true);
  }

  final KnowledgeHubRepository _repository;

  Future<void> load({bool refresh = false}) async {
    if (state.isLoading || state.isLoadingMore) {
      return;
    }

    if (!refresh && !state.hasMore) {
      return;
    }

    final nextPage = refresh ? 1 : state.currentPage + 1;

    state = state.copyWith(
      isLoading: refresh,
      isLoadingMore: !refresh,
      articles: refresh ? const <KnowledgeArticleModel>[] : null,
      currentPage: refresh ? 1 : state.currentPage,
      lastPage: refresh ? 1 : state.lastPage,
      total: refresh ? 0 : state.total,
      error: null,
    );

    try {
      final tree =
          refresh ? await _repository.fetchTree() : state.tree;
      final page = await _repository.fetchArticles(
        page: nextPage,
        query: state.query,
      );

      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        tree: tree,
        articles:
            refresh
                ? page.items
                : <KnowledgeArticleModel>[...state.articles, ...page.items],
        currentPage: page.currentPage,
        lastPage: page.lastPage,
        total: page.total,
        error: null,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: _errorMessage(error),
      );
    }
  }

  Future<void> setQuery(String value) async {
    final normalized = value.trim();

    if (normalized == state.query) {
      return;
    }

    state = state.copyWith(query: normalized);
    await load(refresh: true);
  }

  Future<void> clearQuery() async {
    if (state.query.isEmpty) {
      return;
    }

    state = state.copyWith(query: '');
    await load(refresh: true);
  }
}

class KnowledgeArticleDetailState {
  const KnowledgeArticleDetailState({
    this.isLoading = false,
    this.isSubmittingFeedback = false,
    this.article,
    this.feedbackReaction,
    this.error,
  });

  final bool isLoading;
  final bool isSubmittingFeedback;
  final KnowledgeArticleModel? article;
  final KnowledgeFeedbackReaction? feedbackReaction;
  final String? error;

  KnowledgeArticleDetailState copyWith({
    bool? isLoading,
    bool? isSubmittingFeedback,
    KnowledgeArticleModel? article,
    KnowledgeFeedbackReaction? feedbackReaction,
    bool clearFeedbackReaction = false,
    Object? error = _knowledgeHubSentinel,
  }) {
    return KnowledgeArticleDetailState(
      isLoading: isLoading ?? this.isLoading,
      isSubmittingFeedback:
          isSubmittingFeedback ?? this.isSubmittingFeedback,
      article: article ?? this.article,
      feedbackReaction:
          clearFeedbackReaction
              ? null
              : feedbackReaction ?? this.feedbackReaction,
      error:
          identical(error, _knowledgeHubSentinel)
              ? this.error
              : error as String?,
    );
  }
}

final knowledgeArticleDetailProvider = StateNotifierProvider.family<
  KnowledgeArticleDetailNotifier,
  KnowledgeArticleDetailState,
  String
>((ref, slug) {
  return KnowledgeArticleDetailNotifier(
    ref.read(knowledgeHubRepositoryProvider),
    slug,
  );
});

class KnowledgeArticleDetailNotifier
    extends StateNotifier<KnowledgeArticleDetailState> {
  KnowledgeArticleDetailNotifier(this._repository, this._slug)
    : super(const KnowledgeArticleDetailState()) {
    load();
  }

  final KnowledgeHubRepository _repository;
  final String _slug;

  Future<void> load() async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      clearFeedbackReaction: true,
    );

    try {
      final article = await _repository.fetchArticle(_slug);
      state = state.copyWith(
        isLoading: false,
        article: article,
        error: null,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: _errorMessage(error));
    }
  }

  Future<void> submitFeedback(KnowledgeFeedbackReaction reaction) async {
    final article = state.article;
    if (article == null || state.isSubmittingFeedback) {
      return;
    }

    state = state.copyWith(isSubmittingFeedback: true, error: null);

    try {
      await _repository.sendFeedback(
        articleId: article.id,
        reaction: reaction,
        moduleSlug:
            article.moduleSlugs.isNotEmpty ? article.moduleSlugs.first : null,
        contextKey:
            article.contextKeys.isNotEmpty ? article.contextKeys.first : null,
      );
      state = state.copyWith(
        isSubmittingFeedback: false,
        feedbackReaction: reaction,
        error: null,
      );
    } catch (error) {
      state = state.copyWith(
        isSubmittingFeedback: false,
        error: _errorMessage(error),
      );
      rethrow;
    }
  }
}

class KnowledgeContextHelpParams {
  const KnowledgeContextHelpParams({
    required this.contextKey,
    this.moduleSlug,
    this.permissionKey,
    this.limit = 4,
  });

  final String contextKey;
  final String? moduleSlug;
  final String? permissionKey;
  final int limit;

  @override
  bool operator ==(Object other) {
    return other is KnowledgeContextHelpParams &&
        other.contextKey == contextKey &&
        other.moduleSlug == moduleSlug &&
        other.permissionKey == permissionKey &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(
    contextKey,
    moduleSlug,
    permissionKey,
    limit,
  );
}

final knowledgeContextHelpProvider = FutureProvider.family<
  KnowledgeContextHelpModel,
  KnowledgeContextHelpParams
>((ref, params) {
  return ref
      .read(knowledgeHubRepositoryProvider)
      .fetchContextHelp(
        contextKey: params.contextKey,
        moduleSlug: params.moduleSlug,
        permissionKey: params.permissionKey,
        limit: params.limit,
      );
});

String _errorMessage(Object error) {
  if (error is ApiException) {
    return error.message;
  }

  return 'Не удалось обработать данные базы знаний.';
}
