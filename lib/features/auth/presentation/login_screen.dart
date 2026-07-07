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
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final emailFocusNode = useFocusNode();
    final passwordFocusNode = useFocusNode();
    final showPassword = useState(false);
    final autovalidateMode = useState(AutovalidateMode.disabled);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isLoading = authState is AuthLoading;
    final errorMessage = authState is AuthError ? authState.message : null;
    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final outerTopPadding = isKeyboardVisible ? ProSpacing.md : 28.0;
    final outerBottomPadding =
        isKeyboardVisible ? ProTouchTarget.comfortable : 28.0;
    final formPadding = isKeyboardVisible ? ProSpacing.md : ProSpacing.lg;
    final passwordVisibilityLabel =
        showPassword.value ? 'Скрыть пароль' : 'Показать пароль';

    void togglePasswordVisibility() {
      showPassword.value = !showPassword.value;
    }

    void clearSubmitError() {
      if (authState is AuthError) {
        ref.read(authProvider.notifier).clearError();
      }
    }

    void submit() {
      if (isLoading) {
        return;
      }

      final form = formKey.currentState;
      if (form == null || !form.validate()) {
        autovalidateMode.value = AutovalidateMode.onUserInteraction;
        if (emailController.text.trim().isEmpty) {
          emailFocusNode.requestFocus();
        } else {
          passwordFocusNode.requestFocus();
        }
        return;
      }

      final email = emailController.text.trim();
      final password = passwordController.text;
      FocusScope.of(context).unfocus();
      TextInput.finishAutofillContext();
      ref.read(authProvider.notifier).login(email, password);
    }

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                outerTopPadding,
                20,
                outerBottomPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      isKeyboardVisible
                          ? constraints.maxHeight
                          : constraints.maxHeight - 56,
                ),
                child: Align(
                  alignment:
                      isKeyboardVisible
                          ? Alignment.topCenter
                          : Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AutofillGroup(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!isKeyboardVisible) ...[
                            _LoginBrandHeader(theme: theme),
                            const SizedBox(height: 28),
                          ],
                          Form(
                            key: formKey,
                            autovalidateMode: autovalidateMode.value,
                            child: ProSurface(
                              tone: ProSurfaceTone.elevated,
                              padding: EdgeInsets.all(formPadding),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Вход в систему',
                                    style: AppTypography.h2(context),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Используйте рабочую учетную запись МОСТ.',
                                    style: AppTypography.caption(context),
                                  ),
                                  const SizedBox(height: 20),
                                  _LoginTextField(
                                    controller: emailController,
                                    focusNode: emailFocusNode,
                                    label: 'Email',
                                    icon: Icons.mail_outline_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    enableIMEPersonalizedLearning: false,
                                    smartDashesType: SmartDashesType.disabled,
                                    smartQuotesType: SmartQuotesType.disabled,
                                    autofillHints: const [
                                      AutofillHints.email,
                                      AutofillHints.username,
                                    ],
                                    onChanged: (_) => clearSubmitError(),
                                    validator:
                                        (value) =>
                                            (value ?? '').trim().isEmpty
                                                ? 'Введите email'
                                                : null,
                                  ),
                                  const SizedBox(height: 14),
                                  _LoginTextField(
                                    controller: passwordController,
                                    focusNode: passwordFocusNode,
                                    label: 'Пароль',
                                    icon: Icons.lock_outline_rounded,
                                    obscureText: !showPassword.value,
                                    textInputAction: TextInputAction.done,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    enableIMEPersonalizedLearning: false,
                                    smartDashesType: SmartDashesType.disabled,
                                    smartQuotesType: SmartQuotesType.disabled,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    onChanged: (_) => clearSubmitError(),
                                    onSubmitted: (_) => submit(),
                                    validator:
                                        (value) =>
                                            (value ?? '').isEmpty
                                                ? 'Введите пароль'
                                                : null,
                                    suffix: Semantics(
                                      label: passwordVisibilityLabel,
                                      button: true,
                                      toggled: showPassword.value,
                                      onTap: togglePasswordVisibility,
                                      child: ExcludeSemantics(
                                        child: IconButton(
                                          tooltip: passwordVisibilityLabel,
                                          onPressed: togglePasswordVisibility,
                                          icon: Icon(
                                            showPassword.value
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                          ),
                                        ),
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
                          ),
                          if (!isKeyboardVisible) ...[
                            const SizedBox(height: 18),
                            Text(
                              'Если доступ не открывается, обратитесь к администратору организации.',
                              textAlign: TextAlign.center,
                              style: AppTypography.caption(context),
                            ),
                          ],
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
        const _MostLogoMark(size: 86),
        const SizedBox(height: 18),
        Text(
          'МОСТ',
          textAlign: TextAlign.center,
          style: AppTypography.h1(context).copyWith(fontSize: 32),
        ),
        const SizedBox(height: 4),
        Text(
          'Управление строительством',
          textAlign: TextAlign.center,
          style: AppTypography.caption(context),
        ),
      ],
    );
  }
}

class _MostLogoMark extends StatelessWidget {
  const _MostLogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Логотип МОСТ',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF0B0F14),
          borderRadius: BorderRadius.circular(ProRadius.sm),
        ),
        child: CustomPaint(painter: _MostLogoPainter()),
      ),
    );
  }
}

class _MostLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    final whitePaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12 * scale
          ..strokeCap = StrokeCap.square
          ..strokeJoin = StrokeJoin.miter;
    final orangePaint =
        Paint()
          ..color = const Color(0xFFFF8A00)
          ..style = PaintingStyle.fill;
    final orangeLinePaint =
        Paint()
          ..color = const Color(0xFFFF8A00)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * scale
          ..strokeCap = StrokeCap.square;

    Offset point(double x, double y) => Offset(x * scale, y * scale);
    Rect rect(double left, double top, double right, double bottom) =>
        Rect.fromLTRB(
          left * scale,
          top * scale,
          right * scale,
          bottom * scale,
        );

    final mark =
        Path()
          ..moveTo(20 * scale, 69 * scale)
          ..lineTo(20 * scale, 28 * scale)
          ..lineTo(50 * scale, 50 * scale)
          ..lineTo(80 * scale, 28 * scale)
          ..lineTo(80 * scale, 69 * scale);

    canvas.drawPath(mark, whitePaint);
    canvas.drawRect(rect(13, 74, 27, 88), orangePaint);
    canvas.drawRect(rect(73, 74, 87, 88), orangePaint);
    canvas.drawLine(point(20, 81), point(80, 81), orangeLinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.focusNode,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.enableIMEPersonalizedLearning = true,
    this.smartDashesType,
    this.smartQuotesType,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FocusNode? focusNode;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool enableIMEPersonalizedLearning;
  final SmartDashesType? smartDashesType;
  final SmartQuotesType? smartQuotesType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collapseFieldSemantics = suffix == null;

    final textField = TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      enableIMEPersonalizedLearning: enableIMEPersonalizedLearning,
      smartDashesType: smartDashesType,
      smartQuotesType: smartQuotesType,
      autofillHints: autofillHints,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: AppTypography.bodyLarge(context),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        suffixIcon: suffix,
      ),
    );

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      child: textField,
      builder: (context, value, child) {
        return Semantics(
          container: true,
          excludeSemantics: collapseFieldSemantics,
          label: 'Поле ввода: $label',
          value:
              obscureText && value.text.isNotEmpty
                  ? 'Введено символов: ${value.text.length}'
                  : value.text,
          textField: true,
          enabled: true,
          focusable: true,
          focused: focusNode?.hasFocus,
          obscured: obscureText,
          currentValueLength: value.text.length,
          onTap: focusNode?.requestFocus,
          onSetText: (text) {
            controller.value = TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
            );
            onChanged?.call(text);
          },
          child: child,
        );
      },
    );
  }
}
