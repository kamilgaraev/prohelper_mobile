import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/module_companions/data/companion_module_model.dart';
import 'package:prohelpers_mobile/features/module_companions/data/companion_module_repository.dart';
import 'package:prohelpers_mobile/features/module_companions/domain/companion_module_provider.dart';

import '../companion_module_test_data.dart';

class _RecordingCompanionRepository extends CompanionModuleRepository {
  _RecordingCompanionRepository({this.error}) : super(Dio());

  final Object? error;
  String? loadedSlug;
  int? loadedProjectId;
  String? loadedStatus;
  String? loadedQuery;
  int? detailId;
  String? actionKey;
  String? actionComment;
  int refreshCount = 0;

  @override
  Future<CompanionModuleListModel> fetchList({
    required String moduleSlug,
    int? projectId,
    String? status,
    String? query,
    int perPage = 20,
  }) async {
    final currentError = error;
    if (currentError != null) {
      throw currentError;
    }

    loadedSlug = moduleSlug;
    loadedProjectId = projectId;
    loadedStatus = status;
    loadedQuery = query;
    refreshCount++;

    return CompanionModuleListModel.fromJson(
      companionListJson(slug: moduleSlug),
    );
  }

  @override
  Future<CompanionModuleDetailModel> fetchDetail({
    required String moduleSlug,
    required int id,
  }) async {
    detailId = id;
    return CompanionModuleDetailModel.fromJson(
      companionDetailJson(slug: moduleSlug),
    );
  }

  @override
  Future<CompanionModuleDetailModel> executeAction({
    required String moduleSlug,
    required int id,
    required String action,
    String? comment,
  }) async {
    actionKey = action;
    actionComment = comment;
    return CompanionModuleDetailModel.fromJson(
      companionDetailJson(slug: moduleSlug),
    );
  }
}

void main() {
  test('loads companion list with project status and query', () async {
    final repository = _RecordingCompanionRepository();
    final notifier = CompanionModuleNotifier(repository, 'contract-management')
      ..syncProject(9);

    await notifier.setStatus('active');
    await notifier.setQuery('Tower');

    expect(repository.loadedSlug, 'contract-management');
    expect(repository.loadedProjectId, 9);
    expect(repository.loadedStatus, 'active');
    expect(repository.loadedQuery, 'Tower');
    expect(notifier.state.list?.items.single.id, 42);
    expect(notifier.state.error, isNull);
  });

  test('loads detail and action then refreshes list', () async {
    final repository = _RecordingCompanionRepository();
    final notifier = CompanionModuleNotifier(repository, 'change-management');

    final detail = await notifier.fetchDetail(42);
    await notifier.executeAction(id: 42, action: 'submit', comment: 'Done');

    expect(repository.detailId, 42);
    expect(repository.actionKey, 'submit');
    expect(repository.actionComment, 'Done');
    expect(repository.refreshCount, 1);
    expect(detail.sections.single.title, 'Основное');
  });

  test('marks permission and malformed states', () async {
    final denied = CompanionModuleNotifier(
      _RecordingCompanionRepository(
        error: const ApiException('Нет доступа', statusCode: 403),
      ),
      'contract-management',
    );
    await denied.load();

    expect(denied.state.permissionDenied, isTrue);

    final malformed = CompanionModuleNotifier(
      _RecordingCompanionRepository(
        error: const FormatException('bad contract'),
      ),
      'contract-management',
    );
    await malformed.load();

    expect(malformed.state.malformedContract, isTrue);
  });
}
