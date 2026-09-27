import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_draft.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/features/sync/domain/pending_sync_provider.dart';
import 'package:prohelpers_mobile/features/sync/presentation/pending_sync_screen.dart';

void main() {
  testWidgets('shows queued and uncertain operations with safe retry', (
    tester,
  ) async {
    final queued = _operation(
      moduleSlug: 'warehouse',
      operationType: 'create_receipt',
      status: SyncOperationStatuses.queued,
    );
    final uncertain = _operation(
      moduleSlug: 'site_requests',
      operationType: 'create_site_request',
      status: SyncOperationStatuses.conflict,
      error: SyncQueueMessages.unknownOutcome,
    );
    late _StubPendingSyncNotifier notifier;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pendingSyncProvider.overrideWith((ref) {
            notifier = _StubPendingSyncNotifier(ref, [queued, uncertain]);
            return notifier;
          }),
        ],
        child: MaterialApp(
          theme: MostTheme.lightTheme,
          home: const PendingSyncScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не отправлено'), findsOneWidget);
    expect(find.text('Приход на склад'), findsOneWidget);
    expect(find.text('Ждёт отправки'), findsOneWidget);
    expect(find.text('Заявка с объекта'), findsOneWidget);
    expect(find.text('Нужно проверить результат'), findsOneWidget);
    expect(find.text(SyncQueueMessages.unknownOutcome), findsOneWidget);
    expect(find.textContaining('Не отправляйте её повторно'), findsOneWidget);

    await tester.tap(find.byTooltip('Повторить отправку').first);
    await tester.pump();
    expect(notifier.retryCount, 1);
  });

  testWidgets('keeps operations visible when queue status refresh fails', (
    tester,
  ) async {
    final queued = _operation(
      moduleSlug: 'warehouse',
      operationType: 'create_receipt',
      status: SyncOperationStatuses.queued,
    );
    const error = 'Не удалось проверить сохранённые действия.';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pendingSyncProvider.overrideWith(
            (ref) => _StubPendingSyncNotifier(ref, [queued], error: error),
          ),
        ],
        child: MaterialApp(
          theme: MostTheme.lightTheme,
          home: const PendingSyncScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не удалось обновить список'), findsOneWidget);
    expect(find.text(error), findsOneWidget);
    expect(find.text('Приход на склад'), findsOneWidget);
  });

  testWidgets('shows uncertain result without offering automatic retry', (
    tester,
  ) async {
    final uncertain = _operation(
      moduleSlug: 'quality_control',
      operationType: 'create_defect',
      status: SyncOperationStatuses.conflict,
      error: SyncQueueMessages.unknownOutcome,
    );

    late _StubPendingSyncNotifier notifier;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pendingSyncProvider.overrideWith((ref) {
            notifier = _StubPendingSyncNotifier(ref, [uncertain]);
            return notifier;
          }),
        ],
        child: MaterialApp(
          theme: MostTheme.lightTheme,
          home: const PendingSyncScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Нужно проверить результат'), findsOneWidget);
    expect(find.text(SyncQueueMessages.unknownOutcome), findsOneWidget);
    expect(find.textContaining('Не отправляйте её повторно'), findsOneWidget);
    expect(find.byTooltip('Повторить отправку'), findsNothing);

    await tester.ensureVisible(find.text('Удалить с устройства'));
    await tester.tap(find.text('Удалить с устройства'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('На сервере ничего не удалится'),
      findsOneWidget,
    );
    expect(notifier.discardedIds, isEmpty);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(notifier.discardedIds, isEmpty);

    await tester.tap(find.text('Удалить с устройства'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();
    expect(notifier.discardedIds, [uncertain.id]);
  });

  testWidgets(
    'permission denied action offers manual retry and confirmed discard',
    (tester) async {
      final denied = _operation(
        moduleSlug: 'site_requests',
        operationType: 'create_site_request',
        status: SyncOperationStatuses.permissionDenied,
      );
      late _StubPendingSyncNotifier notifier;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingSyncProvider.overrideWith((ref) {
              notifier = _StubPendingSyncNotifier(ref, [denied]);
              return notifier;
            }),
          ],
          child: MaterialApp(
            theme: MostTheme.lightTheme,
            home: const PendingSyncScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Недостаточно прав'), findsOneWidget);
      expect(find.byTooltip('Повторить отправку'), findsOneWidget);
      expect(
        find.byTooltip('Повторить отправку').hitTestable(),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Повторить отправку'));
      await tester.pump();
      expect(notifier.permissionRetryIds, [denied.id]);

      await tester.ensureVisible(find.text('Удалить с устройства'));
      await tester.tap(find.text('Удалить с устройства'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('На сервере ничего не удалится'),
        findsOneWidget,
      );
      expect(notifier.discardedIds, isEmpty);

      await tester.tap(find.text('Удалить').last);
      await tester.pumpAndSettle();
      expect(notifier.discardedIds, [denied.id]);
    },
  );

  testWidgets('permission denied card stays readable at 1.3 text scale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(720, 1280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final denied = _operation(
      moduleSlug: 'journal',
      operationType: 'create_entry',
      status: SyncOperationStatuses.permissionDenied,
    );
    late _StubPendingSyncNotifier notifier;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pendingSyncProvider.overrideWith((ref) {
            notifier = _StubPendingSyncNotifier(ref, [denied]);
            return notifier;
          }),
        ],
        child: MaterialApp(
          theme: MostTheme.lightTheme,
          home: Builder(
            builder: (context) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.3)),
                child: const PendingSyncScreen(),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Запись журнала'), findsOneWidget);
    expect(find.text('Недостаточно прав'), findsOneWidget);
    final status = tester.renderObject<RenderParagraph>(
      find.text('Недостаточно прав'),
    );
    expect(status.size.width, greaterThan(150));
    expect(find.byTooltip('Повторить отправку').hitTestable(), findsOneWidget);
    expect(find.text('Удалить с устройства').hitTestable(), findsOneWidget);

    await tester.tap(find.byTooltip('Повторить отправку'));
    await tester.pump();
    expect(notifier.permissionRetryIds, [denied.id]);
  });
}

QueuedSyncOperation _operation({
  required String moduleSlug,
  required String operationType,
  required String status,
  String? error,
}) {
  final operation =
      QueuedSyncOperation.fromDraft(
          SyncQueueDraft(
            moduleSlug: moduleSlug,
            operationType: operationType,
            method: 'POST',
            endpoint: '/queued-operation',
            payload: const {'queue_scope': '7:10:session-a'},
          ),
          createdAt: DateTime(2026, 9, 18, 10),
        )
        ..id = 42
        ..status = status;
  operation.lastBusinessError = error;
  return operation;
}

class _StubPendingSyncNotifier extends PendingSyncNotifier {
  _StubPendingSyncNotifier(super.ref, this._operations, {this.error});

  final List<QueuedSyncOperation> _operations;
  final String? error;
  int retryCount = 0;
  final permissionRetryIds = <int>[];
  final discardedIds = <int>[];

  @override
  Future<void> load() async {
    state = PendingSyncState(operations: _operations, error: error);
  }

  @override
  Future<void> retryQueued() async {
    retryCount++;
  }

  @override
  Future<void> retryPermissionDenied(int id) async {
    permissionRetryIds.add(id);
  }

  @override
  Future<void> discardReviewed(int id) async {
    discardedIds.add(id);
  }
}
