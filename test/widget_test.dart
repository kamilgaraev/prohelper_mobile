import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/localization/most_localizations.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/core/widgets/app_loading_state.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_session_identity.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/auth/presentation/login_screen.dart';
import 'package:prohelpers_mobile/main.dart';

class _FakeSecureStorageService extends SecureStorageService {
  @override
  Future<String?> getToken() async => null;

  @override
  Future<Map<String, dynamic>?> getOfflineAuth() async => null;

  @override
  Future<void> saveToken(String token) async {}

  @override
  Future<void> clearToken() async {}
}

class _PendingSecureStorageService extends SecureStorageService {
  final Completer<String?> _tokenCompleter = Completer<String?>();

  @override
  Future<String?> getToken() => _tokenCompleter.future;

  @override
  Future<void> saveToken(String token) async {}

  @override
  Future<void> clearToken() async {}
}

void main() {
  test('session lock closes screens opened over the app', () {
    final user =
        User()
          ..serverId = 7
          ..email = 'foreman@example.test'
          ..name = 'Прораб'
          ..roles = <String>[]
          ..organizationsJson = '[]'
          ..permissionsJson = '{}';
    const identity = AuthSessionIdentity(
      userId: 7,
      organizationId: 12,
      sessionId: 'session-1',
    );
    final signedIn = AuthAuthenticated(user, sessionIdentity: identity);

    expect(
      authTransitionClosesRoutes(signedIn, AuthLocked(user, identity)),
      isTrue,
    );
    expect(authTransitionClosesRoutes(signedIn, AuthUnauthenticated()), isTrue);
    expect(
      authTransitionClosesRoutes(
        AuthLocked(user, identity),
        AuthAuthenticated(user, sessionIdentity: identity),
      ),
      isFalse,
    );
    expect(
      authTransitionClosesRoutes(
        signedIn,
        AuthAuthenticated(user, sessionIdentity: identity),
      ),
      isFalse,
    );
  });

  testWidgets('экран проверки сессии сохраняет читаемый системный статус-бар', (
    WidgetTester tester,
  ) async {
    final storage = _PendingSecureStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
        child: const MostApp(),
      ),
    );

    await tester.pump();

    expect(find.byType(AppLoadingState), findsOneWidget);

    final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.ancestor(
        of: find.byType(AppLoadingState),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ),
    );

    expect(overlay.value.statusBarColor, Colors.transparent);
    expect(overlay.value.statusBarIconBrightness, Brightness.dark);
    expect(overlay.value.statusBarBrightness, Brightness.light);
  });

  testWidgets('Приложение открывает экран входа без сохраненной сессии', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorageService()),
        ],
        child: const MostApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, MostLocalizations.ru);
    expect(app.localizationsDelegates, MostLocalizations.delegates);
    expect(app.supportedLocales, MostLocalizations.supportedLocales);

    final loginContext = tester.element(find.byType(LoginScreen));
    expect(MaterialLocalizations.of(loginContext).okButtonLabel, 'ОК');
    expect(
      MaterialLocalizations.of(loginContext).datePickerHelpText,
      'Выберите дату',
    );
  });
}
