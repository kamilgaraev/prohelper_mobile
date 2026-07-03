import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_widget_model.dart';
import 'package:prohelpers_mobile/features/dashboard/presentation/controllers/dashboard_controller.dart';

void main() {
  test(
    'loadDashboard keeps last successful widgets after refresh failure',
    () async {
      final repository = _SequenceDashboardRepository([
        _DashboardResult.widgets([_widget('project_overview')]),
        _DashboardResult.error(
          const ApiException('Нет соединения с сервером.'),
        ),
      ]);
      final controller = DashboardController(repository, canLoad: false);

      await controller.loadDashboard();

      expect(controller.state.widgets.map((widget) => widget.slug), [
        'project_overview',
      ]);
      expect(controller.state.error, isNull);

      await controller.loadDashboard();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.widgets.map((widget) => widget.slug), [
        'project_overview',
      ]);
      expect(controller.state.error, isNull);
    },
  );

  test(
    'loadDashboard exposes error when no dashboard data exists yet',
    () async {
      final repository = _SequenceDashboardRepository([
        _DashboardResult.error(
          const ApiException('Нет соединения с сервером.'),
        ),
      ]);
      final controller = DashboardController(repository, canLoad: false);

      await controller.loadDashboard();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.widgets, isEmpty);
      expect(controller.state.error, 'Нет соединения с сервером.');
    },
  );
}

class _SequenceDashboardRepository extends DashboardRepository {
  _SequenceDashboardRepository(this._results) : super(Dio());

  final List<_DashboardResult> _results;
  var _index = 0;

  @override
  Future<List<DashboardWidgetModel>> fetchWidgets() async {
    final result = _results[_index++];

    if (result.error != null) {
      throw result.error!;
    }

    return result.widgets;
  }
}

class _DashboardResult {
  const _DashboardResult._({this.widgets = const [], this.error});

  factory _DashboardResult.widgets(List<DashboardWidgetModel> widgets) {
    return _DashboardResult._(widgets: widgets);
  }

  factory _DashboardResult.error(Object error) {
    return _DashboardResult._(error: error);
  }

  final List<DashboardWidgetModel> widgets;
  final Object? error;
}

DashboardWidgetModel _widget(String slug) {
  return DashboardWidgetModel(
    slug: slug,
    title: slug,
    status: DashboardWidgetStatus.ok,
    primaryMetric: const DashboardMetric(label: 'Сигналы', value: 0),
    secondaryMetric: const DashboardMetric(label: 'Просрочено', value: 0),
    route: slug,
    updatedAt: DateTime(2026, 7, 3),
  );
}
