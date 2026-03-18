import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_widget_model.dart';

void main() {
  group('DashboardWidgetModel.fromJson', () {
    test('подставляет warehouse fallback-тексты для translation keys', () {
      final widget = DashboardWidgetModel.fromJson({
        'type': 'warehouse',
        'order': 1,
        'title': 'mobile_dashboard.widgets.warehouse.title',
        'description': 'mobile_dashboard.widgets.warehouse.description',
        'payload': {
          'summary': {
            'warehouse_count': 4,
            'low_stock_count': 2,
          },
        },
      });

      expect(widget.title, 'Склад');
      expect(widget.description, 'Складов: 4. Низкий остаток: 2.');
    });
  });
}
