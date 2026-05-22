import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../features/auth/data/user_model.dart';
import '../sync/queued_sync_operation.dart';

final isarProvider = FutureProvider<Isar>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  return await Isar.open([
    UserSchema,
    QueuedSyncOperationSchema,
  ], directory: dir.path);
});

class IsarService {
  final Future<Isar> _isarFuture;

  IsarService(this._isarFuture);

  Future<Isar> get instance => _isarFuture;

  // Future methods to access data
}
