import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/app_action_buttons.dart';
import 'package:prohelpers_mobile/core/widgets/pro_status_banner.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/auth/data/quick_unlock_service.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';

class LockScreen extends HookConsumerWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authProvider);
    final passwordController = useTextEditingController();
    final pinController = useTextEditingController();
    final showPassword = useState(false);
    if (state is! AuthLocked) return const SizedBox.shrink();

    final notifier = ref.read(authProvider.notifier);
    final busy = state.isSubmitting;
    final message = state.message;
    final isWarning = message != null && state.messageIsError;

    void submitPassword() {
      if (busy || passwordController.text.isEmpty) return;
      FocusScope.of(context).unfocus();
      notifier.reauthenticate(passwordController.text);
    }

    void submitPin() {
      if (busy || !QuickUnlockService.isValidPin(pinController.text)) return;
      FocusScope.of(context).unfocus();
      final pin = pinController.text;
      pinController.clear();
      notifier.unlockWithPin(pin);
    }

    Future<void> signOut() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Выйти из аккаунта?'),
              content: const Text(
                'Изменения, которые ещё не отправлены с этого телефона, будут удалены.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Остаться'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    foregroundColor:
                        Theme.of(dialogContext).colorScheme.onError,
                  ),
                  child: const Text('Выйти и удалить'),
                ),
              ],
            ),
      );
      if (confirmed == true) await notifier.logout();
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Вход в МОСТ', style: AppTypography.h2(context)),
                  const SizedBox(height: 6),
                  Text(
                    state.lockedUser.name.isNotEmpty
                        ? '${state.lockedUser.name}, ${state.lockedUser.email}'
                        : state.lockedUser.email,
                    style: AppTypography.caption(context),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: ProSpacing.md),
                    ProStatusBanner(
                      title: message,
                      tone:
                          isWarning ? ProStatusTone.danger : ProStatusTone.info,
                      fullText: true,
                    ),
                  ],
                  const SizedBox(height: ProSpacing.lg),
                  ProSurface(
                    tone: ProSurfaceTone.elevated,
                    padding: const EdgeInsets.all(ProSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Войти с паролем',
                          style: AppTypography.bodyLarge(
                            context,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: ProSpacing.sm),
                        TextField(
                          controller: passwordController,
                          obscureText: !showPassword.value,
                          enabled: !busy,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => submitPassword(),
                          decoration: InputDecoration(
                            labelText: 'Пароль',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip:
                                  showPassword.value
                                      ? 'Скрыть пароль'
                                      : 'Показать пароль',
                              onPressed:
                                  () =>
                                      showPassword.value = !showPassword.value,
                              icon: Icon(
                                showPassword.value
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: ProSpacing.md),
                        AppPrimaryActionButton(
                          label: 'Войти',
                          busyLabel: 'Входим',
                          leading: const Icon(Icons.login_rounded, size: 20),
                          isBusy: busy,
                          onPressed: busy ? null : submitPassword,
                        ),
                      ],
                    ),
                  ),
                  if (state.canUnlockOffline) ...[
                    const SizedBox(height: ProSpacing.md),
                    ProSurface(
                      tone: ProSurfaceTone.elevated,
                      padding: const EdgeInsets.all(ProSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Нет связи?',
                            style: AppTypography.bodyLarge(
                              context,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Продолжите работу на телефоне. Изменения отправятся после входа с паролем.',
                            style: AppTypography.caption(context),
                          ),
                          const SizedBox(height: ProSpacing.sm),
                          TextField(
                            controller: pinController,
                            enabled: !busy,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            maxLength: QuickUnlockService.pinLength,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) {
                              if (value.length ==
                                  QuickUnlockService.pinLength) {
                                submitPin();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'PIN-код',
                              counterText: '',
                              prefixIcon: Icon(Icons.pin_outlined),
                            ),
                          ),
                          if (state.canUseBiometrics) ...[
                            const SizedBox(height: ProSpacing.sm),
                            AppSecondaryActionButton(
                              label: 'Войти по отпечатку или лицу',
                              leading: const Icon(
                                Icons.fingerprint_rounded,
                                size: 20,
                              ),
                              onPressed:
                                  busy ? null : notifier.unlockWithBiometrics,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: ProSpacing.lg),
                  TextButton(
                    onPressed: busy ? null : signOut,
                    child: const Text('Выйти из аккаунта'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
