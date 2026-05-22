import 'package:dio/dio.dart';

import '../network/api_exception.dart';
import 'sync_queue_draft.dart';
import 'sync_queue_service.dart';

abstract class SyncQueueAwareRepository {
  const SyncQueueAwareRepository(this.syncQueueServiceFuture);

  final Future<SyncQueueService>? syncQueueServiceFuture;

  Future<T> executeOrQueue<T>({
    required Future<T> Function() request,
    required SyncQueueDraft draft,
    required String businessMessage,
  }) async {
    try {
      return await request();
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        final service = await _requireSyncQueueService();
        final operation = await service.enqueue(draft);
        throw SyncQueuedException(queueId: operation.id);
      }

      throw ApiException.fromDio(error, fallbackMessage: businessMessage);
    }
  }

  Future<Never> queueAndThrow(SyncQueueDraft draft) async {
    final service = await _requireSyncQueueService();
    final operation = await service.enqueue(draft);
    throw SyncQueuedException(queueId: operation.id);
  }

  Future<SyncQueueService> _requireSyncQueueService() async {
    final future = syncQueueServiceFuture;
    if (future == null) {
      throw StateError('Sync queue service is not configured.');
    }

    return future;
  }
}
