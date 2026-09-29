import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/assistant_source_navigation.dart';

void main() {
  const baseUrl = 'https://lk.example.test';

  test('maps canonical module links to native registry keys', () {
    expect(
      resolveAssistantSourceTarget('/integrations/1c', sourceBaseUrl: baseUrl),
      isA<AssistantSourceTarget>()
          .having((target) => target.mobileRoute, 'mobile route', 'one-c-basic-exchange')
          .having((target) => target.label, 'label', 'Открыть раздел'),
    );
    expect(
      resolveAssistantSourceTarget('/materials', sourceBaseUrl: baseUrl)?.mobileRoute,
      'catalog-management',
    );
    expect(
      resolveAssistantSourceTarget('/brigades/assignments', sourceBaseUrl: baseUrl)?.mobileRoute,
      'brigades',
    );
  });

  test('preserves project IDs and falls back to the real cabinet project route', () {
    const projectId = '550e8400-e29b-41d4-a716-446655440000';
    final video = resolveAssistantSourceTarget(
      '/projects/$projectId/video-monitoring?entity_id=7',
      sourceBaseUrl: baseUrl,
    );
    final project = resolveAssistantSourceTarget(
      null,
      sourceBaseUrl: baseUrl,
      projectId: projectId,
    );

    expect(video?.mobileRoute, 'video-monitoring');
    expect(video?.projectId, projectId);
    expect(project?.webPath, '/dashboard/projects/$projectId');
    expect(project?.label, 'Открыть проект');
  });

  test('rejects external, protocol-relative, malformed project, and unknown targets', () {
    expect(
      resolveAssistantSourceTarget('https://evil.example/tenders', sourceBaseUrl: baseUrl),
      isNull,
    );
    expect(
      resolveAssistantSourceTarget('//evil.example/tenders', sourceBaseUrl: baseUrl),
      isNull,
    );
    expect(
      resolveAssistantSourceTarget('/projects/../admin', sourceBaseUrl: baseUrl),
      isNull,
    );
    expect(
      resolveAssistantSourceTarget('/unknown/module', sourceBaseUrl: baseUrl),
      isNull,
    );
  });
}
