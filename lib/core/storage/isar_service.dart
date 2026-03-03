import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../features/auth/data/user_model.dart';

final isarProvider = FutureProvider<Isar>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  return await Isar.open(
    [UserSchema],
    directory: dir.path,
  );
});

class IsarService {
  final Future<Isar> _isarFuture;

  IsarService(this._isarFuture);
  
  // Future methods to access data
}
