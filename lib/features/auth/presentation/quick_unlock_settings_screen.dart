import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/app_action_buttons.dart';
import 'package:prohelpers_mobile/core/widgets/pro_status_banner.dart';
import 'package:prohelpers_mobile/features/auth/data/biometric_unlock.dart';
import 'package:prohelpers_mobile/features/auth/data/quick_unlock_service.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';

Future<void> openQuickUnlockSettings(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const QuickUnlockSettingsScreen()),
  );
}

Future<void> offerQuickUnlockSetup(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(authProvider.notifier);
  final status = await notifier.quickUnlockStatus();
  if (status.configured || status.offered || !context.mounted) return;
  await notifier.markQuickUnlockOffered();
  if (!context.mounted) return;
  final accepted = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Вход без связи'),
          content: const Text(
            'Задайте PIN-код, чтобы продолжить работу, если сессия завершится, а интернета не будет. Изменить это можно в профиле.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Не сейчас'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Настроить'),
            ),
          ],
        ),
  );
  if (accepted == true && context.mounted) {
    await openQuickUnlockSettings(context);
  }
}

class QuickUnlockSettingsScreen extends HookConsumerWidget {
  const QuickUnlockSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(authProvider.notifier);
    final reload = useState(0);
    final statusFuture = useMemoized(() => notifier.quickUnlockStatus(), [
      reload.value,
    ]);
    final status = useFuture(statusFuture);
    final editing = useState(false);
    final busy = useState(false);
    final error = useState<String?>(null);
    final pinController = useTextEditingController();
    final confirmController = useTextEditingController();
    final useBiometrics = useState(false);

    final data = status.data;
    final biometricAvailable =
        data?.biometricAvailability == BiometricAvailability.available;
    final showForm = data != null && (!data.configured || editing.value);

    Future<void> run(Future<void> Function() action) async {
      if (busy.value) return;
      busy.value = true;
      error.value = null;
      try {
        await action();
      } catch (_) {
        error.value = 'Не удалось сохранить настройку. Попробуйте еще раз.';
      } finally {
        busy.value = false;
        reload.value++;
      }
    }

    Future<void> savePin() async {
      final pin = pinController.text;
      if (!QuickUnlockService.isValidPin(pin)) {
        error.value =
            'PIN-код должен состоять из ${QuickUnlockService.pinLength} цифр.';
        return;
      }
      if (pin != confirmController.text) {
        error.value = 'PIN-коды не совпадают.';
        return;
      }
      await run(() async {
        await notifier.setupQuickUnlock(
          pin,
          enableBiometrics: biometricAvailable && useBiometrics.value,
        );
        pinController.clear();
        confirmController.clear();
        editing.value = false;
      });
    }

    Future<void> toggleBiometrics(bool enabled) => run(() async {
      if (enabled) {
        final ok = await notifier.enableBiometricUnlock();
        if (!ok) {
          error.value =
              'Вход по отпечатку или лицу не включён. Попробуйте еще раз.';
        }
      } else {
        await notifier.disableBiometricUnlock();
      }
    });

    Future<void> turnOff() => run(() async {
      await notifier.disableQuickUnlock();
      editing.value = false;
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Вход без связи')),
      body: SafeArea(
        child:
            data == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                  padding: const EdgeInsets.all(ProSpacing.lg),
                  children: [
                    Text(
                      'Если сессия завершится, а интернета не будет, войдите по PIN-коду и продолжайте работу. Изменения отправятся после входа с паролем.',
                      style: AppTypography.bodyMedium(context),
                    ),
                    const SizedBox(height: ProSpacing.xs),
                    Text(
                      'Без связи вход доступен до 14 дней с последнего подключения. После ${QuickUnlockService.maxAttempts} неверных PIN-кодов данные входа на телефоне удаляются.',
                      style: AppTypography.caption(context),
                    ),
                    if (error.value != null) ...[
                      const SizedBox(height: ProSpacing.md),
                      ProStatusBanner(
                        title: error.value!,
                        tone: ProStatusTone.danger,
                        fullText: true,
                      ),
                    ],
                    const SizedBox(height: ProSpacing.lg),
                    if (showForm) ...[
                      _PinField(
                        controller: pinController,
                        label: 'Новый PIN-код',
                        enabled: !busy.value,
                      ),
                      const SizedBox(height: ProSpacing.sm),
                      _PinField(
                        controller: confirmController,
                        label: 'Повторите PIN-код',
                        enabled: !busy.value,
                      ),
                      if (biometricAvailable && !data.configured) ...[
                        const SizedBox(height: ProSpacing.sm),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Входить по отпечатку или лицу'),
                          value: useBiometrics.value,
                          onChanged:
                              busy.value
                                  ? null
                                  : (value) => useBiometrics.value = value,
                        ),
                      ],
                      const SizedBox(height: ProSpacing.md),
                      AppPrimaryActionButton(
                        label: 'Сохранить PIN-код',
                        busyLabel: 'Сохраняем',
                        isBusy: busy.value,
                        onPressed: busy.value ? null : savePin,
                      ),
                      if (data.configured) ...[
                        const SizedBox(height: ProSpacing.xs),
                        TextButton(
                          onPressed:
                              busy.value ? null : () => editing.value = false,
                          child: const Text('Отмена'),
                        ),
                      ],
                    ] else ...[
                      const ProStatusBanner(
                        title: 'Вход по PIN-коду включён',
                        tone: ProStatusTone.success,
                      ),
                      if (biometricAvailable) ...[
                        const SizedBox(height: ProSpacing.sm),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Входить по отпечатку или лицу'),
                          value: data.biometricEnabled,
                          onChanged: busy.value ? null : toggleBiometrics,
                        ),
                      ],
                      const SizedBox(height: ProSpacing.md),
                      AppSecondaryActionButton(
                        label: 'Сменить PIN-код',
                        onPressed:
                            busy.value ? null : () => editing.value = true,
                      ),
                      const SizedBox(height: ProSpacing.sm),
                      TextButton(
                        onPressed: busy.value ? null : turnOff,
                        child: const Text('Отключить вход без связи'),
                      ),
                    ],
                  ],
                ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.label,
    required this.enabled,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: QuickUnlockService.pinLength,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        prefixIcon: const Icon(Icons.pin_outlined),
      ),
    );
  }
}
