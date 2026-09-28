import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_request_detail_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_scope.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_request_detail_screen.dart';

void main() {
  testWidgets(
    'сохраняет комментарий после ошибки и закрывает диалог после повтора',
    (tester) async {
      tester.view.physicalSize = const Size(240, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final firstAttempt = Completer<Map<String, dynamic>>();
      final secondAttempt = Completer<Map<String, dynamic>>();
      final repository = _FakeSiteRequestsRepository(
        _siteRequest(),
        responses: [firstAttempt.future, secondAttempt.future],
      );
      await tester.pumpWidget(_app(repository, textScale: 1.3));
      await tester.pumpAndSettle();

      await _openCancelDialog(tester);
      const longComment =
          'Заявка больше не нужна, потому что поставка уже согласована по другой заявке, '
          'а материалы привезены на объект и приняты ответственным сотрудником.';
      await tester.enterText(find.byType(TextField).last, longComment);
      final confirm = find.widgetWithText(TextButton, 'Отменить заявку');

      await tester.tap(confirm);
      await tester.pump();
      expect(repository.statusChanges, hasLength(1));

      firstAttempt.completeError(
        const ApiException('Укажите причину отмены', statusCode: 422),
      );
      await tester.pumpAndSettle();

      expect(find.text('Укажите причину отмены'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        longComment,
      );
      expect(repository.statusChanges.single.notes, longComment);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      expect(repository.statusChanges, hasLength(2));
      expect(repository.statusChanges.last.notes, longComment);

      secondAttempt.complete(_statusResponse('cancelled'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'блокирует двойное подтверждение и безопасно переживает закрытие во время запроса',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      final repository = _FakeSiteRequestsRepository(
        _siteRequest(),
        responses: [pending.future],
      );
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      await _openCancelDialog(tester);
      await tester.enterText(find.byType(TextField).last, 'Причина');
      final confirm = find.widgetWithText(TextButton, 'Отменить заявку');
      final confirmPosition = tester.getCenter(confirm);
      await tester.tapAt(confirmPosition);
      await tester.tapAt(confirmPosition);
      await tester.pump();

      expect(repository.statusChanges, hasLength(1));
      expect(find.text('Сохраняем...'), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsNothing);

      pending.complete(_statusResponse('cancelled'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.statusChanges.single.notes, 'Причина');
    },
  );
}

Future<void> _openCancelDialog(WidgetTester tester) async {
  await tester.tap(find.text('Отменить заявку'));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
}

Widget _app(_FakeSiteRequestsRepository repository, {double textScale = 1}) {
  return ProviderScope(
    overrides: [
      siteRequestsRepositoryProvider.overrideWithValue(repository),
      siteRequestDetailProvider.overrideWith(
        (ref, id) => SiteRequestDetailNotifier(repository, ref, id),
      ),
      siteRequestsProvider.overrideWith(
        (ref) => SiteRequestsNotifier(
          repository,
          initialProjectId: 15,
          initialScope: SiteRequestsScope.own,
        ),
      ),
    ],
    child: MaterialApp(
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
      home: const SiteRequestDetailScreen(id: 1001),
    ),
  );
}

SiteRequestModel _siteRequest() =>
    SiteRequestModel()
      ..serverId = 1001
      ..title = 'Тестовая заявка'
      ..description = 'Описание заявки'
      ..status = 'pending'
      ..statusLabel = 'На согласовании'
      ..priority = 'medium'
      ..priorityLabel = 'Средняя'
      ..requestType = 'material_request'
      ..requestTypeLabel = 'Материалы'
      ..projectId = 15
      ..projectName = 'Объект'
      ..availableTransitions = const [
        SiteRequestTransition(status: 'cancelled'),
      ];

Map<String, dynamic> _statusResponse(String status) => {
  'id': 1001,
  'title': 'Тестовая заявка',
  'description': 'Описание заявки',
  'status': status,
  'status_label': 'Отменена',
  'priority': 'medium',
  'priority_label': 'Средняя',
  'request_type': 'material_request',
  'request_type_label': 'Материалы',
  'project_id': 15,
  'project': {'name': 'Объект'},
  'available_transitions': [],
  'history': [],
};

class _FakeSiteRequestsRepository extends SiteRequestsRepository {
  _FakeSiteRequestsRepository(this.request, {required this.responses})
    : super(Dio());

  final SiteRequestModel request;
  final List<Future<Map<String, dynamic>>> responses;
  final statusChanges = <({String status, String? notes})>[];

  @override
  Future<SiteRequestModel> fetchSiteRequestDetails(int id) async => request;

  @override
  Future<List<Map<String, dynamic>>> fetchFiles(int requestId) async =>
      const [];

  @override
  Future<List<SiteRequestModel>> fetchSiteRequests({
    int page = 1,
    int perPage = 20,
    String? status,
    int? projectId,
    String? search,
    bool urgentOnly = false,
    int? assignedUserId,
    String? requestType,
    DateTime? requiredFrom,
    DateTime? requiredTo,
    SiteRequestsScope scope = SiteRequestsScope.own,
  }) async => const [];

  @override
  Future<Map<String, dynamic>> changeSiteRequestStatusPayload(
    int id,
    String status, {
    String? notes,
  }) {
    statusChanges.add((status: status, notes: notes));
    return responses[statusChanges.length - 1];
  }
}
