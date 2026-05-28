import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/app_action_buttons.dart';
import 'package:prohelpers_mobile/core/widgets/pro_status_banner.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final showPassword = useState(false);
    final localError = useState<String?>(null);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isLoading = authState is AuthLoading;
    final errorMessage =
        localError.value ?? (authState is AuthError ? authState.message : null);

    void submit() {
      final email = emailController.text.trim();
      final password = passwordController.text;

      if (email.isEmpty || password.isEmpty) {
        localError.value = 'Введите email и пароль.';
        return;
      }

      localError.value = null;
      ref.read(authProvider.notifier).login(email, password);
    }

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 56,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AutofillGroup(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _LoginBrandHeader(theme: theme),
                          const SizedBox(height: 28),
                          ProSurface(
                            tone: ProSurfaceTone.elevated,
                            padding: const EdgeInsets.all(ProSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Вход в систему',
                                  style: AppTypography.h2(context),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Используйте рабочую учетную запись ProHelper.',
                                  style: AppTypography.caption(context),
                                ),
                                const SizedBox(height: 20),
                                _LoginTextField(
                                  controller: emailController,
                                  label: 'Email',
                                  icon: Icons.mail_outline_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.email,
                                    AutofillHints.username,
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _LoginTextField(
                                  controller: passwordController,
                                  label: 'Пароль',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: !showPassword.value,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  onSubmitted: (_) => submit(),
                                  suffix: IconButton(
                                    tooltip:
                                        showPassword.value
                                            ? 'Скрыть пароль'
                                            : 'Показать пароль',
                                    onPressed:
                                        () =>
                                            showPassword.value =
                                                !showPassword.value,
                                    icon: Icon(
                                      showPassword.value
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                  ),
                                ),
                                if (errorMessage != null) ...[
                                  const SizedBox(height: 16),
                                  ProStatusBanner(
                                    title: 'Не удалось выполнить вход',
                                    description: errorMessage,
                                    tone: ProStatusTone.danger,
                                  ),
                                ],
                                const SizedBox(height: 22),
                                AppPrimaryActionButton(
                                  label: 'Войти',
                                  busyLabel: 'Входим',
                                  leading: const Icon(
                                    Icons.login_rounded,
                                    size: 20,
                                  ),
                                  onPressed: isLoading ? null : submit,
                                  isBusy: isLoading,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Если доступ не открывается, обратитесь к администратору организации.',
                            textAlign: TextAlign.center,
                            style: AppTypography.caption(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginBrandHeader extends StatelessWidget {
  const _LoginBrandHeader({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 86,
          height: 86,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(ProRadius.sm),
          ),
          child: Icon(
            Icons.construction_rounded,
            size: 42,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'PROHELPER',
          textAlign: TextAlign.center,
          style: AppTypography.h1(context).copyWith(fontSize: 32),
        ),
        const SizedBox(height: 4),
        Text(
          'Industrial management',
          textAlign: TextAlign.center,
          style: AppTypography.caption(context),
        ),
      ],
    );
  }
}

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      style: AppTypography.bodyLarge(context),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        suffixIcon: suffix,
      ),
    );
  }
}
