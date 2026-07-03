import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/data/knowledge_hub_repository.dart';

void main() {
  test('searches articles with module context and pagination meta', () async {
    late RequestOptions request;
    final dio = _dio(
      _JsonAdapter((options) {
        request = options;

        return _responseData(
          [
            {
              'id': 12,
              'title': 'Site request flow',
              'slug': 'site-request-flow',
              'excerpt': 'How to create and track requests',
              'snippet': '<mark>request</mark> flow',
              'kind': 'article',
              'kind_label': 'Article',
              'reading_time': 4,
              'is_pinned': true,
              'depth': 1,
              'tags': ['site-requests'],
              'module_slugs': ['site-requests'],
              'context_keys': ['site_requests.index'],
            },
          ],
          meta: {
            'current_page': 1,
            'last_page': 2,
            'per_page': 1,
            'total': 2,
          },
        );
      }),
    );
    final repository = KnowledgeHubRepository(dio);

    final page = await repository.fetchArticles(
      query: ' request ',
      moduleSlug: 'site-requests',
      contextKey: 'site_requests.index',
      perPage: 1,
    );

    expect(request.path, '/knowledge-hub/search');
    expect(request.queryParameters['q'], 'request');
    expect(request.queryParameters['module_slug'], 'site-requests');
    expect(request.queryParameters['context_key'], 'site_requests.index');
    expect(page.items.single.slug, 'site-request-flow');
    expect(page.items.single.snippetText, 'request flow');
    expect(page.currentPage, 1);
    expect(page.lastPage, 2);
    expect(page.total, 2);
  });

  test('loads contextual help and article details', () async {
    final requests = <RequestOptions>[];
    final dio = _dio(
      _JsonAdapter((options) {
        requests.add(options);

        if (options.path == '/knowledge-hub/context') {
          return _responseData({
            'primary': _articleJson(slug: 'site-request-flow'),
            'suggested': [_articleJson(slug: 'request-statuses')],
            'context': {'context_key': 'site_requests.index'},
          });
        }

        return _responseData({
          ..._articleJson(slug: 'site-request-flow'),
          'content': '<h2>Start</h2><p>Create a request.</p>',
          'plain_text': 'Start Create a request.',
          'children': [_articleJson(slug: 'request-statuses')],
          'related': [_articleJson(slug: 'warehouse-acceptance')],
        });
      }),
    );
    final repository = KnowledgeHubRepository(dio);

    final help = await repository.fetchContextHelp(
      contextKey: 'site_requests.index',
      moduleSlug: 'site-requests',
    );
    final article = await repository.fetchArticle('site-request-flow');

    expect(requests.first.path, '/knowledge-hub/context');
    expect(requests.first.queryParameters['context_key'], 'site_requests.index');
    expect(help.primary?.slug, 'site-request-flow');
    expect(help.suggested.single.slug, 'request-statuses');
    expect(requests.last.path, '/knowledge-hub/articles/site-request-flow');
    expect(article.plainText, 'Start Create a request.');
    expect(article.children.single.slug, 'request-statuses');
    expect(article.related.single.slug, 'warehouse-acceptance');
  });

  test('sends article feedback with mobile context', () async {
    late RequestOptions request;
    final dio = _dio(
      _JsonAdapter((options) {
        request = options;
        return _responseData({'id': 44});
      }),
    );
    final repository = KnowledgeHubRepository(dio);

    await repository.sendFeedback(
      articleId: 12,
      reaction: KnowledgeFeedbackReaction.helpful,
      moduleSlug: 'site-requests',
      contextKey: 'site_requests.index',
    );

    expect(request.method, 'POST');
    expect(request.path, '/knowledge-hub/feedback');
    expect(request.data['article_id'], 12);
    expect(request.data['reaction'], 'helpful');
    expect(request.data['module_slug'], 'site-requests');
    expect(request.data['context_key'], 'site_requests.index');
  });
}

Dio _dio(HttpClientAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'https://api.prohelper.test'))
    ..httpClientAdapter = adapter;
}

Map<String, dynamic> _articleJson({required String slug}) {
  return {
    'id': slug.hashCode.abs(),
    'title': slug,
    'slug': slug,
    'excerpt': 'Article excerpt',
    'kind': 'article',
    'kind_label': 'Article',
    'reading_time': 3,
    'is_pinned': false,
    'depth': 0,
    'tags': ['help'],
    'module_slugs': ['site-requests'],
    'context_keys': ['site_requests.index'],
  };
}

Map<String, dynamic> _responseData(dynamic data, {Map<String, dynamic>? meta}) {
  return {
    'success': true,
    'message': null,
    'data': data,
    if (meta != null) 'meta': meta,
  };
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.handler);

  final Map<String, dynamic> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await requestStream?.drain<void>();

    return ResponseBody.fromString(
      jsonEncode(handler(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
