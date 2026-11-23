import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_models.dart';

void main() {
  test('document access markers preserve original source indices', () {
    final message = AiMessageModel.fromJson({
      'id': 17,
      'role': 'assistant',
      'metadata': {
        'source_refs_version': 'ordinary-publication-locator/1',
        'source_refs': [
          null,
          {'entity_type': 'assistant_document', 'entity_id': 18},
          {'entity_type': 'estimate', 'entity_id': 19},
        ],
      },
    });
    expect(message.presentationSources.keys, [1, 2]);
    expect(message.presentationSources[1]?.documentPreview, isTrue);
    expect(message.presentationSources[2]?.documentPreview, isFalse);
  });

  test(
    'reads only canonical native article links from v1 assistant sources',
    () {
      Map<String, dynamic> article(String url, {String? label}) => {
        'source_type': 'knowledge',
        'entity_type': 'knowledge_article',
        'display_label': label,
        'navigation': {'url': url},
      };
      const prefix = '/dashboard/help/knowledge/';
      final valid = article('${prefix}Field_1-%D0%A1', label: 'Порядок работ');
      final metadata = {
        'contract_version': 1,
        'source_refs': [
          valid,
          article('${prefix}Field_1-%D0%A1', label: 'Повтор источника'),
          article('${prefix}site-requests'),
          article('${prefix}Topic%21'),
          for (final suffix in [
            '',
            '.',
            '..',
            '%2E%2E',
            'nested/slug',
            'nested%2Fslug',
            'nested%5Cslug',
            'nested%252Fslug',
            'slug?query',
            'slug#header',
            'slug%3Fquery',
            'slug%23header',
            '%73lug',
            '%d0%a1',
            'С',
            'slug/',
            ' slug',
            'slug\n',
            'slug%00',
            'slug%C2%85',
            'slug%E2%80%AE',
            '%FF',
            '%',
          ])
            article('$prefix$suffix'),
          article('https://lk.xn--1-xtbgmf.xn--p1ai${prefix}slug'),
          article('//lk.xn--1-xtbgmf.xn--p1ai${prefix}slug'),
          article('/knowledge-hub/articles/slug'),
          {...article('${prefix}wrong-type'), 'source_type': 'project'},
          {...article('${prefix}wrong-entity'), 'entity_type': 'project'},
          {'source_ref': article('${prefix}nested-source')},
        ],
        'rag_context': {
          'sources': [article('${prefix}unchecked-rag')],
        },
        'evidence': [article('${prefix}unchecked-evidence')],
      };

      AiMessageModel message(String role, Object? contractVersion) =>
          AiMessageModel.fromJson({
            'id': 13,
            'role': role,
            'content': '[Откройте статью](${prefix}only-markdown)',
            'metadata': {...metadata, 'contract_version': contractVersion},
          });

      final sources = message('assistant', 1).knowledgeSources;
      expect(sources.map((source) => source.slug), [
        'Field_1-С',
        'site-requests',
        'Topic!',
      ]);
      expect(sources.first.title, 'Порядок работ');
      expect(sources[1].title, isNull);
      expect(message('assistant', '1').knowledgeSources, isEmpty);
      expect(message('assistant', 2).knowledgeSources, isEmpty);
      expect(message('assistant', null).knowledgeSources, isEmpty);
      expect(message('user', 1).knowledgeSources, isEmpty);
    },
  );

  test('loads public progress and a checked interim response from status', () {
    final request = AiAssistantChatRequest.fromJson({
      'request_id': 'request-1',
      'status': 'running',
      'accepted_at': '2026-11-19T08:00:00Z',
      'elapsed_seconds': 121,
      'progress': [
        {
          'id': 7,
          'key': 'check',
          'code': 'record_check',
          'state': 'failed',
          'at': '2026-11-19T08:01:00Z',
        },
        {'id': 8, 'code': 'private_tool_id', 'state': 'started'},
      ],
      'interim_result': {
        'key': 'answer',
        'revision': 2,
        'text': 'Проверены сроки.',
        'scope': {'kind': 'project', 'project_id': 7},
        'sources': [
          {'label': 'График работ', 'id': 'internal-record'},
          {'url': 'https://example.test'},
        ],
        'published_at': '2026-11-19T08:01:30Z',
      },
    });

    expect(request.acceptedAt, DateTime.utc(2026, 11, 19, 8));
    expect(request.elapsedSeconds, 121);
    expect(request.progress.single.key, 'check');
    expect(request.progress.single.state, 'failed');
    expect(request.progress.single.at, DateTime.utc(2026, 11, 19, 8, 1));
    expect(request.interimResult?.revision, 2);
    expect(request.interimResult?.isProjectScoped, isTrue);
    expect(request.interimResult?.sources, ['График работ']);
    expect(
      request.interimResult?.publishedAt,
      DateTime.utc(2026, 11, 19, 8, 1, 30),
    );
    expect(
      AiAssistantChatResult.fromJson({'result_key': 'answer'}).resultKey,
      'answer',
    );
  });

  test('drops interim text outside a supported checked scope', () {
    final request = AiAssistantChatRequest.fromJson({
      'status': 'running',
      'elapsed_seconds': -1,
      'interim_result': {
        'key': 'answer',
        'revision': 1,
        'text': 'Проверены сроки.',
        'scope': {'kind': 'project'},
        'published_at': '2026-11-19T08:01:30Z',
      },
    });
    expect(request.elapsedSeconds, isNull);
    expect(request.interimResult, isNull);
  });

  test('parses shadow billing status and zero actual charge', () {
    final balance = AiCreditsBalanceModel.fromJson({
      'included_minor': 500000,
      'purchased_minor': 0,
      'reserved_minor': 0,
      'available_minor': 500000,
      'charging_enabled': false,
      'billing_mode': 'shadow',
      'can_purchase': false,
      'can_manage_billing': true,
      'pack_purchase_enabled': false,
      'packs': [
        {'id': 'ai-credits-1000', 'units_minor': 100000, 'amount_minor': 50000},
      ],
    });
    final usage = AiCreditUsageModel.fromJson({
      'charged_minor': 0,
      'charging_enabled': false,
    });

    expect(balance.billingMode, 'shadow');
    expect(balance.chargingEnabled, isFalse);
    expect(balance.canPurchase, isFalse);
    expect(balance.packPurchaseEnabled, isFalse);
    expect(balance.canManageBilling, isTrue);
    expect(usage?.actualCharge, '0.00');
    expect(usage?.chargingEnabled, isFalse);
  });

  test('parses assistant report artifacts from structured metadata', () {
    final message = AiMessageModel.fromJson({
      'id': 12,
      'role': 'assistant',
      'content': 'Отчет готов',
      'created_at': '2026-05-20T10:00:00Z',
      'metadata': {
        'structured_payload': {
          'answer': 'Отчет готов',
          'artifacts': [
            {
              'filename': 'timeline.pdf',
              'download_url': 'https://example.test/timeline.pdf',
              'report_type': 'project_timelines',
              'storage_disk': 's3',
              'storage_path': 'org-1/reports/timeline.pdf',
              'filters': {'date_from': '2026-05-01', 'date_to': '2026-05-20'},
              'size': '2048',
            },
            'broken artifact',
          ],
        },
      },
    });

    expect(message.artifacts, hasLength(1));
    expect(message.artifacts.single.isReport, isTrue);
    expect(message.artifacts.single.displayTitle, 'timeline.pdf');
    expect(
      message.artifacts.single.downloadUrl,
      'https://example.test/timeline.pdf',
    );
    expect(message.artifacts.single.reportType, 'project_timelines');
    expect(message.artifacts.single.size, 2048);
    expect(message.artifacts.single.filters['date_from'], '2026-05-01');
  });

  test('keeps plain assistant message usable without metadata', () {
    final message = AiMessageModel.fromJson({
      'id': 13,
      'role': 'assistant',
      'content': 'Обычный ответ',
      'created_at': null,
    });

    expect(message.content, 'Обычный ответ');
    expect(message.artifacts, isEmpty);
  });

  test('parses assistant actions from structured metadata', () {
    final message = AiMessageModel.fromJson({
      'id': 14,
      'role': 'assistant',
      'content': 'Можно создать задачу',
      'created_at': '2026-05-22T10:00:00Z',
      'metadata': {
        'structured_payload': {
          'next_actions': [
            {
              'id': 'schedule-1',
              'type': 'act',
              'label': 'Создать задачу графика',
              'allowed': true,
              'requires_confirmation': true,
              'action_class': 'confirm',
              'tool_name': 'create_schedule_task',
              'arguments': {'project_id': 77},
              'required_permissions': ['schedule_tasks.create'],
            },
          ],
        },
      },
    });

    expect(message.actions, hasLength(1));
    expect(message.actions.single.label, 'Создать задачу графика');
    expect(message.actions.single.isExecutableCandidate, isTrue);
    expect(message.actions.single.arguments['project_id'], 77);
  });
  test(
    'parses source navigation and validation from authoritative metadata',
    () {
      final message = AiMessageModel.fromJson({
        'id': '12',
        'role': 'assistant',
        'content': 'Answer',
        'metadata': {
          'validation_status': 'partial',
          'source_refs': [
            {
              'title': 'Estimate',
              'entity_type': 'estimate_item',
              'entity_id': 'item-3',
              'project_id': '550e8400-e29b-41d4-a716-446655440000',
              'excerpt': 'Риски по срокам графика',
              'navigation': {'url': 'https://most.example.test/estimates/3'},
            },
          ],
          'entity_references': [
            {'id': 3, 'type': 'estimate', 'label': 'Estimate 3'},
          ],
        },
      });
      expect(message.id, 12);
      expect(message.validationStatus, 'partial');
      expect(
        message.evidence.single.url,
        'https://most.example.test/estimates/3',
      );
      expect(
        message.evidence.single.projectId,
        '550e8400-e29b-41d4-a716-446655440000',
      );
      expect(message.evidence.single.entityId, 'item-3');
      expect(message.evidence.single.excerpt, 'Риски по срокам графика');
      expect(message.selectedEntities.single.id, '3');
      expect(
        AiCreditsBalanceModel.fromJson({
          'included_minor': 500000,
          'purchased_minor': 75,
          'reserved_minor': 25,
          'available_minor': 500050,
        }).available,
        '5000.50',
      );
    },
  );
}
