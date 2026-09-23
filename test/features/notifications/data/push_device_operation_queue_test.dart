import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/notifications/data/push_device_operation_queue.dart';

void main() {
  test('serializes registration before logout cleanup', () async {
    final queue = PushDeviceOperationQueue()..setAuthenticated(true);
    final started = Completer<void>();
    final finishRegistration = Completer<void>();
    final events = <String>[];
    final generation = queue.generation;

    final registration = queue.enqueue(() async {
      if (!queue.isCurrent(generation)) return;
      events.add('register-started');
      started.complete();
      await finishRegistration.future;
      events.add('registered');
    });
    await started.future;

    final logoutGeneration = queue.setAuthenticated(false);
    final cleanup = queue.enqueue(() async {
      if (!queue.isGenerationCurrent(logoutGeneration)) return;
      events.add('deleted');
    });
    finishRegistration.complete();
    await Future.wait([registration, cleanup]);

    expect(events, ['register-started', 'registered', 'deleted']);
  });

  test('skips a queued registration after logout begins', () async {
    final queue = PushDeviceOperationQueue()..setAuthenticated(true);
    final staleGeneration = queue.generation;
    queue.setAuthenticated(false);
    var registered = false;

    await queue.enqueue(() async {
      if (queue.isCurrent(staleGeneration)) registered = true;
    });

    expect(registered, isFalse);
  });
}
