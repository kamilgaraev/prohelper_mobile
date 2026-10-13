import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/bim_models.dart';
import '../data/bim_repository.dart';
import '../../auth/domain/auth_provider.dart';
import '../../projects/domain/projects_provider.dart';

typedef DrawingIssueKey = ({int projectId, int versionId});

final drawingIssuesProvider = FutureProvider.autoDispose
    .family<List<BimIssue>, DrawingIssueKey>((ref, key) async {
      final auth = ref.watch(authProvider);
      final project = ref.watch(projectsProvider).selectedProject?.serverId;
      if (auth is! AuthAuthenticated || project != key.projectId) return [];
      var disposed = false;
      ref.onDispose(() => disposed = true);
      final repository = ref.watch(bimRepositoryProvider);
      final issues = <BimIssue>[];
      var page = 1;
      while (true) {
        final result = await repository.issues(
          key.projectId,
          versionId: key.versionId,
          page: page,
        );
        issues.addAll(result.items);
        if (disposed) return [];
        if (result.page >= result.lastPage || result.items.isEmpty) {
          return issues;
        }
        page++;
      }
    });
