import 'dart:async';

import 'package:dio/dio.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/widgets/pro_card.dart';
import 'package:prohelpers_mobile/features/payments/data/payment_document_model.dart';
import 'package:prohelpers_mobile/features/payments/data/payments_repository.dart';
import 'package:prohelpers_mobile/features/payments/presentation/payments_screen.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

class _TestPaymentsRepository extends PaymentsRepository {
  _TestPaymentsRepository({this.canCreate = false, this.pageItems})
    : super(Dio());

  final bool canCreate;
  final List<PaymentDocumentModel>? pageItems;

  Map<String, dynamic>? updatedValues;
  bool failNextUpdate = false;
  bool failNextDecision = false;
  bool failNextRegistration = false;
  bool failNextCreate = false;
  bool failNextOptions = false;
  bool returnEmptyOptionsNext = false;
  Completer<PaymentFormOptions>? pendingOptions;
  bool canApprove = true;
  bool canReject = true;
  bool canRegisterPayment = true;
  int createCalls = 0;
  int registrationCalls = 0;
  final decisionComments = <String>[];
  final registrationKeys = <String>[];
  final creationKeys = <String>[];
  final optionRequests = <(String, int)>[];

  @override
  Future<PaymentDocumentPage> list({
    required int projectId,
    int page = 1,
    String? status,
    String? search,
  }) async {
    return PaymentDocumentPage(
      items:
          pageItems ??
          [
            PaymentDocumentModel.fromJson({
              'id': 52,
              'payment_purpose': 'Поставка арматуры для перекрытия секции А',
              'status': 'partially_paid',
              'status_label': 'Частично оплачен',
              'amount': '123 456,78 ₽',
            }),
          ],
      currentPage: page,
      lastPage: page,
      canCreate: canCreate,
    );
  }

  @override
  Future<PaymentFormOptions> formOptions({
    int? projectId,
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    optionRequests.add((search ?? '', page));
    if (failNextOptions) {
      failNextOptions = false;
      throw const ApiException(
        'Не удалось загрузить стороны.',
        statusCode: 500,
      );
    }
    final pending = pendingOptions;
    pendingOptions = null;
    if (pending != null) return pending.future;
    if (returnEmptyOptionsNext) {
      returnEmptyOptionsNext = false;
      return PaymentFormOptions(
        currentOrganization: const PaymentPartyOption(
          id: 7,
          name: 'МОСТ',
          type: 'organization',
          inn: '7701000000',
        ),
        contractors: PaymentContractorPage(
          items: const [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        ),
      );
    }
    return PaymentFormOptions(
      currentOrganization: const PaymentPartyOption(
        id: 7,
        name: 'МОСТ',
        type: 'organization',
        inn: '7701000000',
      ),
      contractors: PaymentContractorPage(
        items: const [
          PaymentPartyOption(
            id: 31,
            name: 'ООО Поставка',
            type: 'contractor',
            inn: '7702000000',
          ),
        ],
        currentPage: page,
        lastPage: 2,
        total: 21,
      ),
    );
  }

  @override
  Future<PaymentDocumentModel> update(
    int id,
    Map<String, dynamic> values,
  ) async {
    if (failNextUpdate) {
      failNextUpdate = false;
      throw const ApiException('Проверьте реквизиты.', statusCode: 422);
    }
    updatedValues = Map.of(values);
    return PaymentDocumentModel.fromJson({'id': id, ...values});
  }

  @override
  Future<PaymentDocumentModel> detail(int id) async =>
      PaymentDocumentModel.fromJson({
        'id': id,
        'document_type': 'payment_order',
        'document_date': '2026-09-01',
        'amount': 1250,
        'payment_purpose': 'Оплата поставки',
        'status': 'draft',
        'can_reject': canReject,
        'can_approve': canApprove,
        'can_register_payment': canRegisterPayment,
      });

  @override
  Future<PaymentDocumentModel> decide(
    int id, {
    required bool approve,
    required String comment,
  }) async {
    decisionComments.add(comment);
    if (failNextDecision) {
      failNextDecision = false;
      throw const ApiException(
        'Не удалось сохранить решение.',
        statusCode: 422,
      );
    }
    return PaymentDocumentModel.fromJson({'id': id, 'status': 'rejected'});
  }

  @override
  Future<PaymentDocumentModel> registerPayment(
    int id,
    Map<String, dynamic> values, {
    required String idempotencyKey,
  }) async {
    registrationCalls++;
    registrationKeys.add(idempotencyKey);
    if (failNextRegistration) {
      failNextRegistration = false;
      throw const ApiException('Ответ сервера потерян.', statusCode: 500);
    }
    return PaymentDocumentModel.fromJson({'id': id, 'status': 'paid'});
  }

  @override
  Future<PaymentDocumentModel> create(
    Map<String, dynamic> values, {
    required String idempotencyKey,
  }) async {
    createCalls++;
    creationKeys.add(idempotencyKey);
    if (failNextCreate) {
      failNextCreate = false;
      throw const ApiException(
        'Не удалось сохранить документ.',
        statusCode: 500,
      );
    }
    return PaymentDocumentModel.fromJson({'id': 88, ...values});
  }
}

class _TestSecureStorage extends SecureStorageService {
  final Map<String, String> _keys = {};
  bool failClear = false;
  int creates = 0;

  @override
  Future<String> getOrCreateOperationKey({
    required String namespace,
    required String fingerprint,
  }) async {
    final storageKey = '$namespace|$fingerprint';
    return _keys.putIfAbsent(storageKey, () {
      creates++;
      return 'stable-operation-key-$creates';
    });
  }

  @override
  Future<void> clearOperationKey({
    required String namespace,
    required String fingerprint,
  }) async {
    if (failClear) throw StateError('test cleanup failure');
    _keys.remove('$namespace|$fingerprint');
  }
}

void _mockConnectivity(
  WidgetTester tester,
  Future<List<String>> Function(MethodCall call) handler,
) {
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, handler);
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}

Widget _paymentHarness({
  required Widget screen,
  required _TestPaymentsRepository repository,
  required _TestSecureStorage storage,
  double textScale = 1,
}) => ProviderScope(
  overrides: [
    paymentsRepositoryProvider.overrideWithValue(repository),
    secureStorageProvider.overrideWithValue(storage),
  ],
  child: MaterialApp(
    builder:
        (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
    home: Builder(
      builder:
          (context) => Scaffold(
            body: TextButton(
              onPressed:
                  () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => screen)),
              child: const Text('Открыть'),
            ),
          ),
    ),
  ),
);

Future<void> _fillNewPaymentForm(WidgetTester tester) async {
  for (final input in [
    (const ValueKey('payment-purpose'), 'Оплата поставки'),
    (const ValueKey('payment-amount'), '1250'),
    (const ValueKey('payment-bank-account'), '12345678901234567890'),
    (const ValueKey('payment-bank-bik'), '123456789'),
  ]) {
    await tester.ensureVisible(find.byKey(input.$1));
    await tester.enterText(find.byKey(input.$1), input.$2);
  }
  final payer = find.byKey(const ValueKey('payment-payer'));
  await tester.ensureVisible(payer);
  await tester.tap(payer);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Организация: МОСТ · ИНН 7701000000'));
  await tester.pumpAndSettle();
  final payee = find.byKey(const ValueKey('payment-payee'));
  await tester.ensureVisible(payee);
  await tester.tap(payee);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Контрагент: ООО Поставка · ИНН 7702000000'));
  await tester.pumpAndSettle();
}

class _TestProjectsRepository extends ProjectsRepository {
  _TestProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _SelectedProjectNotifier extends ProjectsNotifier {
  _SelectedProjectNotifier() : super(_TestProjectsRepository()) {
    final project =
        Project()
          ..serverId = 52
          ..name = 'Тестовый объект'
          ..address = 'Участок 1';
    state = ProjectsState(
      isLoading: false,
      projects: [project],
      selectedProject: project,
    );
  }
}

void main() {
  testWidgets(
    'new payment form validates required parties and bank details on narrow screen',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(240, 426);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _TestPaymentsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [paymentsRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: TextButton(
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => const PaymentDocumentFormScreen(
                                    projectId: 52,
                                  ),
                            ),
                          ),
                      child: const Text('Открыть'),
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Сохранить'));
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(find.text('Выберите Плательщик в списке'), findsOneWidget);
      expect(find.text('Выберите Получатель в списке'), findsOneWidget);
      expect(find.text('Введите 20 цифр расчётного счёта'), findsOneWidget);
      expect(find.text('Введите 9 цифр БИК'), findsOneWidget);
      expect(repository.updatedValues, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing shows saved parties and preloads bank details narrowly',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(240, 426);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const connectivity = MethodChannel(
        'dev.fluttercommunity.plus/connectivity',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(connectivity, (call) async => ['wifi']);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(connectivity, null);
      });
      final repository = _TestPaymentsRepository();
      repository.failNextUpdate = true;
      final document = PaymentDocumentModel.fromJson({
        'id': 19,
        'document_type': 'payment_order',
        'document_date': '2026-09-01',
        'amount': 1250,
        'payment_purpose': 'Оплата поставки',
        'description': 'Сохранить это значение',
        'payer_name': 'Текущая организация',
        'payee_name': 'Сохранённый контрагент',
        'bank_details': {'account': '12345678901234567890', 'bik': '123456789'},
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [paymentsRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: TextButton(
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => PaymentDocumentFormScreen(
                                    projectId: 52,
                                    document: document,
                                  ),
                            ),
                          ),
                      child: const Text('Открыть'),
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(
        find.text('Сохранённый плательщик: Текущая организация'),
        findsOneWidget,
      );
      expect(
        find.text('Сохранённый получатель: Сохранённый контрагент'),
        findsOneWidget,
      );
      final partySearch = find.byKey(const ValueKey('payment-party-search'));
      await tester.ensureVisible(partySearch);
      await tester.enterText(partySearch, 'Поставка');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repository.optionRequests.last, ('Поставка', 1));
      await tester.ensureVisible(find.text('Ещё контрагенты'));
      await tester.tap(find.text('Ещё контрагенты'));
      await tester.pumpAndSettle();
      expect(repository.optionRequests.last, ('Поставка', 2));
      final payeeDropdown = find
          .byType(DropdownButtonFormField<PaymentPartyOption>)
          .at(1);
      await tester.ensureVisible(payeeDropdown);
      await tester.tap(payeeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Контрагент: ООО Поставка · ИНН 7702000000').last,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Сохранить'));
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(find.text('Проверьте реквизиты.'), findsOneWidget);
      expect(repository.updatedValues, isNull);
      await tester.ensureVisible(find.text('Сохранить'));
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(repository.updatedValues, isNotNull);
      expect(repository.updatedValues!['payee_contractor_id'], 31);
      expect(repository.updatedValues!['payee_organization_id'], isNull);
      expect(
        repository.updatedValues,
        isNot(contains('payer_organization_id')),
      );
      expect(repository.updatedValues, isNot(contains('payer_contractor_id')));
      expect(repository.updatedValues!['bank_account'], '12345678901234567890');
      expect(repository.updatedValues!['bank_bik'], '123456789');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('party search keeps its focused field mounted while loading', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(240, 426);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _TestPaymentsRepository();
    await tester.pumpWidget(
      _paymentHarness(
        screen: const PaymentDocumentFormScreen(projectId: 52),
        repository: repository,
        storage: _TestSecureStorage(),
        textScale: 1.3,
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    final search = find.byKey(const ValueKey('payment-party-search'));
    await tester.ensureVisible(search);
    final searchElement = tester.element(search);
    final pendingOptions = Completer<PaymentFormOptions>();
    repository.pendingOptions = pendingOptions;
    await tester.enterText(search, 'Север');
    await tester.pump(const Duration(milliseconds: 351));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(search, findsOneWidget);
    expect(identical(searchElement, tester.element(search)), isTrue);
    expect(tester.widget<TextField>(search).controller!.text, 'Север');
    expect(tester.testTextInput.isVisible, isTrue);

    pendingOptions.complete(
      PaymentFormOptions(
        currentOrganization: const PaymentPartyOption(
          id: 7,
          name: 'МОСТ',
          type: 'organization',
          inn: '7701000000',
        ),
        contractors: PaymentContractorPage(
          items: const [
            PaymentPartyOption(
              id: 32,
              name: 'ООО Север',
              type: 'contractor',
              inn: '7703000000',
            ),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(search, findsOneWidget);
    expect(tester.widget<TextField>(search).controller!.text, 'Север');
    expect(tester.testTextInput.isVisible, isTrue);
    final payee = find.byKey(const ValueKey('payment-payee'));
    await tester.ensureVisible(payee);
    await tester.tap(payee);
    await tester.pumpAndSettle();
    expect(find.text('Контрагент: ООО Север · ИНН 7703000000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new search supersedes an in-flight contractor page', (
    tester,
  ) async {
    final repository = _TestPaymentsRepository();
    await tester.pumpWidget(
      _paymentHarness(
        screen: const PaymentDocumentFormScreen(projectId: 52),
        repository: repository,
        storage: _TestSecureStorage(),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    final appendResponse = Completer<PaymentFormOptions>();
    repository.pendingOptions = appendResponse;
    final more = find.text('Ещё контрагенты');
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pump();
    expect(repository.optionRequests.last, ('', 2));
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Загрузка…'))
          .onPressed,
      isNull,
    );

    final searchResponse = Completer<PaymentFormOptions>();
    repository.pendingOptions = searchResponse;
    final search = find.byKey(const ValueKey('payment-party-search'));
    await tester.ensureVisible(search);
    await tester.enterText(search, 'Новая выборка');
    await tester.pump(const Duration(milliseconds: 351));
    await tester.pump();
    expect(repository.optionRequests.last, ('Новая выборка', 1));

    searchResponse.complete(
      PaymentFormOptions(
        currentOrganization: const PaymentPartyOption(
          id: 7,
          name: 'МОСТ',
          type: 'organization',
          inn: '7701000000',
        ),
        contractors: PaymentContractorPage(
          items: const [
            PaymentPartyOption(
              id: 33,
              name: 'ООО Новая выборка',
              type: 'contractor',
              inn: '7704000000',
            ),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(search, findsOneWidget);
    expect(find.text('Ещё контрагенты'), findsNothing);

    appendResponse.complete(
      PaymentFormOptions(
        currentOrganization: const PaymentPartyOption(
          id: 7,
          name: 'МОСТ',
          type: 'organization',
          inn: '7701000000',
        ),
        contractors: PaymentContractorPage(
          items: const [
            PaymentPartyOption(
              id: 34,
              name: 'Устаревшая страница',
              type: 'contractor',
              inn: '7705000000',
            ),
          ],
          currentPage: 2,
          lastPage: 2,
          total: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final payee = find.byKey(const ValueKey('payment-payee'));
    await tester.ensureVisible(payee);
    await tester.tap(payee);
    await tester.pumpAndSettle();
    expect(
      find.text('Контрагент: ООО Новая выборка · ИНН 7704000000'),
      findsOneWidget,
    );
    expect(
      find.text('Контрагент: Устаревшая страница · ИНН 7705000000'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing immediately invalidates a pending contractor page', (
    tester,
  ) async {
    final repository = _TestPaymentsRepository();
    await tester.pumpWidget(
      _paymentHarness(
        screen: const PaymentDocumentFormScreen(projectId: 52),
        repository: repository,
        storage: _TestSecureStorage(),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    final appendResponse = Completer<PaymentFormOptions>();
    repository.pendingOptions = appendResponse;
    await tester.ensureVisible(find.text('Ещё контрагенты'));
    await tester.tap(find.text('Ещё контрагенты'));
    await tester.pump();
    expect(repository.optionRequests.last, ('', 2));

    final search = find.byKey(const ValueKey('payment-party-search'));
    final searchElement = tester.element(search);
    await tester.enterText(search, 'Новая выборка');
    await tester.pump(const Duration(milliseconds: 100));
    appendResponse.complete(
      PaymentFormOptions(
        currentOrganization: const PaymentPartyOption(
          id: 7,
          name: 'МОСТ',
          type: 'organization',
          inn: '7701000000',
        ),
        contractors: PaymentContractorPage(
          items: const [
            PaymentPartyOption(
              id: 34,
              name: 'Устаревшая страница',
              type: 'contractor',
              inn: '7705000000',
            ),
          ],
          currentPage: 2,
          lastPage: 2,
          total: 2,
        ),
      ),
    );
    await tester.pump();

    final payee = find.byKey(const ValueKey('payment-payee'));
    await tester.ensureVisible(payee);
    await tester.tap(payee);
    await tester.pump();
    expect(repository.optionRequests, hasLength(2));
    expect(
      find.text('Контрагент: Устаревшая страница · ИНН 7705000000'),
      findsNothing,
    );
    expect(identical(searchElement, tester.element(search)), isTrue);
    expect(tester.widget<TextField>(search).controller!.text, 'Новая выборка');
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 251));
    await tester.pumpAndSettle();
    expect(repository.optionRequests.last, ('Новая выборка', 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed contractor page retry appends the same page', (
    tester,
  ) async {
    final repository = _TestPaymentsRepository();
    await tester.pumpWidget(
      _paymentHarness(
        screen: const PaymentDocumentFormScreen(projectId: 52),
        repository: repository,
        storage: _TestSecureStorage(),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    repository.failNextOptions = true;
    await tester.ensureVisible(find.text('Ещё контрагенты'));
    await tester.tap(find.text('Ещё контрагенты'));
    await tester.pumpAndSettle();

    expect(repository.optionRequests.last, ('', 2));
    expect(find.text('Не удалось загрузить стороны.'), findsOneWidget);
    expect(find.byKey(const ValueKey('payment-party-search')), findsOneWidget);
    final retryResponse = Completer<PaymentFormOptions>();
    repository.pendingOptions = retryResponse;
    await tester.ensureVisible(find.text('Повторить загрузку сторон'));
    await tester.tap(find.text('Повторить загрузку сторон'));
    await tester.pump();
    expect(repository.optionRequests.last, ('', 2));
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Загрузка…'))
          .onPressed,
      isNull,
    );
    retryResponse.complete(
      PaymentFormOptions(
        currentOrganization: const PaymentPartyOption(
          id: 7,
          name: 'МОСТ',
          type: 'organization',
          inn: '7701000000',
        ),
        contractors: PaymentContractorPage(
          items: const [
            PaymentPartyOption(
              id: 32,
              name: 'ООО Вторая страница',
              type: 'contractor',
              inn: '7706000000',
            ),
          ],
          currentPage: 2,
          lastPage: 2,
          total: 21,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final payee = find.byKey(const ValueKey('payment-payee'));
    await tester.ensureVisible(payee);
    await tester.tap(payee);
    await tester.pumpAndSettle();
    expect(
      find.text('Контрагент: ООО Поставка · ИНН 7702000000'),
      findsOneWidget,
    );
    expect(
      find.text('Контрагент: ООО Вторая страница · ИНН 7706000000'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('party search error keeps selections and retries inline', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(240, 426);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _TestPaymentsRepository();
    await tester.pumpWidget(
      _paymentHarness(
        screen: const PaymentDocumentFormScreen(projectId: 52),
        repository: repository,
        storage: _TestSecureStorage(),
        textScale: 1.3,
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await _fillNewPaymentForm(tester);

    repository.failNextOptions = true;
    final search = find.byKey(const ValueKey('payment-party-search'));
    await tester.ensureVisible(search);
    await tester.enterText(search, 'Не найден');
    await tester.pump(const Duration(milliseconds: 351));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить стороны.'), findsOneWidget);
    expect(search, findsOneWidget);
    expect(tester.widget<TextField>(search).controller!.text, 'Не найден');
    final dropdowns = tester
        .widgetList<DropdownButtonFormField<PaymentPartyOption>>(
          find.byType(DropdownButtonFormField<PaymentPartyOption>),
        );
    expect(dropdowns, hasLength(2));
    expect(dropdowns.first.initialValue?.id, 7);
    expect(dropdowns.last.initialValue?.id, 31);
    expect(find.text('Повторить загрузку сторон'), findsOneWidget);

    await tester.ensureVisible(find.text('Повторить загрузку сторон'));
    await tester.tap(find.text('Повторить загрузку сторон'));
    await tester.pumpAndSettle();
    expect(search, findsOneWidget);
    expect(tester.widget<TextField>(search).controller!.text, 'Не найден');
    expect(repository.optionRequests.last, ('Не найден', 1));
    final retriedDropdowns = tester
        .widgetList<DropdownButtonFormField<PaymentPartyOption>>(
          find.byType(DropdownButtonFormField<PaymentPartyOption>),
        );
    expect(retriedDropdowns.first.initialValue?.id, 7);
    expect(retriedDropdowns.last.initialValue?.id, 31);

    repository.returnEmptyOptionsNext = true;
    await tester.enterText(search, 'Нет результатов');
    await tester.pump(const Duration(milliseconds: 351));
    await tester.pumpAndSettle();
    expect(find.text('Контрагенты не найдены.'), findsOneWidget);
    expect(search, findsOneWidget);
    expect(
      tester.widget<TextField>(search).controller!.text,
      'Нет результатов',
    );
    final emptyResultDropdowns = tester
        .widgetList<DropdownButtonFormField<PaymentPartyOption>>(
          find.byType(DropdownButtonFormField<PaymentPartyOption>),
        );
    expect(emptyResultDropdowns, hasLength(2));
    expect(emptyResultDropdowns.first.initialValue?.id, 7);
    expect(emptyResultDropdowns.last.initialValue?.id, 31);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rejection reason stays available after validation and 422 retry',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(240, 426);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository =
          _TestPaymentsRepository()
            ..failNextDecision = true
            ..canApprove = false
            ..canRegisterPayment = false;
      var isOnline = false;
      _mockConnectivity(tester, (_) async => isOnline ? ['wifi'] : ['none']);
      await tester.pumpWidget(
        _paymentHarness(
          screen: const PaymentDocumentDetailScreen(id: 14),
          repository: repository,
          storage: _TestSecureStorage(),
          textScale: 1.3,
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отклонить'));
      await tester.pumpAndSettle();

      final reasonField = find.byKey(
        const ValueKey('payment-decision-comment'),
      );
      await tester.enterText(reasonField, 'не');
      await tester.tap(find.widgetWithText(FilledButton, 'Отклонить').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Укажите причину отклонения не короче 3 символов.'),
        findsOneWidget,
      );
      expect(repository.decisionComments, isEmpty);

      await tester.enterText(reasonField, 'Недостаточно документов');
      await tester.tap(find.widgetWithText(FilledButton, 'Отклонить').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Для решения подключитесь к интернету.'),
        findsOneWidget,
      );
      expect(repository.decisionComments, isEmpty);

      isOnline = true;
      await tester.tap(find.widgetWithText(FilledButton, 'Отклонить').last);
      await tester.pumpAndSettle();
      expect(find.text('Не удалось сохранить решение.'), findsOneWidget);
      expect(
        tester.widget<TextField>(reasonField).controller!.text,
        'Недостаточно документов',
      );
      expect(repository.decisionComments, ['Недостаточно документов']);

      await tester.tap(find.widgetWithText(FilledButton, 'Отклонить').last);
      await tester.pumpAndSettle();
      expect(repository.decisionComments, [
        'Недостаточно документов',
        'Недостаточно документов',
      ]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new payment save reserves busy before delayed connectivity check',
    (tester) async {
      final repository = _TestPaymentsRepository();
      final storage = _TestSecureStorage()..failClear = true;
      final networkGate = Completer<List<String>>();
      var networkChecks = 0;
      _mockConnectivity(tester, (_) {
        networkChecks++;
        return networkGate.future;
      });
      await tester.pumpWidget(
        _paymentHarness(
          screen: const PaymentDocumentFormScreen(projectId: 52),
          repository: repository,
          storage: storage,
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      await _fillNewPaymentForm(tester);
      final save = tester.widget<FilledButton>(
        find.byKey(const ValueKey('payment-document-save')),
      );
      save.onPressed!();
      save.onPressed!();
      await tester.pump();
      expect(networkChecks, 1);
      expect(repository.createCalls, 0);

      networkGate.complete(['wifi']);
      await tester.pumpAndSettle();
      expect(repository.createCalls, 1);
      expect(repository.creationKeys, ['stable-operation-key-1']);
      expect(storage.creates, 1);
      expect(
        find.text('Для сохранения подключитесь к интернету.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending decision connectivity result is ignored after screen disposal',
    (tester) async {
      final repository =
          _TestPaymentsRepository()
            ..canApprove = false
            ..canRegisterPayment = false;
      final networkGate = Completer<List<String>>();
      _mockConnectivity(tester, (_) => networkGate.future);
      await tester.pumpWidget(
        _paymentHarness(
          screen: const PaymentDocumentDetailScreen(id: 14),
          repository: repository,
          storage: _TestSecureStorage(),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Отклонить'));
      await tester.tap(find.text('Отклонить'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('payment-decision-comment')),
        'Причина отказа',
      );
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Отклонить').last,
          )
          .onPressed!();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());

      networkGate.complete(['wifi']);
      await tester.pumpAndSettle();
      expect(repository.decisionComments, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending new-payment connectivity result is ignored after screen disposal',
    (tester) async {
      final repository = _TestPaymentsRepository();
      final networkGate = Completer<List<String>>();
      _mockConnectivity(tester, (_) => networkGate.future);
      await tester.pumpWidget(
        _paymentHarness(
          screen: const PaymentDocumentFormScreen(projectId: 52),
          repository: repository,
          storage: _TestSecureStorage(),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      await _fillNewPaymentForm(tester);
      final save = tester.widget<FilledButton>(
        find.byKey(const ValueKey('payment-document-save')),
      );
      save.onPressed!();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());

      networkGate.complete(['wifi']);
      await tester.pumpAndSettle();
      expect(repository.createCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending registration connectivity result is ignored after screen disposal',
    (tester) async {
      final repository = _TestPaymentsRepository();
      final networkGate = Completer<List<String>>();
      _mockConnectivity(tester, (_) => networkGate.future);
      await tester.pumpWidget(
        _paymentHarness(
          screen: const PaymentDocumentDetailScreen(id: 14),
          repository: repository,
          storage: _TestSecureStorage(),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      final amount = find.byKey(const ValueKey('payment-register-amount'));
      await tester.ensureVisible(amount);
      await tester.enterText(amount, '500');
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('payment-register-submit')),
          )
          .onPressed!();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());

      networkGate.complete(['wifi']);
      await tester.pumpAndSettle();
      expect(repository.registrationCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'payment registration double tap posts once and cleanup failure is not a false error',
    (tester) async {
      final repository = _TestPaymentsRepository();
      final storage = _TestSecureStorage()..failClear = true;
      final networkGate = Completer<List<String>>();
      var networkChecks = 0;
      _mockConnectivity(tester, (_) {
        networkChecks++;
        return networkGate.future;
      });
      await tester.pumpWidget(
        _paymentHarness(
          screen: const PaymentDocumentDetailScreen(id: 14),
          repository: repository,
          storage: storage,
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      final amount = find.byKey(const ValueKey('payment-register-amount'));
      await tester.ensureVisible(amount);
      await tester.enterText(amount, '500');
      final register = tester.widget<FilledButton>(
        find.byKey(const ValueKey('payment-register-submit')),
      );
      register.onPressed!();
      register.onPressed!();
      await tester.pump();
      expect(networkChecks, 1);
      expect(repository.registrationCalls, 0);

      networkGate.complete(['wifi']);
      await tester.pumpAndSettle();
      expect(repository.registrationCalls, 1);
      expect(storage.creates, 1);
      expect(
        find.text('Для фиксации оплаты подключитесь к интернету.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'registration retry after lost response reuses the same idempotency key',
    (tester) async {
      final repository = _TestPaymentsRepository()..failNextRegistration = true;
      final storage = _TestSecureStorage();
      _mockConnectivity(tester, (_) async => ['wifi']);
      await tester.pumpWidget(
        _paymentHarness(
          screen: const PaymentDocumentDetailScreen(id: 14),
          repository: repository,
          storage: storage,
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      final amount = find.byKey(const ValueKey('payment-register-amount'));
      await tester.ensureVisible(amount);
      await tester.enterText(amount, '500');
      final register = find.byKey(const ValueKey('payment-register-submit'));
      await tester.tap(register);
      await tester.pumpAndSettle();
      expect(repository.registrationCalls, 1);
      expect(find.text('Ответ сервера потерян.'), findsOneWidget);
      expect(tester.widget<TextField>(amount).controller!.text, '500');

      await tester.tap(register);
      await tester.pumpAndSettle();
      expect(repository.registrationCalls, 2);
      expect(repository.registrationKeys, [
        'stable-operation-key-1',
        'stable-operation-key-1',
      ]);
      expect(storage.creates, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [240.0, 360.0]) {
    testWidgets('shows full payment data at ${width.toInt()}dp', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectsProvider.overrideWith((ref) => _SelectedProjectNotifier()),
            paymentsRepositoryProvider.overrideWithValue(
              _TestPaymentsRepository(),
            ),
          ],
          child: MaterialApp(
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
            home: const PaymentsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Поставка арматуры для перекрытия секции А'),
        findsOneWidget,
      );
      expect(find.text('Частично оплачен · 123 456,78 ₽'), findsOneWidget);
      expect(find.byTooltip('Создать документ'), findsNothing);
      expect(
        tester
            .getSize(find.text('Поставка арматуры для перекрытия секции А'))
            .width,
        greaterThan(90),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'payment detail and create targets remain separate while scrolling',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final items = List.generate(
        8,
        (index) => PaymentDocumentModel.fromJson({
          'id': 52 + index,
          'payment_purpose': 'Платёж ${index + 1}: поставка арматуры',
          'status': 'partially_paid',
          'status_label': 'Частично оплачен',
          'amount': '123 456,78 ₽',
        }),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectsProvider.overrideWith((ref) => _SelectedProjectNotifier()),
            paymentsRepositoryProvider.overrideWithValue(
              _TestPaymentsRepository(canCreate: true, pageItems: items),
            ),
          ],
          child: MaterialApp(
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
            home: const PaymentsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final createAction = find.byTooltip('Создать документ');
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(createAction, findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      final card =
          find
              .ancestor(
                of: find.text('Платёж 8: поставка арматуры'),
                matching: find.byType(ProCard),
              )
              .first;
      final cardRect = tester.getRect(card);
      expect(cardRect.overlaps(tester.getRect(createAction)), isFalse);
      const formerlyCoveredPoint = Offset(236, 756);
      expect(cardRect.contains(formerlyCoveredPoint), isTrue);

      await tester.tapAt(formerlyCoveredPoint);
      await tester.pump();
      expect(find.byType(PaymentDocumentFormScreen), findsNothing);
    },
  );
}
