import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/workforce/data/month_timekeeping_model.dart';
import 'package:prohelpers_mobile/features/workforce/data/month_timekeeping_repository.dart';
import 'package:prohelpers_mobile/features/workforce/domain/month_timekeeping_provider.dart';

import '../timekeeping_fixture.dart';

class _Repository extends MonthTimekeepingRepository {
  _Repository() : super(Dio());
  final loads = <Completer<TimekeepingPage>>[];
  final scopes = <int?>[];
  final revisions = <int>[];
  final detailLoads = <Completer<TimekeepingPeriod>>[];
  bool delayDetails = false;
  Completer<TimekeepingPeriod>? pending;
  @override
  Future<TimekeepingPage> periods(
    String month, {
    int? projectId,
    int page = 1,
  }) {
    scopes.add(projectId);
    final completer = Completer<TimekeepingPage>();
    loads.add(completer);
    return completer.future;
  }

  @override
  Future<TimekeepingPeriod> period(int id) async {
    if (delayDetails) {
      final completer = Completer<TimekeepingPeriod>();
      detailLoads.add(completer);
      return completer.future;
    }
    return TimekeepingPeriod.fromJson(timekeepingFixture());
  }

  @override
  Future<TimekeepingPeriod> saveCell(
    TimekeepingPeriod period,
    Map<String, dynamic> data,
  ) {
    revisions.add(period.revision);
    return pending!.future;
  }
}

void main() {
  test('ignores stale detail responses after a newer reload', () async {
    final repository = _Repository()..delayDetails = true;
    final notifier = TimekeepingDetailNotifier(repository, 7);
    final newer = notifier.load();
    repository.detailLoads[1].complete(
      TimekeepingPeriod.fromJson(timekeepingFixture(revision: 3)),
    );
    await newer;
    repository.detailLoads[0].complete(
      TimekeepingPeriod.fromJson(timekeepingFixture(revision: 1)),
    );
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.requireValue.revision, 3);
    notifier.dispose();
  });

  test('ignores pending detail loads after a mutation begins', () async {
    final repository = _Repository()..delayDetails = true;
    final notifier = TimekeepingDetailNotifier(repository, 7);
    final newer = notifier.load();
    repository.detailLoads[1].complete(
      TimekeepingPeriod.fromJson(timekeepingFixture(revision: 3)),
    );
    await newer;
    repository.pending = Completer<TimekeepingPeriod>();
    final saving = notifier.saveCell({});
    repository.detailLoads[0].complete(
      TimekeepingPeriod.fromJson(timekeepingFixture(revision: 1)),
    );
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.isLoading, true);
    repository.pending!.complete(
      TimekeepingPeriod.fromJson(timekeepingFixture(revision: 4)),
    );
    await saving;
    expect(notifier.state.requireValue.revision, 4);
    notifier.dispose();
  });

  test(
    'ignores stale month requests and clears project scope explicitly',
    () async {
      final repository = _Repository();
      final notifier = MonthTimekeepingNotifier(repository);
      final newer = notifier.load(
        selectedMonth: DateTime(2026, 9),
        selectedProjectId: 3,
        changeScope: true,
      );
      repository.loads[1].complete(const TimekeepingPage([], 2, 4));
      await newer;
      repository.loads[0].complete(const TimekeepingPage([], 1, 1));
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.requireValue.page, 2);
      final organization = notifier.load(changeScope: true);
      expect(repository.scopes, [null, 3, null]);
      repository.loads.last.complete(const TimekeepingPage([], 1, 1));
      await organization;
      notifier.dispose();
    },
  );

  test(
    'blocks duplicate mutations, keeps data on conflict, and uses the new revision on retry',
    () async {
      final repository = _Repository();
      final notifier = TimekeepingDetailNotifier(repository, 7);
      await Future<void>.delayed(Duration.zero);
      repository.pending = Completer<TimekeepingPeriod>();
      final saving = notifier.saveCell({});
      expect(notifier.state.isLoading, true);
      await expectLater(notifier.saveCell({}), throwsStateError);
      final failure = expectLater(saving, throwsA(isA<ApiException>()));
      repository.pending!.completeError(
        const ApiException('Обновите табель.', statusCode: 422),
      );
      await failure;
      expect(notifier.state.requireValue.revision, 1);
      repository.pending = Completer<TimekeepingPeriod>();
      final retry = notifier.saveCell({});
      repository.pending!.complete(
        TimekeepingPeriod.fromJson(timekeepingFixture(revision: 2)),
      );
      await retry;
      repository.pending = Completer<TimekeepingPeriod>();
      final next = notifier.saveCell({});
      expect(repository.revisions, [1, 1, 2]);
      repository.pending!.complete(
        TimekeepingPeriod.fromJson(timekeepingFixture(revision: 3)),
      );
      await next;
      notifier.dispose();
    },
  );
}
