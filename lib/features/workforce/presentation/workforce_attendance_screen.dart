import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../../core/widgets/pro_card.dart';
import 'attendance_history_screen.dart';
import 'attendance_scan_screen.dart';
import 'employee_attendance_qr_screen.dart';
import 'self_attendance_screen.dart';

class WorkforceAttendanceScreen extends StatelessWidget {
  const WorkforceAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Явка сотрудников'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _ActionCard(
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
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.qr_code_2_rounded,
              title: 'Мой QR для явки',
              subtitle:
                  'Выберите дату и покажите код ответственному сотруднику для подтверждения.',
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EmployeeAttendanceQrScreen(),
                    ),
                  ),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Подтвердить явку по QR',
              subtitle:
                  'Отсканируйте QR сотрудника и зафиксируйте подтверждение в табеле.',
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AttendanceScanScreen(),
                    ),
                  ),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.history_rounded,
              title: 'История явки',
              subtitle:
                  'Выберите период и проверьте сохраненные записи по явке.',
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AttendanceHistoryScreen(),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ProCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyLarge(context)),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: AppTypography.bodyMedium(
                    context,
                  ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
