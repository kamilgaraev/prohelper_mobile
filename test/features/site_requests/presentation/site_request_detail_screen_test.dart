import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_request_detail_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_request_detail_screen.dart';

class _FakeSiteRequestsRepository extends SiteRequestsRepository {
  _FakeSiteRequestsRepository() : super(Dio());

  @override
  Future<SiteRequestModel> fetchSiteRequestDetails(int id) async {
    return _request;
  }
}

final _request = SiteRequestModel()
  ..serverId = 1001
  ..title = 'Срочно нужен бетон'
  ..description = 'Нужно закрыть подачу бетона до конца смены.'
  ..notes = 'Подтвердить время поставки до 14:00.'
  ..status = 'draft'
  ..statusLabel = 'Черновик'
  ..priority = 'urgent'
  ..priorityLabel = 'Срочно'
  ..requestType = 'material_request'
  ..requestTypeLabel = 'Материалы'
  ..materialName = 'Бетон М300'
  ..materialQuantity = 12
  ..materialUnit = 'м3'
  ..projectId = 15
  ..projectName = 'Дом 300м Царево'
  ..canBeEdited = true
  ..userName = 'Иван Петров'
  ..assignedUserName = 'Снабжение'
  ..requiredDate = '2026-03-15'
  ..groupTitle = 'Материалы на фундамент'
  ..groupRequestCount = 2
  ..groupItems = const [
    SiteRequestGroupItem(
      id: 1001,
      title: 'Бетон М300',
      status: 'draft',
      statusLabel: 'Черновик',
      requestType: 'material_request',
      requestTypeLabel: 'Материалы',
      materialName: 'Бетон М300',
      materialQuantity: 12,
      materialUnit: 'м3',
      assignedUserName: 'Снабжение',
      isCurrent: true,
    ),
    SiteRequestGroupItem(
      id: 1002,
      title: 'Арматура А500',
      status: 'pending',
      statusLabel: 'На согласовании',
      requestType: 'material_request',
      requestTypeLabel: 'Материалы',
      materialName: 'Арматура А500',
      materialQuantity: 2,
      materialUnit: 'т',
    ),
  ]
  ..history = const [
    SiteRequestHistoryEntry(
      id: 1,
      action: 'created',
      actionLabel: 'Создана',
      userName: 'Иван Петров',
    ),
    SiteRequestHistoryEntry(
      id: 2,
      action: 'status_changed',
      actionLabel: 'Статус изменен',
      userName: 'Руководитель проекта',
      oldStatusLabel: 'Черновик',
      newStatusLabel: 'На согласовании',
      notes: 'Нужно ускорить поставку.',
    ),
  ]
  ..availableTransitions = const [
    SiteRequestTransition(status: 'pending'),
    SiteRequestTransition(status: 'cancelled'),
  ]
  ..createdAt = DateTime(2026, 3, 14);

void main() {
  Widget createWidget() {
    return ProviderScope(
      overrides: [
        siteRequestDetailProvider.overrideWith(
          (ref, id) => SiteRequestDetailNotifier(
            _FakeSiteRequestsRepository(),
            ref,
            id,
          ),
        ),
      ],
      child: const TickerMode(
        enabled: false,
        child: MaterialApp(
          home: SiteRequestDetailScreen(id: 1001),
        ),
      ),
    );
  }

  testWidgets('показывает ключевой контекст, группу и историю по заявке', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Срочно нужен бетон'), findsOneWidget);
    expect(find.text('Срочная заявка'), findsOneWidget);
    expect(find.text('Контекст заявки'), findsOneWidget);
    expect(find.text('Участники'), findsOneWidget);
    expect(find.text('Редактировать заявку'), findsOneWidget);
    expect(find.text('Состав заявки'), findsOneWidget);
    expect(find.text('История обработки'), findsOneWidget);
    expect(find.text('Отправить на согласование'), findsOneWidget);
    expect(find.text('Бетон М300'), findsWidgets);
    expect(find.text('Арматура А500'), findsOneWidget);
    expect(find.text('Дом 300м Царево'), findsOneWidget);
    expect(find.text('Иван Петров'), findsWidgets);
    expect(find.text('Подтвердить время поставки до 14:00.'), findsOneWidget);
  });
}
