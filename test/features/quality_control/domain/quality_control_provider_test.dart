import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_control_repository.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_defect_model.dart';
import 'package:prohelpers_mobile/features/quality_control/domain/quality_control_provider.dart';

class _FakeQualityControlRepository extends QualityControlRepository {
  _FakeQualityControlRepository() : super(Dio());

  int? loadedProjectId;
  int? startedDefectId;
  int? resolvedDefectId;
  Map<String, dynamic>? createdData;

  @override
  Future<List<QualityDefectModel>> fetchDefects({
    int page = 1,
    int perPage = 50,
    int? projectId,
    String? status,
  }) async {
    loadedProjectId = projectId;
    return [_defect];
  }

  @override
  Future<QualityDefectModel> createDefect(Map<String, dynamic> data) async {
    createdData = data;
    return _defect;
  }

  @override
  Future<QualityDefectModel> startDefect(int id, {String? comment}) async {
    startedDefectId = id;
    return _defect;
  }

  @override
  Future<QualityDefectModel> resolveDefect(
    int id, {
    String? comment,
    String? photoUrl,
  }) async {
    resolvedDefectId = id;
    return _defect;
  }
}

const _defect = QualityDefectModel(
  id: 7,
  defectNumber: 'QD-7',
  title: 'Скол покрытия',
  severity: 'major',
  status: 'open',
  availableActions: ['start', 'resolve'],
  inspectionRequired: true,
);

void main() {
  test('загружает дефекты в контексте выбранного проекта', () async {
    final repository = _FakeQualityControlRepository();
    final notifier = QualityControlNotifier(repository);

    notifier.syncProject(15);
    await notifier.loadDefects();

    expect(repository.loadedProjectId, 15);
    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.defects.single.id, 7);
    expect(notifier.state.error, isNull);
  });

  test('после действий обновляет список дефектов', () async {
    final repository = _FakeQualityControlRepository();
    final notifier = QualityControlNotifier(repository)..syncProject(15);

    await notifier.createDefect({'project_id': 15, 'title': 'Скол'});
    await notifier.startDefect(7, comment: 'Взято в работу');
    await notifier.resolveDefect(7, comment: 'Исправлено');

    expect(repository.createdData?['project_id'], 15);
    expect(repository.startedDefectId, 7);
    expect(repository.resolvedDefectId, 7);
    expect(notifier.state.defects, hasLength(1));
  });
}
