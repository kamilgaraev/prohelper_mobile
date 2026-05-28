import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/widgets/pro_operational_page.dart';
import 'package:prohelpers_mobile/core/widgets/pro_record_card.dart';
import 'package:prohelpers_mobile/core/widgets/pro_section.dart';
import 'attendance_history_screen.dart';
import 'attendance_scan_screen.dart';
import 'employee_attendance_qr_screen.dart';
import 'self_attendance_screen.dart';

class WorkforceAttendanceScreen extends StatelessWidget {
  const WorkforceAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProOperationalPage(
      title: 'Явка сотрудников',
      subtitle: 'QR, подтверждение и история отметок',
      children: [
        ProSectionBlock(
          title: 'Быстрые сценарии',
          subtitle: 'Выберите действие без перехода через лишние меню.',
          children: [
            ProRecordCard(
              icon: Icons.how_to_reg_rounded,
              title: 'Отметить мою явку',
              subtitle:
                  'Выберите дату и сохраните присутствие от своего имени.',
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SelfAttendanceScreen(),
                    ),
                  ),
            ),
            ProRecordCard(
              icon: Icons.qr_code_2_rounded,
              title: 'Мой QR для явки',
              subtitle:
                  'Покажите код ответственному сотруднику для подтверждения.',
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EmployeeAttendanceQrScreen(),
                    ),
                  ),
            ),
            ProRecordCard(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Подтвердить явку по QR',
              subtitle:
                  'Отсканируйте QR сотрудника и зафиксируйте подтверждение.',
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AttendanceScanScreen(),
                    ),
                  ),
            ),
            ProRecordCard(
              icon: Icons.history_rounded,
              title: 'История явки',
              subtitle: 'Проверьте сохраненные записи за выбранный период.',
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AttendanceHistoryScreen(),
                    ),
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
