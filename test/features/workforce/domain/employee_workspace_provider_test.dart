import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/workforce/data/employee_workspace_model.dart';
import 'package:prohelpers_mobile/features/workforce/data/employee_workspace_repository.dart';
import 'package:prohelpers_mobile/features/workforce/domain/employee_workspace_provider.dart';

EmployeeWorkspaceModel _model(String name) => EmployeeWorkspaceModel(
  employeeName: name,
  personnelNumber: '001',
  documents: [],
  requests: [],
  periods: [],
);

class _Repository extends EmployeeWorkspaceRepository {
  _Repository() : super(Dio());
  final calls = <Completer<EmployeeWorkspaceModel>>[];
  @override
  Future<EmployeeWorkspaceModel> fetch(String month, {String? workDate}) {
    final completer = Completer<EmployeeWorkspaceModel>();
    calls.add(completer);
    return completer.future;
  }
}

void main() {
  test(
    'a slow previous month cannot overwrite the newly selected month',
    () async {
      final repository = _Repository();
      final notifier = EmployeeWorkspaceNotifier(repository);
      final newest = notifier.load(selectedMonth: '2026-09');
      repository.calls[1].complete(_model('Сентябрь'));
      await newest;
      repository.calls[0].complete(_model('Старый месяц'));
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.asData!.value.employeeName, 'Сентябрь');
      expect(notifier.month, '2026-09');
      notifier.dispose();
    },
  );
}
