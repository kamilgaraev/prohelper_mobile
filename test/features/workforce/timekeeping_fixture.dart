Map<String, dynamic> timekeepingFixture({
  int id = 7,
  int revision = 1,
  String status = 'draft',
  int minutes = 0,
}) => {
  'id': id,
  'month': '2026-09',
  'status': status,
  'revision': revision,
  'project_id': null,
  'summary': {'fact_minutes': minutes, 'employee_count': 1},
  'actions': [
    {'code': 'submit', 'enabled': status == 'draft', 'reason': null},
    {'code': 'reopen', 'enabled': status == 'closed', 'reason': null},
    {'code': 'approve', 'enabled': status == 'verified', 'reason': null},
  ],
  'documents': [],
  'rows': [
    {
      'employee_id': 12,
      'full_name': 'Иван Петров',
      'personnel_number': '001',
      'accounting_mode': 'hours',
      'summary': {'fact_minutes': minutes},
      'days': [
        for (var day = 1; day <= 30; day++)
          {
            'work_date': '2026-09-${day.toString().padLeft(2, '0')}',
            'planned_minutes': 480,
            'fact_minutes': day == 2 ? minutes : 0,
            'intervals': [],
            'sources': [],
            'issues': [],
          },
      ],
    },
  ],
};
