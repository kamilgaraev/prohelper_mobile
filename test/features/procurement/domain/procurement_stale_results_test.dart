import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/procurement/data/procurement_model.dart';
import 'package:prohelpers_mobile/features/procurement/data/procurement_repository.dart';
import 'package:prohelpers_mobile/features/procurement/domain/procurement_provider.dart';

import '../procurement_test_data.dart';

class _PageRepository extends ProcurementRepository {
  _PageRepository() : super(Dio());

  Future<ProcurementPage<ProcurementPurchaseRequestModel>> Function({
    required int? projectId,
    required int page,
    required String? status,
    required String? query,
  })?
  requestHandler;
  Object? requestError;
  Object? summaryError;
  final requestQueries = <String?>[];
  final requestProjects = <int?>[];

  Future<ProcurementPage<ProcurementPurchaseOrderModel>> Function({
    required int? projectId,
    required int page,
    required String? status,
    required String? query,
  })?
  orderHandler;
  Object? orderError;

  @override
  Future<ProcurementSummaryModel> fetchSummary({int? projectId}) async {
    final error = summaryError;
    if (error != null) throw error;
    return ProcurementSummaryModel.fromJson(procurementSummaryJson());
  }

  @override
  Future<ProcurementPage<ProcurementPurchaseRequestModel>>
  fetchPurchaseRequests({
    int? projectId,
    int page = 1,
    String? status,
    String? query,
  }) {
    requestQueries.add(query);
    requestProjects.add(projectId);
    final error = requestError;
    if (error != null) return Future.error(error);
    final handler = requestHandler;
    if (handler != null) {
      return handler(
        projectId: projectId,
        page: page,
        status: status,
        query: query,
      );
    }
    return Future.value(_requestPage());
  }

  @override
  Future<ProcurementPage<ProcurementPurchaseOrderModel>> fetchPurchaseOrders({
    int? projectId,
    int page = 1,
    String? status,
    String? query,
  }) {
    final error = orderError;
    if (error != null) return Future.error(error);
    final handler = orderHandler;
    if (handler != null) {
      return handler(
        projectId: projectId,
        page: page,
        status: status,
        query: query,
      );
    }
    return Future.value(_orderPage());
  }

  ProcurementPage<ProcurementPurchaseRequestModel> _requestPage() =>
      ProcurementPage(
        items: [
          ProcurementPurchaseRequestModel.fromJson(
            procurementPurchaseRequestJson(),
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );

  ProcurementPage<ProcurementPurchaseOrderModel> _orderPage() =>
      ProcurementPage(
        items: [
          ProcurementPurchaseOrderModel.fromJson(
            procurementPurchaseOrderJson(),
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );
}

const _emptyRequestPage = ProcurementPage<ProcurementPurchaseRequestModel>(
  items: [],
  currentPage: 1,
  lastPage: 1,
  total: 0,
);

void main() {
  test('keeps current rows visible during a pending refresh', () async {
    final repository = _PageRepository();
    final notifier = ProcurementNotifier(repository)..syncProject(9);
    await notifier.loadSummary();
    final response =
        Completer<ProcurementPage<ProcurementPurchaseRequestModel>>();
    repository.requestHandler =
        ({
          required projectId,
          required page,
          required status,
          required query,
        }) => response.future;

    final refresh = notifier.filterRequests();
    expect(notifier.state.loadingRequests, isTrue);
    expect(notifier.state.requests.items, hasLength(1));
    expect(notifier.state.requestsShowingPreviousQuery, isFalse);

    response.complete(_emptyRequestPage);
    await refresh;

    expect(notifier.state.requests.items, isEmpty);
    expect(notifier.state.requests.total, 0);
    expect(notifier.state.requestsShowingPreviousQuery, isFalse);
  });

  test(
    'keeps same-project rows after offline query failure and retries it',
    () async {
      final repository = _PageRepository();
      final notifier = ProcurementNotifier(repository)..syncProject(9);
      await notifier.loadSummary();
      repository.requestError = const ApiException('Нет соединения');

      await notifier.filterRequests(query: 'бетон');

      expect(notifier.state.requests.items, hasLength(1));
      expect(notifier.state.requestsShowingPreviousQuery, isTrue);
      expect(notifier.state.requestsError, isNotNull);

      repository.requestError = null;
      repository.requestHandler =
          ({
            required projectId,
            required page,
            required status,
            required query,
          }) => Future.value(_emptyRequestPage);
      await notifier.filterRequests();

      expect(repository.requestQueries.last, 'бетон');
      expect(notifier.state.requests.items, isEmpty);
      expect(notifier.state.requestsShowingPreviousQuery, isFalse);
      expect(notifier.state.requestsError, isNull);

      repository.requestHandler = null;
      await notifier.filterRequests(query: '');
      expect(repository.requestQueries.last, '');
      expect(notifier.state.requests.items, hasLength(1));
      expect(notifier.state.requestsShowingPreviousQuery, isFalse);
    },
  );

  test('does not use stale rows after a non-offline response', () async {
    for (final statusCode in [401, 403, 404, 422]) {
      final repository = _PageRepository();
      final notifier = ProcurementNotifier(repository)..syncProject(9);
      await notifier.loadSummary();
      repository.requestError = ApiException(
        'Ошибка $statusCode',
        statusCode: statusCode,
      );

      await notifier.filterRequests(query: 'бетон');

      expect(notifier.state.requests.items, isEmpty, reason: '$statusCode');
      expect(
        notifier.state.hasSuccessfulRequestsPage,
        isFalse,
        reason: '$statusCode',
      );
      expect(
        notifier.state.requestsShowingPreviousQuery,
        isFalse,
        reason: '$statusCode',
      );
      expect(notifier.state.requestsError, 'Ошибка $statusCode');
    }
  });

  test('does not carry prior project rows into an offline failure', () async {
    final repository = _PageRepository();
    final notifier = ProcurementNotifier(repository)..syncProject(9);
    await notifier.loadSummary();
    notifier.syncProject(10);
    repository.requestError = const ApiException('Нет соединения');

    await notifier.filterRequests(query: 'бетон');

    expect(repository.requestProjects.last, 10);
    expect(notifier.state.requests.items, isEmpty);
    expect(notifier.state.requestsError, isNotNull);
    expect(notifier.state.requestsShowingPreviousQuery, isFalse);
  });

  test('does not use order rows as request fallback data', () async {
    final repository = _PageRepository();
    repository.requestError = const ApiException('Нет соединения');
    final notifier = ProcurementNotifier(repository)..syncProject(9);
    await notifier.loadSummary();

    await notifier.filterRequests(query: 'бетон');

    expect(notifier.state.orders.items, hasLength(1));
    expect(notifier.state.requests.items, isEmpty);
    expect(notifier.state.hasSuccessfulRequestsPage, isFalse);
    expect(notifier.state.ordersShowingPreviousQuery, isFalse);
  });

  test('clears retained page rows when pagination is forbidden', () async {
    final repository = _PageRepository();
    repository.requestHandler =
        ({
          required projectId,
          required page,
          required status,
          required query,
        }) => Future.value(
          ProcurementPage(
            items: [
              ProcurementPurchaseRequestModel.fromJson(
                procurementPurchaseRequestJson(),
              ),
            ],
            currentPage: page,
            lastPage: 2,
            total: 2,
          ),
        );
    final notifier = ProcurementNotifier(repository)..syncProject(9);
    await notifier.loadSummary();
    repository.requestError = const ApiException(
      'Нет доступа',
      statusCode: 403,
    );

    await notifier.loadMoreRequests();

    expect(notifier.state.requests.items, isEmpty);
    expect(notifier.state.requestsError, 'Нет доступа');
  });

  test(
    'retains previous order results only for an offline filter failure',
    () async {
      final repository = _PageRepository();
      final notifier = ProcurementNotifier(repository)..syncProject(9);
      await notifier.loadSummary();
      repository.orderError = const ApiException('Нет соединения');

      await notifier.filterOrders(query: 'бетон');

      expect(notifier.state.orders.items, hasLength(1));
      expect(notifier.state.ordersShowingPreviousQuery, isTrue);

      repository.orderError = const ApiException(
        'Нет доступа',
        statusCode: 403,
      );
      await notifier.filterOrders(query: 'сталь');

      expect(notifier.state.orders.items, isEmpty);
      expect(notifier.state.ordersShowingPreviousQuery, isFalse);
    },
  );

  test('retains same-project summary after offline refresh failure', () async {
    final repository = _PageRepository();
    final notifier = ProcurementNotifier(repository)..syncProject(9);
    await notifier.loadSummary();
    repository.summaryError = const ApiException('Нет соединения');

    await notifier.loadSummary();

    expect(notifier.state.summary, isNotNull);
    expect(notifier.state.requests.items, hasLength(1));
    expect(notifier.state.orders.items, hasLength(1));
    expect(notifier.state.error, 'Нет соединения');
  });

  test('clears cached summary pages after forbidden summary refresh', () async {
    final repository = _PageRepository();
    final notifier = ProcurementNotifier(repository)..syncProject(9);
    await notifier.loadSummary();
    repository.summaryError = const ApiException(
      'Нет доступа',
      statusCode: 403,
    );

    await notifier.loadSummary();

    expect(notifier.state.summary, isNull);
    expect(notifier.state.requests.items, isEmpty);
    expect(notifier.state.orders.items, isEmpty);
    expect(notifier.state.error, 'Нет доступа');
  });

  test(
    'failed summary refresh releases invalidated request and order loaders',
    () async {
      final repository = _PageRepository();
      final notifier = ProcurementNotifier(repository)..syncProject(9);
      await notifier.loadSummary();
      final pendingRequests =
          Completer<ProcurementPage<ProcurementPurchaseRequestModel>>();
      final pendingOrders =
          Completer<ProcurementPage<ProcurementPurchaseOrderModel>>();
      repository.requestHandler =
          ({
            required projectId,
            required page,
            required status,
            required query,
          }) => pendingRequests.future;
      repository.orderHandler =
          ({
            required projectId,
            required page,
            required status,
            required query,
          }) => pendingOrders.future;

      final requestLoad = notifier.filterRequests(query: 'бетон');
      final orderLoad = notifier.filterOrders(query: 'бетон');
      expect(notifier.state.loadingRequests, isTrue);
      expect(notifier.state.loadingOrders, isTrue);

      repository.summaryError = const ApiException('Нет соединения');
      await notifier.loadSummary();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.loadingRequests, isFalse);
      expect(notifier.state.loadingOrders, isFalse);
      expect(notifier.state.error, 'Нет соединения');
      expect(notifier.state.summary, isNotNull);

      repository.summaryError = null;
      repository.requestHandler = null;
      repository.orderHandler = null;
      await notifier.loadSummary();
      pendingRequests.complete(_PageRepository()._requestPage());
      pendingOrders.complete(_PageRepository()._orderPage());
      await Future.wait([requestLoad, orderLoad]);

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.loadingRequests, isFalse);
      expect(notifier.state.loadingOrders, isFalse);
      expect(notifier.state.error, isNull);
    },
  );
}
