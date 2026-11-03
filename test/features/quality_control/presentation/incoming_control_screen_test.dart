import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/quality_control/data/incoming_control_model.dart';
import 'package:prohelpers_mobile/features/quality_control/domain/incoming_control_provider.dart';
import 'package:prohelpers_mobile/features/quality_control/presentation/incoming_control_screen.dart';

void main() {
  testWidgets(
    'карточка показывает уведомление о скрытых связях без чужих идентификаторов',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            incomingControlDetailProvider(11).overrideWith(
              (ref) async => IncomingControlModel.fromJson({
                'id': 11,
                'project_id': 4,
                'version': 2,
                'status': 'accepted',
                'material': {'name': 'Гвозди'},
                'available_actions': [],
              }),
            ),
            incomingControlHistoryProvider(11).overrideWith((ref) async => []),
            incomingControlDependenciesProvider(11).overrideWith(
              (ref) async => {
                'redacted': true,
                'redaction_notice': 'Часть связей скрыта в другой организации.',
                'balances': [],
                'movements': [],
                'journal_materials': [],
                'completed_works': [],
                'acts': [],
              },
            ),
          ],
          child: const MaterialApp(home: IncomingControlDetailScreen(id: 11)),
        ),
      );
      await tester.pumpAndSettle();
      final title = find.text('Использование и связанные документы');
      await tester.scrollUntilVisible(
        title,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(
        find.text('Часть связей скрыта в другой организации.'),
        findsOneWidget,
      );
      expect(find.textContaining('descendant_project_ids'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
