import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_session_identity.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/contract_management/data/legal_document_model.dart';
import 'package:prohelpers_mobile/features/contract_management/data/legal_document_repository.dart';
import 'package:prohelpers_mobile/features/contract_management/data/legal_document_snapshot.dart';
import 'package:prohelpers_mobile/features/contract_management/domain/legal_document_provider.dart';

void main() {
  test(
    'keeps an in-flight API list response when auth verification updates',
    () async {
      const identity = AuthSessionIdentity(
        userId: 7,
        organizationId: 3,
        sessionId: 'session-a',
      );
      final auth = _TestAuthNotifier(
        AuthAuthenticated(User(), sessionIdentity: identity),
      );
      final repository = _PendingLegalDocumentRepository();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => auth),
          legalDocumentRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(legalDocumentProvider.notifier);
      notifier.syncProject(31);
      final load = notifier.load();

      auth.verifyOnline();
      expect(container.read(legalDocumentProvider.notifier), same(notifier));

      repository.response.complete(
        LegalDocumentListResult(
          documents: [LegalDocumentModel.fromJson({'id': 42, 'title': 'Договор'})],
          isPartial: false,
          isFromCache: false,
        ),
      );
      await load;

      expect(container.read(legalDocumentProvider).documents.single.id, 42);
    },
  );
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(AuthState initialState)
    : super(_FakeAuthRepository(), _FakeSecureStorage(), autoCheckAuth: false) {
    state = initialState;
  }

  void verifyOnline() {
    final current = state as AuthAuthenticated;
    state = AuthAuthenticated(
      current.user,
      sessionIdentity: current.sessionIdentity,
      isOnlineVerified: true,
    );
  }
}

class _FakeAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSecureStorage implements SecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PendingLegalDocumentRepository extends LegalDocumentRepository {
  _PendingLegalDocumentRepository() : super(Dio());

  final response = Completer<LegalDocumentListResult>();

  @override
  Future<LegalDocumentListResult> fetchDocumentList({
    required int projectId,
    LegalDocumentCacheIdentity? identity,
    CancelToken? cancelToken,
    bool Function()? isCurrent,
  }) => response.future;
}
