import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'ai_assistant_models.dart';

final aiAssistantDraftTurnStoreProvider = Provider<AiAssistantDraftTurnStore>(
  (ref) => AiAssistantDraftTurnStore(),
);

typedef AiAssistantDraftScope = ({int userId, int organizationId});

class AiAssistantDraftTurnStore {
  final _storage = const FlutterSecureStorage();
  final _requests = <AiAssistantDraftScope, String?>{};
  Future<void> _writes = Future<void>.value();

  String _key(AiAssistantDraftScope scope) =>
      'assistant_draft_request_${scope.userId}_${scope.organizationId}';

  Future<String?> read(AiAssistantDraftScope scope) async {
    if (_requests.containsKey(scope)) return _requests[scope];
    String? requestId;
    try {
      requestId = await _storage.read(key: _key(scope));
    } on PlatformException {
      return _requests[scope];
    } on MissingPluginException {
      return _requests[scope];
    }
    return _requests.putIfAbsent(
      scope,
      () =>
          requestId != null && AiAssistantChatRequest.isRequestId(requestId)
              ? requestId
              : null,
    );
  }

  void track(AiAssistantDraftScope scope, String requestId) {
    _requests[scope] = requestId;
    _write(() => _storage.write(key: _key(scope), value: requestId));
  }

  void forget(AiAssistantDraftScope scope, String requestId) {
    if (_requests[scope] != requestId) return;
    _requests[scope] = null;
    _write(() => _storage.delete(key: _key(scope)));
  }

  void _write(Future<void> Function() write) {
    _writes = _writes
        .then((_) => write())
        .then<void>((_) {}, onError: (Object _) {});
  }
}
