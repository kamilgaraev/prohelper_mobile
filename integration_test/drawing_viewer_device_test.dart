import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_session_identity.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/design_management/data/bim_models.dart';
import 'package:prohelpers_mobile/features/design_management/data/bim_repository.dart';
import 'package:prohelpers_mobile/features/design_management/data/design_package_model.dart';
import 'package:prohelpers_mobile/features/design_management/presentation/drawing_layer.dart';
import 'package:prohelpers_mobile/features/design_management/presentation/drawing_viewer_screen.dart';

const session = AuthSessionIdentity(
  userId: 7,
  organizationId: 9,
  sessionId: 'drawing-device-qa',
);

class DeviceAuth extends AuthNotifier {
  DeviceAuth()
    : super(
        AuthRepository(Dio(), SecureStorageService()),
        SecureStorageService(),
        autoCheckAuth: false,
      ) {
    state = AuthAuthenticated(
      User()
        ..serverId = 7
        ..name = 'Проверка',
      sessionIdentity: session,
    );
  }
}

class DeviceProjects extends ProjectsNotifier {
  DeviceProjects() : super(ProjectsRepository(Dio())) {
    final project =
        Project()
          ..serverId = 9
          ..name = 'Проверка чертежей';
    state = ProjectsState(
      isLoading: false,
      projects: [project],
      selectedProject: project,
    );
  }
}

class DeviceIssues extends BimRepository {
  DeviceIssues() : super(Dio());
  final saved = <BimIssue>[];
  @override
  Future<BimPage<BimIssue>> issues(
    int projectId, {
    int page = 1,
    String? status,
    int? versionId,
  }) async => BimPage(items: saved, page: 1, lastPage: 1, total: saved.length);
  @override
  Future<BimIssue> createIssue(
    int projectId,
    BimJson payload, {
    String? idempotencyKey,
  }) async {
    final issue = BimIssue(
      id: saved.length + 1,
      projectId: projectId,
      revision: 1,
      title: payload['title'],
      status: 'open',
      context: {
        'version_id': payload['version_id'],
        'annotations': payload['annotations'],
      },
    );
    saved.add(issue);
    return issue;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('opens native PDF, draws and saves on the selected page', (
    tester,
  ) async {
    final repository = DeviceIssues();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => DeviceAuth()),
          projectsProvider.overrideWith((ref) => DeviceProjects()),
          bimRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: DrawingViewerScreen(
            path: '/data/local/tmp/most-pir-drawing-20261013.pdf',
            file: DesignPackageFile(
              id: 15,
              name: 'АР - проверка.pdf',
              mimeType: 'application/pdf',
              canAnnotate: true,
              versionNumber: '2',
            ),
            projectId: 9,
            packageId: 42,
            sessionIdentity: session,
          ),
        ),
      ),
    );
    for (var attempt = 0; attempt < 60; attempt++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.text('Лист 1 / 3').evaluate().isNotEmpty) break;
    }
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('mobile-drawing-open');
    expect(
      find.text('Лист 1 / 3'),
      findsOneWidget,
      reason: find
          .byType(Text)
          .evaluate()
          .map((node) => (node.widget as Text).data)
          .join(' | '),
    );
    expect(find.textContaining('Не удалось прочитать PDF'), findsNothing);
    await tester.tap(find.byTooltip('Стрелка'));
    await tester.pump();
    final layer = find.byType(DrawingLayer).first;
    final rect = tester.getRect(layer);
    await tester.dragFrom(
      rect.topLeft + Offset(rect.width * 0.2, rect.height * 0.4),
      Offset(rect.width * 0.3, -rect.height * 0.1),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Замечание'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Проверить проём');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
    expect(repository.saved, hasLength(1));
    final annotations = repository.saved.single.context['annotations'] as Map;
    expect(annotations['page_number'], 1);
    expect(annotations['strokes'], hasLength(1));
    await binding.takeScreenshot('mobile-drawing-saved');
    await tester.tap(find.byTooltip('Следующий лист'));
    await tester.pumpAndSettle();
    expect(find.text('Лист 2 / 3'), findsOneWidget);
    await binding.takeScreenshot('mobile-drawing-rotated');
  });
}
