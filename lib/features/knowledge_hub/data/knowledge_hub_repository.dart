import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/network/dio_client.dart';
import 'package:prohelpers_mobile/core/network/mobile_api_response.dart';

import 'knowledge_article_model.dart';

final knowledgeHubRepositoryProvider = Provider<KnowledgeHubRepository>((ref) {
  return KnowledgeHubRepository(ref.read(dioProvider));
});

enum KnowledgeFeedbackReaction {
  helpful('helpful'),
  notHelpful('not_helpful');

  const KnowledgeFeedbackReaction(this.value);

  final String value;
}

class KnowledgeArticlePage {
  const KnowledgeArticlePage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  final List<KnowledgeArticleModel> items;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}

class KnowledgeContextHelpModel {
  const KnowledgeContextHelpModel({
    required this.primary,
    required this.suggested,
    required this.context,
  });

  final KnowledgeArticleModel? primary;
  final List<KnowledgeArticleModel> suggested;
  final Map<String, dynamic> context;

  factory KnowledgeContextHelpModel.fromJson(Map<String, dynamic> json) {
    final primary = _mapValue(json['primary']);

    return KnowledgeContextHelpModel(
      primary:
          primary.isEmpty ? null : KnowledgeArticleModel.fromJson(primary),
      suggested:
          _mapList(json['suggested'])
              .map(KnowledgeArticleModel.fromJson)
              .toList(growable: false),
      context: _mapValue(json['context']),
    );
  }
}

class KnowledgeHubRepository {
  KnowledgeHubRepository(this._dio);

  final Dio _dio;

  Future<KnowledgeArticlePage> fetchArticles({
    int page = 1,
    int perPage = 20,
    String? query,
    String? moduleSlug,
    String? contextKey,
    String? permissionKey,
  }) async {
    final normalizedQuery = query?.trim();
    final hasQuery = normalizedQuery != null && normalizedQuery.length >= 2;

    try {
      final response = await _dio.get(
        hasQuery ? '/knowledge-hub/search' : '/knowledge-hub/articles',
        queryParameters: _queryParameters({
          'page': page,
          'per_page': perPage,
          if (hasQuery) 'q': normalizedQuery,
          'module_slug': moduleSlug,
          'context_key': contextKey,
          'permission_key': permissionKey,
        }),
      );
      final payload = MobileApiResponse.list(response.data);

      return KnowledgeArticlePage(
        items:
            payload.data
                .map(KnowledgeArticleModel.fromJson)
                .toList(growable: false),
        currentPage: _intValue(payload.meta['current_page'], fallback: page),
        lastPage: _intValue(payload.meta['last_page'], fallback: page),
        perPage: _intValue(payload.meta['per_page'], fallback: perPage),
        total: _intValue(payload.meta['total'], fallback: payload.data.length),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить базу знаний.',
      );
    }
  }

  Future<List<KnowledgeArticleModel>> fetchTree({
    String? moduleSlug,
    String? contextKey,
  }) async {
    try {
      final response = await _dio.get(
        '/knowledge-hub/tree',
        queryParameters: _queryParameters({
          'module_slug': moduleSlug,
          'context_key': contextKey,
        }),
      );

      return MobileApiResponse.dataList(response.data)
          .map(KnowledgeArticleModel.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить структуру базы знаний.',
      );
    }
  }

  Future<KnowledgeContextHelpModel> fetchContextHelp({
    required String contextKey,
    String? moduleSlug,
    String? permissionKey,
    int limit = 4,
  }) async {
    try {
      final response = await _dio.get(
        '/knowledge-hub/context',
        queryParameters: _queryParameters({
          'context_key': contextKey,
          'module_slug': moduleSlug,
          'permission_key': permissionKey,
          'limit': limit,
        }),
      );

      return KnowledgeContextHelpModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить подсказку.',
      );
    }
  }

  Future<KnowledgeArticleModel> fetchArticle(String slug) async {
    try {
      final response = await _dio.get('/knowledge-hub/articles/$slug');

      return KnowledgeArticleModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось открыть статью.',
      );
    }
  }

  Future<void> sendFeedback({
    required int articleId,
    required KnowledgeFeedbackReaction reaction,
    String? moduleSlug,
    String? contextKey,
    String? permissionKey,
    String? comment,
  }) async {
    try {
      await _dio.post(
        '/knowledge-hub/feedback',
        data: _queryParameters({
          'article_id': articleId,
          'reaction': reaction.value,
          'module_slug': moduleSlug,
          'context_key': contextKey,
          'permission_key': permissionKey,
          'comment': comment,
        }),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось сохранить оценку статьи.',
      );
    }
  }
}

Map<String, dynamic> _queryParameters(Map<String, dynamic> values) {
  final result = <String, dynamic>{};

  for (final entry in values.entries) {
    final value = entry.value;

    if (value == null) {
      continue;
    }

    if (value is String && value.trim().isEmpty) {
      continue;
    }

    result[entry.key] = value is String ? value.trim() : value;
  }

  return result;
}

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }

  return value
      .whereType<Map>()
      .map((item) => item.map((key, entry) => MapEntry(key.toString(), entry)))
      .toList(growable: false);
}

int _intValue(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
