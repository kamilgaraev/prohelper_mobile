import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_control_repository.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_defect_model.dart';
import 'package:prohelpers_mobile/features/quality_control/domain/quality_control_provider.dart';

class _FakeQualityControlRepository extends QualityControlRepository {
  _FakeQualityControlRepository({this.permissionDenied = false}) : super(Dio());

  final bool permissionDenied;

  int? loadedProjectId;
  String? loadedStatus;
  String? loadedSeverity;
  bool? loadedOverdueOnly;
  int? fetchedDefectId;
  int? startedDefectId;
  int? resolvedDefectId;
  int? verifiedDefectId;
  int? rejectedDefectId;
  String? rejectedComment;
  Map<String, dynamic>? createdData;
  List<String> createdPhotoPaths = const <String>[];
  List<String> resolvedPhotoPaths = const <String>[];

  @override
  Future<List<QualityDefectModel>> fetchDefects({
    int page = 1,
    int perPage = 50,
    int? projectId,
    String? status,
    String? severity,
    bool overdueOnly = false,
  }) async {
    if (permissionDenied) {
      throw const ApiException(
        'Недостаточно прав для просмотра контроля качества.',
        statusCode: 403,
      );
    }

    loadedProjectId = projectId;
    loadedStatus = status;
    loadedSeverity = severity;
    loadedOverdueOnly = overdueOnly;
    return [_defect];
  }

  @override
  Future<QualityDefectModel> createDefect(
    Map<String, dynamic> data, {
    List<String> photoPaths = const [],
  }) async {
    createdData = data;
    createdPhotoPaths = List<String>.from(photoPaths);
    return _defect;
  }

  @override
  Future<QualityDefectModel> fetchDefect(int id) async {
    fetchedDefectId = id;
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
    List<String> photoPaths = const [],
  }) async {
    resolvedDefectId = id;
    resolvedPhotoPaths = List<String>.from(photoPaths);
    return _defect;
  }

  @override
  Future<QualityDefectModel> verifyDefect(int id, {String? comment}) async {
    verifiedDefectId = id;
    return _defect;
  }

  @override
  Future<QualityDefectModel> rejectDefect(
    int id, {
    required String comment,
  }) async {
    rejectedDefectId = id;
    rejectedComment = comment;
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
  workflowSummary: QualityDefectWorkflowSummary(
    status: 'open',
    availableActions: ['start', 'resolve'],
    problemFlags: [],
  ),
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

    await notifier.createDefect(
      {'project_id': 15, 'title': 'Скол'},
      photoPaths: const ['/tmp/before-1.jpg', '/tmp/before-2.jpg'],
    );
    await notifier.startDefect(7, comment: 'Взято в работу');
    await notifier.resolveDefect(
      7,
      comment: 'Исправлено',
      photoPaths: const ['/tmp/after-1.jpg', '/tmp/after-2.jpg'],
    );
    await notifier.verifyDefect(7, comment: 'Проверено');
    await notifier.rejectDefect(7, comment: 'Нужно переделать');

    expect(repository.createdData?['project_id'], 15);
    expect(repository.createdPhotoPaths, [
      '/tmp/before-1.jpg',
      '/tmp/before-2.jpg',
    ]);
    expect(repository.startedDefectId, 7);
    expect(repository.resolvedDefectId, 7);
    expect(repository.resolvedPhotoPaths, [
      '/tmp/after-1.jpg',
      '/tmp/after-2.jpg',
    ]);
    expect(repository.verifiedDefectId, 7);
    expect(repository.rejectedDefectId, 7);
    expect(repository.rejectedComment, 'Нужно переделать');
    expect(notifier.state.defects, hasLength(1));
  });

  test('передает выбранные фильтры в загрузку дефектов', () async {
    final repository = _FakeQualityControlRepository();
    final notifier = QualityControlNotifier(repository)..syncProject(15);

    notifier.setStatusFilter('ready_for_review');
    notifier.setSeverityFilter('critical');
    notifier.setOverdueOnly(true);
    await notifier.loadDefects();

    expect(repository.loadedProjectId, 15);
    expect(repository.loadedStatus, 'ready_for_review');
    expect(repository.loadedSeverity, 'critical');
    expect(repository.loadedOverdueOnly, isTrue);

    notifier.setStatusFilter(null);
    notifier.setSeverityFilter(null);
    notifier.setOverdueOnly(false);
    await notifier.loadDefects();

    expect(repository.loadedStatus, isNull);
    expect(repository.loadedSeverity, isNull);
    expect(repository.loadedOverdueOnly, isFalse);
  });

  test('загружает детальную карточку дефекта', () async {
    final repository = _FakeQualityControlRepository();
    final notifier = QualityControlNotifier(repository);

    final defect = await notifier.fetchDefect(7);

    expect(repository.fetchedDefectId, 7);
    expect(defect.id, 7);
  });

  test('фиксирует состояние недостаточных прав при загрузке', () async {
    final repository = _FakeQualityControlRepository(permissionDenied: true);
    final notifier = QualityControlNotifier(repository)..syncProject(15);

    await notifier.loadDefects();

    expect(notifier.state.permissionDenied, isTrue);
    expect(
      notifier.state.error,
      'Недостаточно прав для просмотра контроля качества.',
    );
    expect(notifier.state.defects, isEmpty);
  });
}
