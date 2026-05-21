import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_widget_model.dart';

void main() {
  group('DashboardWidgetModel.fromJson', () {
    test('читает новый контракт карточки дашборда', () {
      final widget = DashboardWidgetModel.fromJson({
        'slug': 'quality_control',
        'title': 'Контроль качества',
        'status': 'attention',
        'primary_metric': {'label': 'Открыто', 'value': 4},
        'secondary_metric': {'label': 'Просрочено', 'value': 1},
        'route': 'quality-control',
        'updated_at': '2026-05-21T10:00:00+03:00',
      });

      expect(widget.slug, 'quality_control');
      expect(widget.title, 'Контроль качества');
      expect(widget.status, DashboardWidgetStatus.attention);
      expect(widget.primaryMetric.label, 'Открыто');
      expect(widget.primaryMetric.displayValue, '4');
      expect(widget.secondaryMetric.label, 'Просрочено');
      expect(widget.secondaryMetric.displayValue, '1');
      expect(widget.route, 'quality-control');
      expect(widget.updatedAt.toIso8601String(), '2026-05-21T07:00:00.000Z');
    });

    test('отклоняет старый контракт карточки', () {
      expect(
        () => DashboardWidgetModel.fromJson({
          'type': 'warehouse',
          'order': 1,
          'title': 'Склад',
          'description': 'Складов: 4.',
          'payload': {
            'summary': {'warehouse_count': 4},
          },
        }),
        throwsFormatException,
      );
    });
  });
}
