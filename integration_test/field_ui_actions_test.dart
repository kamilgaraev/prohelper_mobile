import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_repository.dart';
import 'package:prohelpers_mobile/features/construction_journal/presentation/journal_entry_form_screen.dart';
import 'package:prohelpers_mobile/features/production_labor/data/production_labor_model.dart';
import 'package:prohelpers_mobile/features/production_labor/data/production_labor_repository.dart';
import 'package:prohelpers_mobile/features/production_labor/domain/production_labor_provider.dart';
import 'package:prohelpers_mobile/features/production_labor/presentation/production_labor_screen.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_control_repository.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_defect_model.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_photo_picker.dart';
import 'package:prohelpers_mobile/features/quality_control/domain/quality_control_provider.dart';
import 'package:prohelpers_mobile/features/quality_control/presentation/quality_control_screen.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_request_detail_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_request_detail_screen.dart';

import '../test/helpers/mobile_integration_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureMostIntegrationTestEnvironment();

  testWidgets('uploads a photo from the site request screen', (tester) async {
    final previousPicker = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _FakeImagePickerPlatform();
    addTearDown(() => ImagePickerPlatform.instance = previousPicker);

    final repository = _SiteRequestRepository();
    await pumpMostWidget(
      tester,
      const SiteRequestDetailScreen(id: 1001),
      overrides: [
        ...mostCoreOverrides(selectedProject: MostTestData.project()),
        siteRequestsRepositoryProvider.overrideWithValue(repository),
        siteRequestDetailProvider.overrideWith(
          (ref, id) => SiteRequestDetailNotifier(repository, ref, id),
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Добавить фото'));
    await tester.tap(find.byTooltip('Добавить фото'));
    await tester.pumpAndSettle();

    expect(repository.uploadedRequestId, 1001);
    expect(repository.uploadedPath, '/tmp/site-request-photo.jpg');
    expect(find.text('site-request-photo.jpg'), findsOneWidget);
  });

  testWidgets('creates a quality defect with a picked photo', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _QualityRepository();
    await pumpMostWidget(
      tester,
      const QualityControlScreen(),
      overrides: [
        ...mostCoreOverrides(selectedProject: MostTestData.project()),
        qualityControlProvider.overrideWith(
          (ref) => QualityControlNotifier(repository),
        ),
        qualityPhotoPickerProvider.overrideWithValue(
          _FakeQualityPhotoPicker('/tmp/quality-before.jpg'),
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Скол плитки');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Средняя').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Не требуется').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Добавить фото до исправления'));
    await tester.tap(find.text('Добавить фото до исправления'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(repository.createdTitle, 'Скол плитки');
    expect(repository.photoPaths, ['/tmp/quality-before.jpg']);
  });

  testWidgets('saves a journal draft through its form', (tester) async {
    var createRequests = 0;
    final dio =
        Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                if (options.path.endsWith('/entry-form-options')) {
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: const {
                        'data': {
                          'estimates': <dynamic>[],
                          'work_types': <dynamic>[],
                          'project_materials': <dynamic>[],
                        },
                      },
                    ),
                  );
                  return;
                }
                createRequests++;
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: {
                      'data': {
                        'id': 42,
                        'journal_id': 7,
                        'entry_number': 1,
                        'entry_date': '2026-09-20',
                        'work_description': 'Монтаж перекрытия',
                        'status': 'draft',
                        'status_label': 'Черновик',
                        'workflow_state': 'ready',
                        'workVolumes': <dynamic>[],
                        'workers': <dynamic>[],
                        'equipment': <dynamic>[],
                        'materials': <dynamic>[],
                        'blockers': <dynamic>[],
                        'available_actions': <dynamic>[],
                      },
                    },
                  ),
                );
              },
            ),
          );
    final repository = ConstructionJournalRepository(dio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          constructionJournalRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(body: JournalEntryFormScreen(journalId: 7)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Дата записи'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Описание работ',
      ),
      'Монтаж перекрытия',
    );
    await tester.scrollUntilVisible(
      find.text('Сохранить черновик'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Сохранить черновик'));
    await tester.pumpAndSettle();

    expect(createRequests, 1);
    expect(find.byType(JournalEntryFormScreen), findsNothing);
  });

  testWidgets('shows review status after submitting production output', (
    tester,
  ) async {
    final repository = _ProductionLaborRepository();
    final project = MostTestData.project();
    await pumpMostWidget(
      tester,
      const ProductionLaborScreen(),
      overrides: [
        ...mostCoreOverrides(selectedProject: project),
        projectsProvider.overrideWith(
          (ref) => TestProjectsNotifier(
            projects: [project],
            selectedProject: project,
          ),
        ),
        productionLaborProvider.overrideWith(
          (ref) => _ProductionLaborNotifier(repository),
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Выработка'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '2');
    await tester.enterText(find.byType(TextFormField).at(1), '4');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(repository.outputCalls, 1);
    expect(repository.idempotencyKeys, hasLength(1));
    expect(find.text(SyncQueueMessages.unknownOutcome), findsOneWidget);
    expect(find.text('Факт выработки'), findsNothing);
  });
}

class _FakeImagePickerPlatform extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile('/tmp/site-request-photo.jpg');
}

class _SiteRequestRepository extends SiteRequestsRepository {
  _SiteRequestRepository() : super(Dio());

  int? uploadedRequestId;
  String? uploadedPath;
  List<Map<String, dynamic>> _files = const [];

  @override
  Future<SiteRequestModel> fetchSiteRequestDetails(int id) async =>
      SiteRequestModel()
        ..serverId = id
        ..title = 'Заявка на бетон'
        ..description = 'Поставка на сегодня'
        ..status = 'draft'
        ..statusLabel = 'Черновик'
        ..priority = 'medium'
        ..priorityLabel = 'Средний'
        ..requestType = 'material_request'
        ..requestTypeLabel = 'Материалы'
        ..projectId = 15
        ..projectName = 'Объект А';

  @override
  Future<List<Map<String, dynamic>>> fetchFiles(int requestId) async => _files;

  @override
  Future<void> uploadFile(int requestId, String path) async {
    uploadedRequestId = requestId;
    uploadedPath = path;
    _files = [
      {
        'id': 9,
        'name': 'site-request-photo.jpg',
        'download_url': 'https://example.test/site-request-photo.jpg',
      },
    ];
  }
}

class _QualityRepository extends QualityControlRepository {
  _QualityRepository() : super(Dio());

  String? createdTitle;
  List<String> photoPaths = const [];

  @override
  Future<List<QualityDefectModel>> fetchDefects({
    int page = 1,
    int perPage = 50,
    int? projectId,
    String? status,
    String? severity,
    bool overdueOnly = false,
  }) async => const [];

  @override
  Future<QualityDefectModel> createDefect(
    Map<String, dynamic> data, {
    List<String> photoPaths = const [],
  }) async {
    createdTitle = data['title']?.toString();
    this.photoPaths = List<String>.from(photoPaths);
    return const QualityDefectModel(
      id: 1,
      defectNumber: 'QD-1',
      title: 'Скол плитки',
      severity: 'major',
      status: 'open',
      availableActions: [],
      inspectionRequired: false,
      workflowSummary: QualityDefectWorkflowSummary(
        status: 'open',
        availableActions: [],
        problemFlags: [],
      ),
    );
  }
}

class _FakeQualityPhotoPicker extends QualityPhotoPicker {
  _FakeQualityPhotoPicker(this.path);

  final String path;

  @override
  Future<String?> pickInitialPhoto() async => path;
}

class _ProductionLaborRepository extends ProductionLaborRepository {
  _ProductionLaborRepository() : super(Dio());

  int outputCalls = 0;
  final List<String> idempotencyKeys = [];

  LaborWorkOrderModel get workOrder => const LaborWorkOrderModel(
    id: 5,
    projectId: 15,
    title: 'Монтаж стен',
    orderNumber: 'PL-1',
    status: 'in_progress',
    statusLabel: 'В работе',
    availableActions: ['submit'],
    assigneeName: 'Бригада 1',
    lines: [
      LaborWorkOrderLineModel(
        id: 7,
        workOrderId: 5,
        name: 'Стены',
        unit: 'м2',
        plannedQuantity: 10,
        acceptedQuantity: 3,
        remainingQuantity: 7,
        requiresSafetyPermit: false,
      ),
    ],
  );

  @override
  Future<List<LaborWorkOrderModel>> fetchWorkOrders({int? projectId}) async => [
    workOrder,
  ];

  @override
  Future<LaborOutputModel> recordOutput({
    required int workOrderLineId,
    required double quantity,
    required double hours,
    required String workDate,
    required String idempotencyKey,
    String? comment,
  }) async {
    outputCalls++;
    idempotencyKeys.add(idempotencyKey);
    throw const SyncQueuedException(queueId: 12, requiresReview: true);
  }
}

class _ProductionLaborNotifier extends ProductionLaborNotifier {
  _ProductionLaborNotifier(this.repository) : super(repository) {
    state = ProductionLaborState(
      isLoading: false,
      projectFilter: 15,
      workOrders: [repository.workOrder],
      error: null,
    );
  }

  final _ProductionLaborRepository repository;

  @override
  Future<void> load() async {
    state = state.copyWith(
      isLoading: false,
      projectFilter: 15,
      workOrders: [repository.workOrder],
      error: null,
    );
  }
}
