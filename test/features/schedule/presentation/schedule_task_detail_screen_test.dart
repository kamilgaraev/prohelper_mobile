import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/schedule/presentation/schedule_task_detail_screen.dart';

void main() {
  test(
    'edit requires server action, project context, permission and module',
    () {
      bool allowed({
        List<String> actions = const ['update'],
        int? actionProjectId = 7,
        int? selectedProjectId = 7,
        bool hasPermission = true,
        bool hasModule = true,
      }) => canEditScheduleTask(
        allowedActions: actions,
        actionProjectId: actionProjectId,
        selectedProjectId: selectedProjectId,
        hasPermission: hasPermission,
        hasModule: hasModule,
      );

      expect(allowed(), isTrue);
      expect(allowed(actions: const []), isFalse);
      expect(allowed(actionProjectId: 8), isFalse);
      expect(allowed(selectedProjectId: null), isFalse);
      expect(allowed(hasPermission: false), isFalse);
      expect(allowed(hasModule: false), isFalse);
    },
  );
}
