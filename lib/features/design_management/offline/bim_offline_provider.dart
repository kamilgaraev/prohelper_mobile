import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/widgets.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/encrypted_local_file_cache.dart';
import '../../../core/storage/isar_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/domain/auth_provider.dart';
import 'bim_offline_service.dart';
import 'bim_offline_store.dart';
import 'bim_offline_transport.dart';

bool bimOfflineAuthIsValid(
  Map<String, dynamic>? record,
  DateTime now,
  String scope,
) {
  if (record == null) return false;
  final confirmed = DateTime.tryParse(record['confirmed_at']?.toString() ?? '');
  if (confirmed == null || record['token'] == null) return false;
  final age = now.toUtc().difference(confirmed.toUtc());
  final recordScope =
      '${record['user_id']}:${record['organization_id'] ?? 0}:${record['session_id']}';
  return recordScope == scope &&
      !age.isNegative &&
      age <= const Duration(days: 14);
}

String? bimAuthScope(AuthState state) {
  if (state is! AuthAuthenticated || state.sessionIdentity == null) return null;
  final identity = state.sessionIdentity!;
  return '${identity.userId}:${identity.organizationId ?? 0}:${identity.sessionId}';
}

final FutureProvider<BimOfflineService>
bimOfflineServiceProvider = FutureProvider<BimOfflineService>((ref) async {
  var disposed = false;
  BimOfflineService? initialized;
  ref.onDispose(() {
    disposed = true;
    initialized?.dispose();
  });
  final isar = await ref.watch(isarProvider.future);
  if (disposed) throw StateError('Работа с сохранёнными моделями завершена.');
  late final BimOfflineService service;
  service = BimOfflineService(
    store: IsarBimOfflineStore(isar),
    files: ref.read(encryptedLocalFileCacheProvider),
    transport: DioBimOfflineTransport(ref.read(dioProvider)),
    currentScope: () => disposed ? null : bimAuthScope(ref.read(authProvider)),
    canUseOffline: () async {
      if (disposed) return false;
      final scope = bimAuthScope(ref.read(authProvider));
      if (scope == null) return false;
      final storage = ref.read(secureStorageProvider);
      final record = await storage.getOfflineAuth();
      final token = await storage.getToken();
      return !disposed &&
          record?['token'] == token &&
          token?.isNotEmpty == true &&
          bimOfflineAuthIsValid(record, DateTime.now(), scope);
    },
    isOnline: () async {
      final connectivity = await Connectivity().checkConnectivity();
      return connectivity.any((item) => item != ConnectivityResult.none);
    },
    verifyOnline: () async {
      if (disposed) return false;
      final before = bimAuthScope(ref.read(authProvider));
      final verified =
          await ref.read(authProvider.notifier).verifyOnlineForQueue();
      return !disposed &&
          verified &&
          before != null &&
          bimAuthScope(ref.read(authProvider)) == before;
    },
  );
  ref.listen<AuthState>(authProvider, (previous, next) {
    if (bimAuthScope(previous ?? AuthInitial()) != bimAuthScope(next)) {
      service.stopOperations();
    }
  });
  initialized = service;
  final lifecycle = _BimLifecycle(service);
  WidgetsBinding.instance.addObserver(lifecycle);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(lifecycle));
  unawaited(service.resumeInterruptedDownloads());
  return service;
});

class _BimLifecycle with WidgetsBindingObserver {
  _BimLifecycle(this.service);
  final BimOfflineService service;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(service.resumeInterruptedDownloads());
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      service.stopOperations();
    }
  }
}

final bimOfflineChangesProvider = StreamProvider<void>((ref) async* {
  final service = await ref.watch(bimOfflineServiceProvider.future);
  yield null;
  yield* service.changes;
});
