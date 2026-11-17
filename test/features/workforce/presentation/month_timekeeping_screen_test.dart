import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';
import 'package:prohelpers_mobile/features/workforce/data/month_timekeeping_model.dart';
import 'package:prohelpers_mobile/features/workforce/data/month_timekeeping_repository.dart';
import 'package:prohelpers_mobile/features/workforce/presentation/month_timekeeping_screen.dart';

import '../timekeeping_fixture.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

class _Repository extends MonthTimekeepingRepository {
  _Repository() : super(Dio());
  Completer<TimekeepingPeriod>? loading;
  Completer<TimekeepingPeriod>? saving;
  Object? failure;
  Map<String, dynamic>? saved;
  int calls = 0;
  int serverRevision = 1;
  final revisions = <int>[];
  bool initiallyClosed = false;
  bool reopened = false;
  int currentMinutes = 0;
  int listLoads = 0;
  int uploadCalls = 0;
  int actionCalls = 0;
  bool approval = false;
  bool noRows = false;
  Map<String, dynamic>? actionData;
  TimekeepingPeriod fixture(int id) {
    final json = timekeepingFixture(
      id: id,
      revision: serverRevision,
      minutes: currentMinutes,
      status:
          approval
              ? 'verified'
              : initiallyClosed && !reopened
              ? 'closed'
              : 'draft',
    );
    if (approval) {
      json['documents'] = [
        {
          'id': 54 + serverRevision,
          'revision': serverRevision,
          'filename': 'Табель.pdf',
          'format': 'pdf',
        },
      ];
    }
    if (noRows) json['rows'] = [];
    return TimekeepingPeriod.fromJson(json);
  }

  @override
  Future<TimekeepingPeriod> period(int id) =>
      loading?.future ?? Future.value(fixture(id));
  @override
  Future<TimekeepingPage> periods(
    String month, {
    int? projectId,
    int page = 1,
  }) async {
    listLoads++;
    return TimekeepingPage([fixture(reopened ? 8 : 7)], 1, 1);
  }

  @override
  Future<int> uploadSignedFile(
    TimekeepingPeriod period,
    int documentId,
    MultipartFile file,
  ) async {
    expect(period.revision, serverRevision);
    expect(documentId, 54 + serverRevision);
    uploadCalls++;
    return 99;
  }

  @override
  Future<TimekeepingPeriod> action(
    TimekeepingPeriod period,
    String action,
    Map<String, dynamic> data,
  ) async {
    actionCalls++;
    actionData = data;
    expect(period.revision, serverRevision);
    if (action == 'reopen') {
      reopened = true;
      serverRevision = 1;
      return fixture(8);
    }
    if (action == 'approve' && actionCalls == 1) {
      throw const ApiException('Попробуйте ещё раз.', statusCode: 503);
    }
    return TimekeepingPeriod.fromJson(timekeepingFixture(status: 'approved'));
  }

  @override
  Future<TimekeepingPeriod> saveCell(
    TimekeepingPeriod period,
    Map<String, dynamic> data,
  ) async {
    calls++;
    revisions.add(period.revision);
    saved = data;
    if (failure != null) throw failure!;
    currentMinutes = data['duration_minutes'] as int;
    serverRevision = period.revision + 1;
    return saving?.future ??
        TimekeepingPeriod.fromJson(
          timekeepingFixture(
            id: period.id,
            revision: serverRevision,
            minutes: data['duration_minutes'] as int,
          ),
        );
  }
}

Widget _app(
  _Repository repository, {
  bool manage = true,
  Widget home = const TimekeepingPeriodScreen(periodId: 7),
  double textScale = 1,
}) => ProviderScope(
  overrides: [
    monthTimekeepingRepositoryProvider.overrideWithValue(repository),
    projectsProvider.overrideWith(
      (ref) => ProjectsNotifier(ProjectsRepository(Dio())),
    ),
    permissionServiceProvider.overrideWithValue(
      PermissionService(
        context: UserContext.field,
        activeModules: {AppModule.workforceManagement},
        grantedPermissions: {
          'workforce.timekeeping.view',
          if (manage) 'workforce.timekeeping.manage',
          if (repository.approval) ...[
            'workforce.timekeeping.approve',
            'workforce.hr.private.read',
            'workforce.timekeeping.export',
          ],
        },
      ),
    ),
  ],
  child: MaterialApp(
    home: home,
    builder:
        (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
  ),
);

Future<void> _openDay(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Иван Петров'),
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Иван Петров'));
  await tester.pumpAndSettle();
  final dayY = tester.getCenter(find.text('02')).dy;
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  if (dayY > height - 80) {
    await tester.drag(
      find.byType(CustomScrollView).first,
      Offset(0, height / 2 - dayY),
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('02'));
  await tester.pumpAndSettle();
}

void main() {
  for (final noRows in [false, true]) {
    testWidgets(
      'documents remain available without matching employees (empty period: $noRows)',
      (tester) async {
        final repository =
            _Repository()
              ..approval = true
              ..noRows = noRows;
        await tester.pumpWidget(_app(repository));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Сотрудник или табельный номер'),
          'Нет совпадений',
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Документы табеля'),
          240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Документы табеля'));
        await tester.pumpAndSettle();
        expect(find.text('Табель.pdf'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'resets the selected approval document when reloading a new revision',
    (tester) async {
      final repository = _Repository()..approval = true;
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Утвердить табель'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Табель.pdf').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Подтвердить'));
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      repository.serverRevision = 2;
      await tester.ensureVisible(find.text('Загрузить новую версию'));
      await tester.tap(find.text('Загрузить новую версию'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Табель.pdf'), findsNothing);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Табель.pdf').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(
              find.byType(DropdownButtonFormField<int>),
            )
            .initialValue,
        56,
      );
    },
  );

  testWidgets(
    'month calendar stays usable with large text on a compact phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(_Repository(), textScale: 2));
      await tester.pumpAndSettle();
      await _openDay(tester);
      expect(find.text('Часы сотрудника'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'reopens into a new period, saves it, and reloads the list on final return',
    (tester) async {
      final repository = _Repository()..initiallyClosed = true;
      await tester.pumpWidget(
        _app(repository, home: const MonthTimekeepingScreen()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Табель №7'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Вернуть в работу'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Основание возврата в работу'),
        'Исправление часов',
      );
      await tester.ensureVisible(find.text('Подтвердить'));
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      expect(repository.listLoads, 1);
      await _openDay(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Часы за день'),
        '7,5',
      );
      await tester.ensureVisible(find.text('Сохранить часы'));
      await tester.tap(find.text('Сохранить часы'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(repository.listLoads, 2);
      expect(find.textContaining('Табель №8'), findsOneWidget);
      expect(find.textContaining('Часов: 7,5'), findsOneWidget);
    },
  );

  testWidgets(
    'approval retries without reuploading the signed file and keeps document revision',
    (tester) async {
      const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => [
              {
                'name': 'signed.pdf',
                'size': 4,
                'path': null,
                'bytes': Uint8List.fromList([37, 80, 68, 70]),
              },
            ],
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final repository = _Repository()..approval = true;
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Утвердить табель'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Табель.pdf').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Подписант'),
        'Иван Петров',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Где хранится бумажный оригинал'),
        'Кадровый архив',
      );
      await tester.ensureVisible(find.text('Выбрать подписанный скан'));
      await tester.tap(find.text('Выбрать подписанный скан'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Подтвердить'));
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      expect(repository.uploadCalls, 1);
      expect(find.text('Попробуйте ещё раз.'), findsOneWidget);
      await tester.ensureVisible(find.text('Подтвердить'));
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      expect(repository.uploadCalls, 1);
      expect(repository.actionCalls, 2);
      expect(repository.actionData!['document_id'], 55);
      expect(repository.actionData!['document_revision'], 1);
      expect(repository.actionData!['signed_file_id'], 99);
      expect(find.text('Подтвердить'), findsNothing);
    },
  );
  testWidgets(
    'loads the month, edits decimal hours, blocks duplicate saving, and shows updated fact',
    (tester) async {
      final repository =
          _Repository()..loading = Completer<TimekeepingPeriod>();
      await tester.pumpWidget(_app(repository));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repository.loading!.complete(
        TimekeepingPeriod.fromJson(timekeepingFixture()),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Вся организация'), findsOneWidget);
      await _openDay(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Часы за день'),
        '7,5',
      );
      repository.saving = Completer<TimekeepingPeriod>();
      await tester.ensureVisible(find.text('Сохранить часы'));
      await tester.tap(find.text('Сохранить часы'));
      await tester.pump();
      expect(repository.saved!['duration_minutes'], 450);
      expect(repository.saved!['intervals'], isEmpty);
      expect(repository.calls, 1);
      expect(find.text('Сохранение…'), findsOneWidget);
      repository.saving!.complete(
        TimekeepingPeriod.fromJson(
          timekeepingFixture(revision: 2, minutes: 450),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Часы сотрудника'), findsNothing);
      expect(find.textContaining('Часов: 7,5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'retains entered hours after a revision conflict and allows correcting the input',
    (tester) async {
      final repository =
          _Repository()
            ..failure = const ApiException(
              'Табель изменён. Обновите данные.',
              statusCode: 422,
            );
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await _openDay(tester);
      final field = find.widgetWithText(TextField, 'Часы за день');
      await tester.enterText(field, '7,5');
      await tester.ensureVisible(find.text('Сохранить часы'));
      await tester.tap(find.text('Сохранить часы'));
      await tester.pumpAndSettle();
      expect(find.text('Табель изменён. Обновите данные.'), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, '7,5');
      expect(repository.calls, 1);
      repository.serverRevision = 2;
      repository.failure = null;
      await tester.ensureVisible(find.text('Загрузить новую версию'));
      await tester.tap(find.text('Загрузить новую версию'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, '7,5');
      expect(find.textContaining('На сервере сейчас'), findsOneWidget);
      await tester.ensureVisible(find.text('Сохранить часы'));
      await tester.tap(find.text('Сохранить часы'));
      await tester.pumpAndSettle();
      expect(repository.revisions, [1, 2]);
      expect(find.text('Часы сотрудника'), findsNothing);
    },
  );

  testWidgets(
    'read-only users can see daily facts and search but cannot open an editor',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(_app(repository, manage: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Иван Петров'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('02'));
      await tester.tap(find.text('02'));
      await tester.pumpAndSettle();
      expect(find.text('Часы сотрудника'), findsNothing);
      expect(find.text('Обновить из источников'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Сотрудник или табельный номер'),
        'неизвестный',
      );
      await tester.pumpAndSettle();
      expect(find.text('Сотрудники не найдены.'), findsOneWidget);
      expect(repository.calls, 0);
    },
  );
}
