import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';
import 'package:prohelpers_mobile/features/workforce/data/employee_workspace_model.dart';
import 'package:prohelpers_mobile/features/workforce/data/employee_workspace_repository.dart';
import 'package:prohelpers_mobile/features/workforce/presentation/employee_workspace_screen.dart';

const _workspace = EmployeeWorkspaceModel(
  employeeName: 'Иван Петров',
  personnelNumber: '001',
  documents: [],
  requests: [],
  periods: [],
);

class _Repository extends EmployeeWorkspaceRepository {
  _Repository(this.result) : super(Dio());
  final Future<EmployeeWorkspaceModel> result;
  final requestPages = <int>[];
  @override
  Future<EmployeeWorkspaceModel> fetch(String month, {String? workDate}) =>
      result;
  @override
  Future<EmployeeRequestPageModel> fetchRequests({int page = 1}) async {
    requestPages.add(page);
    return EmployeeRequestPageModel(
      requests: [_request(page)],
      currentPage: page,
      lastPage: 2,
      total: 51,
    );
  }
}

Widget _app(_Repository repository, {bool canRequest = false}) => ProviderScope(
  overrides: [
    employeeWorkspaceRepositoryProvider.overrideWithValue(repository),
    permissionServiceProvider.overrideWithValue(
      PermissionService(
        context: UserContext.field,
        activeModules: {AppModule.workforceManagement},
        grantedPermissions: {
          'workforce.self-service.view',
          if (canRequest) 'workforce.self-service.request',
        },
      ),
    ),
  ],
  child: const MaterialApp(home: EmployeeWorkspaceScreen()),
);

EmployeeRequestModel _request(int id) => EmployeeRequestModel(
  id: id,
  kind: 'absence',
  status: 'rejected',
  dateFrom: '2026-10-15',
  dateTo: '2026-10-16',
  basis: id == 1 ? 'Первая заявка' : 'Заявка на второй странице',
);

void main() {
  testWidgets('opens a paginated archive and loads older requests', (
    tester,
  ) async {
    final repository = _Repository(
      Future.value(
        EmployeeWorkspaceModel(
          employeeName: 'Иван Петров',
          personnelNumber: '001',
          documents: [],
          requests: [_request(1)],
          periods: [],
        ),
      ),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Все заявки'));
    await tester.pumpAndSettle();
    expect(find.text('История моих заявок'), findsOneWidget);
    expect(repository.requestPages, [1]);
    await tester.tap(find.byTooltip('Следующая страница'));
    await tester.pumpAndSettle();
    expect(repository.requestPages, [1, 2]);
    expect(find.textContaining('Заявка на второй странице'), findsOneWidget);
    expect(find.text('Страница 2 из 2. Всего: 51'), findsOneWidget);
  });

  testWidgets('shows loading, own employee and explicit empty states', (
    tester,
  ) async {
    final completer = Completer<EmployeeWorkspaceModel>();
    await tester.pumpWidget(_app(_Repository(completer.future)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(_workspace);
    await tester.pumpAndSettle();
    expect(find.text('Иван Петров'), findsOneWidget);
    expect(find.text('Документов пока нет'), findsOneWidget);
    expect(find.text('Заявок пока нет'), findsOneWidget);
    expect(find.text('Подать заявку'), findsNothing);
  });

  testWidgets('shows a safe retry when employee binding is unavailable', (
    tester,
  ) async {
    final completer = Completer<EmployeeWorkspaceModel>();
    await tester.pumpWidget(_app(_Repository(completer.future)));
    completer.completeError(StateError('internal_storage_credentials'));
    await tester.pumpAndSettle();
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.textContaining('internal_storage_credentials'), findsNothing);
  });

  testWidgets('request action requires a separate permission', (tester) async {
    await tester.pumpWidget(
      _app(_Repository(Future.value(_workspace)), canRequest: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Подать заявку'), findsOneWidget);
    await tester.tap(find.text('Подать заявку'));
    await tester.pumpAndSettle();
    expect(find.text('Заявка сотрудника'), findsOneWidget);
    expect(
      find.textContaining('Заявка не заменяет кадровый документ'),
      findsOneWidget,
    );
  });
}
