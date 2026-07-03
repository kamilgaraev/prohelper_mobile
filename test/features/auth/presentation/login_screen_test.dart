import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/widgets/app_action_buttons.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/presentation/login_screen.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(Dio(), _MemorySecureStorage());

  int loginCalls = 0;
  Object? loginError;
  Completer<User>? pendingLogin;

  @override
  Future<User> login(String email, String password) async {
    loginCalls += 1;
    final error = loginError;
    if (error != null) {
      throw error;
    }

    final pending = pendingLogin;
    if (pending != null) {
      return pending.future;
    }

    return User()
      ..serverId = 7
      ..email = email
      ..name = 'Иван Прораб';
  }
}

class _MemorySecureStorage extends SecureStorageService {
  String? token;

  @override
  Future<void> saveToken(String token) async {
    this.token = token;
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> clearToken() async {
    token = null;
  }
}

void main() {
  testWidgets('login brand header uses Russian product tagline', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();

    await _pumpLogin(tester, repository: repository);

    expect(find.text('Управление строительством'), findsOneWidget);
    expect(find.text('Industrial management'), findsNothing);
  });

  testWidgets('login form shows inline required field errors', (tester) async {
    final repository = _FakeAuthRepository();

    await _pumpLogin(tester, repository: repository);
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Введите email'), findsOneWidget);
    expect(find.text('Введите пароль'), findsOneWidget);
    expect(find.text('Введите email и пароль.'), findsNothing);
    expect(repository.loginCalls, 0);
  });

  testWidgets('login form cleans technical submit errors', (tester) async {
    final repository =
        _FakeAuthRepository()
          ..loginError = const FormatException('payload auth token');

    await _pumpLogin(tester, repository: repository);
    await tester.enterText(find.byType(TextField).at(0), 'foreman@test.local');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    expect(
      find.text('Не удалось выполнить действие. Попробуйте еще раз.'),
      findsOneWidget,
    );
    expect(find.textContaining('FormatException'), findsNothing);
    expect(find.textContaining('payload'), findsNothing);
    expect(repository.loginCalls, 1);
  });

  testWidgets('login form clears submit error after user edits fields', (
    tester,
  ) async {
    final repository =
        _FakeAuthRepository()
          ..loginError = const ApiException(
            'Email или пароль не подошли. Проверьте данные и попробуйте еще раз.',
            statusCode: 401,
          );

    await _pumpLogin(tester, repository: repository);
    await tester.enterText(find.byType(TextField).at(0), 'foreman@test.local');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Email или пароль не подошли. Проверьте данные и попробуйте еще раз.',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).at(0), 'foreman2@test.local');
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Email или пароль не подошли. Проверьте данные и попробуйте еще раз.',
      ),
      findsNothing,
    );
    expect(repository.loginCalls, 1);
  });

  testWidgets('login submit hides keyboard while request is running', (
    tester,
  ) async {
    final repository = _FakeAuthRepository()..pendingLogin = Completer<User>();

    await _pumpLogin(tester, repository: repository);
    await tester.enterText(find.byType(TextField).at(0), 'foreman@test.local');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.showKeyboard(find.byType(TextField).at(1));

    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('Войти'));
    await tester.pump();

    expect(repository.loginCalls, 1);
    expect(tester.testTextInput.isVisible, isFalse);

    repository.pendingLogin!.complete(
      User()
        ..serverId = 7
        ..email = 'foreman@test.local'
        ..name = 'Иван Прораб',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('password visibility control has screen reader labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = _FakeAuthRepository();

    try {
      await _pumpLogin(tester, repository: repository);

      expect(find.bySemanticsLabel('Показать пароль'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Показать пароль'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Скрыть пароль'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('login fields expose explicit screen reader labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = _FakeAuthRepository();

    try {
      await _pumpLogin(tester, repository: repository);

      expect(find.bySemanticsLabel('Поле ввода: Email'), findsOneWidget);
      expect(find.bySemanticsLabel('Поле ввода: Пароль'), findsOneWidget);

      final emailNode = tester.getSemantics(
        find.bySemanticsLabel('Поле ввода: Email'),
      );
      final passwordNode = tester.getSemantics(
        find.bySemanticsLabel('Поле ввода: Пароль'),
      );

      for (final node in [emailNode, passwordNode]) {
        expect(node.hasFlag(SemanticsFlag.isTextField), isTrue);
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.setText),
          isTrue,
        );
      }
      expect(emailNode.childrenCount, 0);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('login credential fields disable text correction helpers', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();

    await _pumpLogin(tester, repository: repository);

    final emailField = tester.widget<TextField>(find.byType(TextField).at(0));
    final passwordField = tester.widget<TextField>(
      find.byType(TextField).at(1),
    );

    for (final field in [emailField, passwordField]) {
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.enableIMEPersonalizedLearning, isFalse);
      expect(field.smartDashesType, SmartDashesType.disabled);
      expect(field.smartQuotesType, SmartQuotesType.disabled);
    }
  });

  testWidgets('login fields keep visible labels when empty', (tester) async {
    final repository = _FakeAuthRepository();

    await _pumpLogin(tester, repository: repository);

    final emailField = tester.widget<TextField>(find.byType(TextField).at(0));
    final passwordField = tester.widget<TextField>(
      find.byType(TextField).at(1),
    );

    expect(
      emailField.decoration?.floatingLabelBehavior,
      FloatingLabelBehavior.always,
    );
    expect(
      passwordField.decoration?.floatingLabelBehavior,
      FloatingLabelBehavior.always,
    );
  });

  testWidgets('login form keeps breathing room above the keyboard', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();

    await _pumpLogin(
      tester,
      repository: repository,
      viewInsets: const EdgeInsets.only(bottom: 320),
    );

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    final padding = scrollView.padding as EdgeInsets;

    expect(padding.bottom, 52);
    expect(
      scrollView.keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
  });

  testWidgets('login form compacts brand area above keyboard with large text', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLogin(
      tester,
      repository: repository,
      viewInsets: const EdgeInsets.only(bottom: 380),
      textScaler: TextScaler.linear(1.6),
    );

    expect(find.text('Industrial management'), findsNothing);

    final actionRect = tester.getRect(find.byType(AppPrimaryActionButton));
    final keyboardTop = tester.view.physicalSize.height - 380;

    expect(actionRect.top, lessThan(keyboardTop));
  });
}

Future<void> _pumpLogin(
  WidgetTester tester, {
  required _FakeAuthRepository repository,
  EdgeInsets viewInsets = EdgeInsets.zero,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        secureStorageProvider.overrideWithValue(_MemorySecureStorage()),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(viewInsets: viewInsets, textScaler: textScaler),
          child: const LoginScreen(),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}
