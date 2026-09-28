import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/payments/data/payment_document_model.dart';
import 'package:prohelpers_mobile/features/payments/data/payments_repository.dart';
import 'package:prohelpers_mobile/features/payments/presentation/payments_screen.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

class _TestPaymentsRepository extends PaymentsRepository {
  _TestPaymentsRepository() : super(Dio());

  @override
  Future<PaymentDocumentPage> list({
    required int projectId,
    int page = 1,
    String? status,
    String? search,
  }) async {
    return PaymentDocumentPage(
      items: [
        PaymentDocumentModel.fromJson({
          'id': 52,
          'payment_purpose': 'Поставка арматуры для перекрытия секции А',
          'status': 'partially_paid',
          'status_label': 'Частично оплачен',
          'amount': '123 456,78 ₽',
        }),
      ],
      currentPage: page,
      lastPage: page,
      canCreate: false,
    );
  }
}

class _TestProjectsRepository extends ProjectsRepository {
  _TestProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _SelectedProjectNotifier extends ProjectsNotifier {
  _SelectedProjectNotifier() : super(_TestProjectsRepository()) {
    final project =
        Project()
          ..serverId = 52
          ..name = 'Тестовый объект'
          ..address = 'Участок 1';
    state = ProjectsState(
      isLoading: false,
      projects: [project],
      selectedProject: project,
    );
  }
}

void main() {
  for (final width in [240.0, 360.0]) {
    testWidgets('shows full payment data at ${width.toInt()}dp', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectsProvider.overrideWith((ref) => _SelectedProjectNotifier()),
            paymentsRepositoryProvider.overrideWithValue(
              _TestPaymentsRepository(),
            ),
          ],
          child: MaterialApp(
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
            home: const PaymentsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Поставка арматуры для перекрытия секции А'),
        findsOneWidget,
      );
      expect(find.text('Частично оплачен · 123 456,78 ₽'), findsOneWidget);
      expect(
        tester
            .getSize(find.text('Поставка арматуры для перекрытия секции А'))
            .width,
        greaterThan(90),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
