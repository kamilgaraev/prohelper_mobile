import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/site_requests_repository.dart';

final siteRequestsMetaProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(siteRequestsRepositoryProvider).fetchMeta();
});
