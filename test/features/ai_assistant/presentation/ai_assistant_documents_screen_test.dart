import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_document_models.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:prohelpers_mobile/features/ai_assistant/presentation/ai_assistant_documents_screen.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';

void main() {
  test('OCR limit preserves minor precision and backend maximum', () {
    expect(parseAiDocumentLimit('25,50'), 2550);
    expect(parseAiDocumentLimit('0.01'), 1);
    expect(parseAiDocumentLimit('10000000'), 1000000000);
    expect(parseAiDocumentLimit('10000000.01'), isNull);
    expect(parseAiDocumentLimit('-1'), isNull);
    expect(parseAiDocumentLimit('1.234'), isNull);
  });
  testWidgets(
    'participant sees coverage without owner controls or settings call',
    (tester) async {
      final repository = _Repository(false);
      await tester.pumpWidget(_screen(repository));
      await tester.pumpAndSettle();
      expect(find.text('Требуют распознавания'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Архив: проверено 8 из 12 файлов'),
        400,
      );
      expect(find.text('Архив: проверено 8 из 12 файлов'), findsOneWidget);
      expect(find.text('Сохранить лимит'), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(repository.settingsCalls, 0);
    },
  );
  testWidgets('owner explicitly confirms OCR budget before saving', (
    tester,
  ) async {
    final repository = _Repository(true);
    await tester.pumpWidget(_screen(repository));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(TextField), 400);
    await tester.enterText(find.byType(TextField), '25,50');
    await tester.ensureVisible(find.text('Сохранить лимит'));
    await tester.tap(find.text('Сохранить лимит'));
    await tester.pumpAndSettle();
    expect(repository.savedLimit, isNull);
    expect(find.text('Подтвердить распознавание?'), findsOneWidget);
    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();
    expect(repository.savedLimit, 2550);
    expect(repository.savedScope, 'archive');
    expect(repository.settingsCalls, 2);
  });

  testWidgets('processing status loads once and refreshes only on request', (
    tester,
  ) async {
    final repository = _Repository(false, processing: true);
    await tester.pumpWidget(_screen(repository));
    await tester.pumpAndSettle();
    expect(repository.statusCalls, 1);
    await tester.pump(const Duration(seconds: 12));
    expect(repository.statusCalls, 1);
    await tester.tap(find.byTooltip('Обновить'));
    await tester.pumpAndSettle();
    expect(repository.statusCalls, 2);
  });

  testWidgets('unknown status retries until ready and then stops', (
    tester,
  ) async {
    final repository = _Repository(false, statusSequence: const [false, true]);
    await tester.pumpWidget(_screen(repository));
    await tester.pumpAndSettle();
    expect(repository.statusCalls, 1);
    expect(find.text('Получаем актуальную статистику…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(repository.statusCalls, 2);
    expect(find.textContaining('Документы: готовы 2 из 4'), findsOneWidget);
    await tester.pump(const Duration(seconds: 90));
    expect(repository.statusCalls, 2);
  });

  testWidgets('terminal status error stops retries', (tester) async {
    final repository = _Repository(
      false,
      statusSequence: const [false],
      statusErrorCall: 2,
      statusError: const ApiException('Forbidden', statusCode: 403),
    );
    await tester.pumpWidget(_screen(repository));
    await tester.pumpAndSettle();
    expect(repository.statusCalls, 1);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(repository.statusCalls, 2);
    expect(find.text('Forbidden'), findsOneWidget);
    await tester.pump(const Duration(seconds: 90));
    expect(repository.statusCalls, 2);
  });

  testWidgets('unmount cancels the pending unknown-status retry', (
    tester,
  ) async {
    final repository = _Repository(false, statusSequence: const [false]);
    await tester.pumpWidget(_screen(repository));
    await tester.pumpAndSettle();
    expect(repository.statusCalls, 1);
    final token = repository.statusTokens.single;
    await tester.pumpWidget(const SizedBox.shrink());
    expect(token.isCancelled, isTrue);
    await tester.pump(const Duration(seconds: 90));
    expect(repository.statusCalls, 1);
  });

  testWidgets('old load completion does not cancel the new retry window', (
    tester,
  ) async {
    final deferredStatus = Completer<AiDocumentProcessingStatus>();
    final repository = _Repository(
      false,
      statusSequence: const [false, false, true],
      deferredStatus: deferredStatus,
    );
    await tester.pumpWidget(_screen(repository));
    await tester.pump();
    final oldToken = repository.statusTokens.single;
    await tester.tap(find.byTooltip('Обновить'));
    await tester.pumpAndSettle();
    expect(repository.statusCalls, 2);
    expect(oldToken.isCancelled, isTrue);

    deferredStatus.complete(
      AiDocumentProcessingStatus.fromJson({'status_available': false}),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 91));
    final callsAtDeadline = repository.statusCalls;
    await tester.pump(const Duration(seconds: 10));

    expect(repository.statusCalls, callsAtDeadline);
  });

  testWidgets('old organization status cannot populate after scope switch', (
    tester,
  ) async {
    final deferredStatus = Completer<AiDocumentProcessingStatus>();
    final repository = _Repository(false, deferredStatus: deferredStatus);
    final auth = _OrganizationAuthNotifier(4);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => auth),
          aiAssistantRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: AiAssistantDocumentsScreen()),
      ),
    );
    await tester.pump();
    final token = repository.statusTokens.single;
    auth.setOrganization(5);
    await tester.pump();
    expect(token.isCancelled, isTrue);
    deferredStatus.complete(
      AiDocumentProcessingStatus.fromJson({
        'status_available': true,
        'document_coverage': {'total': 9, 'ready': 9},
      }),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Документы: готовы 9 из 9'), findsNothing);
    expect(repository.statusCalls, 1);
  });

  testWidgets('unavailable status hides counts and does not load settings', (
    tester,
  ) async {
    final repository = _Repository(true, statusAvailable: false);
    await tester.pumpWidget(_screen(repository));
    await tester.pumpAndSettle();

    expect(find.text('Получаем актуальную статистику…'), findsOneWidget);
    expect(find.textContaining('Документы: готовы'), findsNothing);
    expect(find.text('Всего документов'), findsNothing);
    expect(find.textContaining('Архив: проверено'), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(repository.settingsCalls, 0);
  });
}

Widget _screen(_Repository repository) => ProviderScope(
  overrides: [aiAssistantRepositoryProvider.overrideWithValue(repository)],
  child: const MaterialApp(home: AiAssistantDocumentsScreen()),
);

class _Repository extends AiAssistantRepository {
  _Repository(
    this.owner, {
    this.processing = false,
    this.statusAvailable = true,
    this.statusSequence = const [],
    this.statusErrorCall,
    this.statusError,
    this.deferredStatus,
  }) : super(Dio());
  final bool owner;
  final bool processing;
  final bool statusAvailable;
  final List<bool> statusSequence;
  final int? statusErrorCall;
  final Object? statusError;
  final Completer<AiDocumentProcessingStatus>? deferredStatus;
  int statusCalls = 0;
  final statusTokens = <CancelToken>[];
  int settingsCalls = 0;
  int? savedLimit;
  String? savedScope;
  @override
  Future<AiDocumentProcessingStatus> fetchDocumentProcessing({
    CancelToken? cancelToken,
  }) async {
    statusCalls++;
    if (cancelToken != null) statusTokens.add(cancelToken);
    if (statusErrorCall == statusCalls) throw statusError!;
    if (statusCalls == 1 && deferredStatus != null) {
      return deferredStatus!.future;
    }
    final available =
        statusCalls <= statusSequence.length
            ? statusSequence[statusCalls - 1]
            : statusAvailable;
    return AiDocumentProcessingStatus.fromJson({
      'status_available': available,
      'can_manage_document_settings': owner,
      'processing': processing,
      'document_coverage': {
        'total': 4,
        'ready': 2,
        'ocr_required': 1,
        'pending': processing ? 1 : 0,
      },
      'archive_scan': {
        'expected_file_count': 12,
        'scanned_file_count': 8,
        'processing': processing,
      },
    });
  }

  @override
  Future<AiDocumentBudget> fetchDocumentBudget() async {
    settingsCalls++;
    return const AiDocumentBudget(
      enabled: true,
      scope: 'archive',
      limitMinor: 1000,
      spentMinor: 0,
      reservedMinor: 0,
      availableMinor: 1000,
    );
  }

  @override
  Future<AiDocumentBudget> approveDocumentBudget({
    required bool enabled,
    required String scope,
    required int limitMinor,
  }) async {
    savedLimit = limitMinor;
    savedScope = scope;
    return AiDocumentBudget(
      enabled: enabled,
      scope: scope,
      limitMinor: limitMinor,
      spentMinor: 0,
      reservedMinor: 0,
      availableMinor: limitMinor,
    );
  }
}

class _TestSecureStorage extends SecureStorageService {
  @override
  Future<String?> getToken() async => null;
}

class _OrganizationAuthNotifier extends AuthNotifier {
  _OrganizationAuthNotifier(int organizationId)
    : super(
        AuthRepository(Dio(), _TestSecureStorage()),
        _TestSecureStorage(),
        autoCheckAuth: false,
      ) {
    state = AuthAuthenticated(_user(organizationId));
  }

  static User _user(int organizationId) =>
      User()
        ..serverId = 7
        ..email = 'test@example.test'
        ..name = 'Test'
        ..organizationsJson = '[]'
        ..roles = const []
        ..permissionsJson = '{}'
        ..currentOrganizationId = organizationId;

  void setOrganization(int organizationId) {
    state = AuthAuthenticated(_user(organizationId));
  }

  @override
  Future<void> checkAuth() async {}
}
