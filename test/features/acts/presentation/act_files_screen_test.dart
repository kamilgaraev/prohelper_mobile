import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/acts/data/act_model.dart';
import 'package:prohelpers_mobile/features/acts/data/acts_repository.dart';
import 'package:prohelpers_mobile/features/acts/presentation/acts_screen.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/design_management/data/design_package_file_service.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import '../../../helpers/mobile_integration_test_helpers.dart';

void main() {
  testWidgets(
    'counterparty field capability shows verification without legal approval action',
    (tester) async {
      final repository = _Repository(canConfirm: true, canView: true);
      final files = _Files();
      await _pump(tester, repository, files: files);
      expect(find.text('КС-2.pdf'), findsOneWidget);
      expect(find.text('Зафиксировать проверку'), findsOneWidget);
      expect(find.text('Утвердить'), findsNothing);
      expect(find.text('На согласовании'), findsOneWidget);
      await tester.tap(find.text('КС-2.pdf'));
      await tester.pumpAndSettle();
      expect(repository.downloads, 1);
      expect(files.opened, 1);
      expect(repository.confirmations, 0);
      expect(find.text('На согласовании'), findsOneWidget);
      await tester.tap(find.text('Зафиксировать проверку'));
      await tester.pumpAndSettle();
      expect(find.text('Полевая проверка акта'), findsOneWidget);
    },
  );

  testWidgets('server capabilities deny viewing files and field confirmation', (
    tester,
  ) async {
    final repository = _Repository(canConfirm: false, canView: false);
    await _pump(tester, repository);
    expect(find.text('Зафиксировать проверку'), findsNothing);
    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'КС-2.pdf'),
    );
    expect(tile.onTap, isNull);
    expect(repository.downloads, 0);
  });

  testWidgets(
    'organization change during download discards the temporary file',
    (tester) async {
      final repository = _Repository(
        canConfirm: false,
        canView: true,
        pending: Completer<String>(),
      );
      final auth = _Auth();
      final files = _Files();
      await _pump(tester, repository, auth: auth, files: files);
      await tester.tap(find.text('КС-2.pdf'));
      await tester.pump();
      auth.changeOrganization(11);
      await tester.pump();
      repository.pending!.complete('/temporary/act.pdf');
      await tester.pumpAndSettle();
      expect(files.opened, 0);
      expect(files.deleted, ['/temporary/act.pdf']);
      expect(find.text('Объект или организация изменились'), findsOneWidget);
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  _Repository repository, {
  _Files? files,
  _Auth? auth,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        actsRepositoryProvider.overrideWithValue(repository),
        actFileServiceProvider.overrideWithValue(files ?? _Files()),
        authProvider.overrideWith((ref) => auth ?? _Auth()),
        projectsProvider.overrideWith((ref) => _Projects()),
      ],
      child: const MaterialApp(home: ActDetailScreen(id: 4)),
    ),
  );
  await tester.pumpAndSettle();
}

class _Projects extends ProjectsNotifier {
  _Projects() : super(ProjectsRepository(Dio())) {
    state = state.copyWith(
      selectedProject:
          Project()
            ..serverId = 9
            ..name = 'Объект'
            ..address = 'Площадка',
    );
  }
}

class _Auth extends TestAuthNotifier {
  _Auth()
    : super(
        user: MostTestData.user(),
        storage: MemorySecureStorageService(),
        authenticated: true,
      );
  void changeOrganization(int organizationId) {
    state = AuthAuthenticated(
      MostTestData.user()..currentOrganizationId = organizationId,
    );
  }
}

class _Repository extends ActsRepository {
  _Repository({required this.canConfirm, required this.canView, this.pending})
    : super(Dio());
  final bool canConfirm;
  final bool canView;
  final Completer<String>? pending;
  int downloads = 0;
  int confirmations = 0;
  @override
  Future<ActModel> detail(int id) async => ActModel.fromJson({
    'id': 4,
    'project_id': 9,
    'organization_id': 4,
    'status': 'pending_approval',
    'files': [
      {'id': 7, 'name': 'КС-2.pdf'},
    ],
    'capabilities': {
      'can_field_confirm': canConfirm,
      'can_view_files': canView,
    },
  });
  @override
  Future<String> downloadFile(int actId, ActFile file) async {
    expect(actId, 4);
    expect(file.id, 7);
    downloads++;
    return pending == null ? '/temporary/act.pdf' : pending!.future;
  }

  @override
  Future<Map<String, dynamic>> confirmField({
    required int id,
    required String signatureData,
    required String idempotencyKey,
  }) async {
    confirmations++;
    return {'act_id': id};
  }
}

class _Files extends DesignPackageFileService {
  int opened = 0;
  final deleted = <String>[];
  @override
  Future<bool> openLocalFile(String path) async {
    opened++;
    return true;
  }

  @override
  Future<void> deleteDownloaded(String path) async {
    deleted.add(path);
  }

  @override
  void scheduleCleanup(String path) {}
}
