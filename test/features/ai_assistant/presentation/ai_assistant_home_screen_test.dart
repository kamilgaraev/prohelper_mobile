import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_models.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:prohelpers_mobile/features/ai_assistant/presentation/ai_assistant_home_screen.dart';

void main() {
  testWidgets('new chat button follows the intro at compact large text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiAssistantRepositoryProvider.overrideWithValue(_Repository()),
        ],
        child: MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
          home: const AiAssistantHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final intro = find.textContaining('прошлым разборам');
    final button = find.widgetWithText(FilledButton, 'Новый чат');
    expect(intro, findsOneWidget);
    expect(button, findsOneWidget);
    expect(
      tester.getTopLeft(button).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(intro).dy),
    );
    expect(tester.takeException(), isNull);
  });
}

class _Repository extends AiAssistantRepository {
  _Repository() : super(Dio());

  @override
  Future<AiAssistantHomeModel> fetchHome() async => const AiAssistantHomeModel(
    usage: AiUsageModel(
      monthlyLimit: 100,
      used: 0,
      remaining: 100,
      percentageUsed: 0,
    ),
    conversations: [],
  );
}
