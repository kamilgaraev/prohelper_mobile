import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_draft.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_store.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_repository.dart';
import 'package:prohelpers_mobile/features/construction_journal/presentation/journal_entry_form_screen.dart';

void main() {
  testWidgets(
    'saving a new draft returns to the journal without a pending-operation error',
    (tester) async {
      final store = _Store();
      var creates = 0;
      final dio =
          Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  final isOptions = options.path.endsWith(
                    '/entry-form-options',
                  );
                  if (!isOptions) creates++;
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: {
                        'data':
                            isOptions
                                ? {
                                  'estimates': [],
                                  'work_types': [],
                                  'project_materials': [],
                                }
                                : {
                                  'id': 42,
                                  'journal_id': 7,
                                  'entry_number': 1,
                                  'entry_date': '2026-09-20',
                                  'work_description': 'Монтаж',
                                  'status': 'draft',
                                  'status_label': 'Черновик',
                                  'workflow_state': 'ready',
                                  'workVolumes': [],
                                  'workers': [],
                                  'equipment': [],
                                  'materials': [],
                                  'blockers': [],
                                  'available_actions': [],
                                },
                      },
                    ),
                  );
                },
              ),
            );
      final queue = SyncQueueService(store: store, dio: dio);
      final repository = ConstructionJournalRepository(
        dio,
        syncQueueServiceFuture: Future.value(queue),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            constructionJournalRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: ElevatedButton(
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<bool>(
                              builder:
                                  (_) => const JournalEntryFormScreen(
                                    journalId: 7,
                                  ),
                            ),
                          ),
                      child: const Text('Открыть журнал'),
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть журнал'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Дата записи'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Описание работ',
        ),
        'Монтаж',
      );
      await tester.scrollUntilVisible(
        find.text('Сохранить черновик'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Сохранить черновик'));
      await tester.pumpAndSettle();
      expect(creates, 1);
      expect(find.text('Открыть журнал'), findsOneWidget);
      expect(await store.all(), isEmpty);
    },
  );

  testWidgets('shows notice when known ID cannot be checked offline', (
    tester,
  ) async {
    final store = _Store();
    var online = false;
    var writes = 0;
    final dio =
        Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                if (options.path.endsWith('/entry-form-options')) {
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: const {
                        'data': {
                          'estimates': <dynamic>[],
                          'work_types': <dynamic>[],
                          'project_materials': <dynamic>[],
                        },
                      },
                    ),
                  );
                  return;
                }
                if (online) {
                  if (options.method != 'GET') writes++;
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: {
                        'data': {
                          'id': 42,
                          'journal_id': 7,
                          'entry_number': 1,
                          'entry_date': '2026-09-20',
                          'work_description': 'Монтаж',
                          'status': 'submitted',
                          'status_label': 'На проверке',
                          'workflow_state': 'ready',
                          'workVolumes': [],
                          'workers': [],
                          'equipment': [],
                          'materials': [],
                          'blockers': [],
                          'available_actions': [],
                        },
                      },
                    ),
                  );
                  return;
                }
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionError,
                  ),
                );
              },
            ),
          );
    final queue = SyncQueueService(store: store, dio: dio);
    await queue.enqueue(
      const SyncQueueDraft(
        moduleSlug: 'construction_journal',
        operationType: 'create_entry',
        method: 'POST',
        endpoint: '/construction-journals/7/entries',
        payload: {
          'idempotency_key': 'restart-key',
          'journal_id': 7,
          'created_entry_id': 42,
          'stage': 'created',
          'submit_intent': true,
          'entry_date': '2026-09-20',
          'work_description': 'Сохранённая запись',
        },
      ),
    );
    final repository = ConstructionJournalRepository(
      dio,
      syncQueueServiceFuture: Future.value(queue),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          constructionJournalRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(body: JournalEntryFormScreen(journalId: 7)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('ожидает подтверждения сервера'),
      findsOneWidget,
    );
    online = true;
    await tester.scrollUntilVisible(
      find.text('Отправить'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Отправить'));
    await tester.pumpAndSettle();
    expect(await store.all(), isEmpty);
    expect(writes, 0);
  });

  testWidgets('shows server rejection and does not create a second entry', (
    tester,
  ) async {
    final store = _Store();
    var creates = 0;
    final dio =
        Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                if (options.path.endsWith('/entry-form-options')) {
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: const {
                        'data': {
                          'estimates': <dynamic>[],
                          'work_types': <dynamic>[],
                          'project_materials': <dynamic>[],
                        },
                      },
                    ),
                  );
                  return;
                }
                creates++;
                handler.reject(
                  DioException(
                    requestOptions: options,
                    response: Response(
                      requestOptions: options,
                      statusCode: 422,
                      data: {
                        'message': 'Нет протокола для участка А',
                      },
                    ),
                    type: DioExceptionType.badResponse,
                  ),
                );
              },
            ),
          );
    final queue = SyncQueueService(store: store, dio: dio);
    final repository = ConstructionJournalRepository(
      dio,
      syncQueueServiceFuture: Future.value(queue),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          constructionJournalRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(body: JournalEntryFormScreen(journalId: 7)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дата записи'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Описание работ',
      ),
      'Монтаж',
    );
    await tester.scrollUntilVisible(
      find.text('Сохранить черновик'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Сохранить черновик'));
    await tester.pumpAndSettle();
    expect(creates, 1);
    expect(await store.all(), isEmpty);
    await tester.scrollUntilVisible(
      find.textContaining('Отклонено сервером'),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Отклонено сервером'), findsWidgets);
    expect(find.textContaining('Нет протокола для участка А'), findsWidgets);
  });
}

class _Store implements SyncQueueStore {
  final operations = <QueuedSyncOperation>[];

  @override
  Future<QueuedSyncOperation> put(QueuedSyncOperation operation) async {
    if (operation.id == 0) {
      operation.id = operations.length + 1;
      operations.add(operation);
    } else {
      final index = operations.indexWhere((item) => item.id == operation.id);
      if (index == -1) {
        operations.add(operation);
      } else {
        operations[index] = operation;
      }
    }
    return operation;
  }

  @override
  Future<List<QueuedSyncOperation>> all() async => List.of(operations);

  @override
  Future<List<QueuedSyncOperation>> due(DateTime now) async => all();

  @override
  Future<QueuedSyncOperation?> get(int id) async {
    for (final operation in operations) {
      if (operation.id == id) return operation;
    }
    return null;
  }

  @override
  Future<void> delete(int id) async {
    operations.removeWhere((item) => item.id == id);
  }
}
