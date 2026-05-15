import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/machinery_operations/data/machinery_operations_model.dart';

void main() {
  group('Machinery operations models', () {
    test('parses machinery asset with project and flags', () {
      final asset = MachineryAssetModel.fromJson({
        'id': 7,
        'asset_code': 'EXC-001',
        'name': 'Экскаватор',
        'status': 'assigned',
        'status_label': 'Назначен',
        'available_actions': ['start_operation'],
        'project_id': 9,
        'project': {'id': 9, 'name': 'Башня'},
        'problem_flags': [
          {'code': 'maintenance_due', 'severity': 'warning', 'message': 'Нужно ТО'},
        ],
      });

      expect(asset.name, 'Экскаватор');
      expect(asset.projectName, 'Башня');
      expect(asset.availableActions, ['start_operation']);
      expect(asset.problemFlags.single.code, 'maintenance_due');
    });

    test('parses shift report numeric values', () {
      final report = MachineryShiftReportModel.fromJson({
        'id': 11,
        'asset_id': 7,
        'project_id': 9,
        'report_date': '2026-06-01',
        'status': 'submitted',
        'status_label': 'На проверке',
        'actual_hours': '7.5',
        'fuel_consumed': 50,
        'available_actions': ['approve'],
        'asset': {'id': 7, 'name': 'Экскаватор'},
      });

      expect(report.actualHours, 7.5);
      expect(report.fuelConsumed, 50);
      expect(report.assetName, 'Экскаватор');
    });
  });
}
