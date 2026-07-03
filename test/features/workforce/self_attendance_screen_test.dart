import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/localization/most_localizations.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/workforce/data/workforce_attendance_model.dart';
import 'package:prohelpers_mobile/features/workforce/data/workforce_repository.dart';
import 'package:prohelpers_mobile/features/workforce/presentation/self_attendance_screen.dart';

class _FakeWorkforceRepository extends WorkforceRepository {
  _FakeWorkforceRepository() : super(Dio());

  final List<DateTime> selfAttendanceDates = [];

  @override
  Future<AttendanceScanResultModel> recordSelfAttendance({
    int? projectId,
    required DateTime workDate,
    String? deviceId,
  }) async {
    selfAttendanceDates.add(workDate);

    return AttendanceScanResultModel(
      scanEventId: 91,
      employeeId: 41,
      employeeLabel: 'Иванов Иван',
      projectId: projectId,
      projectLabel: 'Объект Литейная',
      workDate: workDate,
      status: 'at_work',
      statusLabel: 'Явка сохранена.',
      source: 'self_attendance',
      sourceLabel: 'Самоотметка',
      confirmedAt: DateTime(2026, 5, 16, 9, 1),
    );
  }
}

class _FakeProjectsRepository extends ProjectsRepository {
  _FakeProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => [_project()];
}

class _TestProjectsNotifier extends ProjectsNotifier {
  _TestProjectsNotifier() : super(_FakeProjectsRepository()) {
    final project = _project();
    state = ProjectsState(
      hasLoaded: true,
      projects: [project],
      selectedProject: project,
    );
  }
}

void main() {
  testWidgets('самоотметка объясняет, почему сохранение недоступно без даты', (
    tester,
  ) async {
    final repository = _FakeWorkforceRepository();

    await _pumpSelfAttendance(tester, repository);

    expect(find.text('Выберите дату явки'), findsOneWidget);
    expect(
      find.text(
        'Сначала выберите дату явки. После этого кнопка сохранения станет активной.',
      ),
      findsOneWidget,
    );
    expect(find.text('Сначала выберите дату'), findsOneWidget);

    final submitButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Сначала выберите дату'),
    );
    expect(submitButton.onPressed, isNull);

    await tester.tap(find.text('Сначала выберите дату'));
    await tester.pumpAndSettle();

    expect(repository.selfAttendanceDates, isEmpty);
  });

  testWidgets('календарь самоотметки открывается на русском языке', (
    tester,
  ) async {
    final repository = _FakeWorkforceRepository();

    await _pumpSelfAttendance(tester, repository);

    await tester.tap(find.text('Выберите дату явки'));
    await tester.pumpAndSettle();

    expect(find.text('Select date'), findsNothing);
    expect(find.text('Выберите дату'), findsOneWidget);
    expect(find.text('ОК'), findsOneWidget);
  });
}

Future<void> _pumpSelfAttendance(
  WidgetTester tester,
  _FakeWorkforceRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workforceRepositoryProvider.overrideWithValue(repository),
        projectsProvider.overrideWith((ref) => _TestProjectsNotifier()),
      ],
      child: const MaterialApp(
        locale: MostLocalizations.ru,
        localizationsDelegates: MostLocalizations.delegates,
        supportedLocales: MostLocalizations.supportedLocales,
        home: SelfAttendanceScreen(),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Project _project() {
  return Project()
    ..serverId = 7
    ..name = 'Строительство склада Литер А'
    ..address = '420054, Казань'
    ..myRole = 'Прораб';
}
