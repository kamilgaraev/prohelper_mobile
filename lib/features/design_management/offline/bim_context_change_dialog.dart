import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/widgets/app_error_notice.dart';
import 'bim_offline_provider.dart';

Future<bool> prepareBimContextChange(
  BuildContext context,
  WidgetRef ref,
) async {
  final service = await ref.read(bimOfflineServiceProvider.future);
  if (!context.mounted) return false;
  if (!await service.hasPending()) return true;
  if (!context.mounted) return false;
  final action = await showDialog<String>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Есть неотправленные замечания'),
          content: const Text(
            'Отправьте замечания перед выходом или сменой организации. При удалении замечания и вложения будут потеряны.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: const Text('Удалить и продолжить'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'sync'),
              child: const Text('Отправить'),
            ),
          ],
        ),
  );
  if (action == null || action == 'cancel') return false;
  try {
    if (action == 'sync') {
      await service.syncPending();
      if (await service.hasPending()) {
        throw StateError(
          'Не все замечания отправлены. Повторите отправку или отмените выход.',
        );
      }
    }
    await service.prepareContextChange(discard: action == 'discard');
    return true;
  } catch (error) {
    if (context.mounted) AppErrorNotice.show(context, error);
    return false;
  }
}
