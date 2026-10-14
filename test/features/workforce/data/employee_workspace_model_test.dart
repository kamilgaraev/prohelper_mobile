import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/workforce/data/employee_workspace_model.dart';

void main() {
  test(
    'читает только собственные подтверждённые факты и безопасные документы',
    () {
      final value = EmployeeWorkspaceModel.fromJson({
        'employee': {'full_name': 'Иван Петров', 'personnel_number': '001'},
        'documents': [
          {
            'id': 1,
            'title': 'Трудовой договор',
            'evidence_kind': 'paper_signed',
          },
        ],
        'requests': [
          {
            'id': 7,
            'kind': 'absence',
            'status': 'awaiting_hr',
            'date_from': '2026-10-14',
            'date_to': '2026-10-15',
            'basis': 'Прошу отпуск',
          },
        ],
        'monthly_facts': {
          'periods': [
            {
              'id': 3,
              'status': 'approved',
              'employment_contract_id': 11,
              'contract_number': 'ТД-11',
              'days': [
                {
                  'work_date': '2026-10-14',
                  'fact_minutes': 480,
                  'planned_minutes': 480,
                },
              ],
            },
          ],
        },
      });
      expect(value.employeeName, 'Иван Петров');
      expect(value.documents.single.evidenceKind, 'paper_signed');
      expect(value.requests.single.status, 'awaiting_hr');
      expect(value.periods.single.days.single.factMinutes, 480);
      expect(value.periods.single.contractNumber, 'ТД-11');
      expect(value.periods.single.employmentContractId, 11);
    },
  );

  test('черновой табель нельзя представить как подтверждённый', () {
    expect(
      () =>
          EmployeeMonthModel.fromJson({'id': 3, 'status': 'draft', 'days': []}),
      throwsFormatException,
    );
  });
}
