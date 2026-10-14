import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/config/app_config.dart';
import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../data/auth_mock_repository.dart';
import '../domain/auth_failure.dart';
import 'auth_controller.dart';

/// A-02 Đăng nhập CHUNG cho mọi role.
/// Sau khi đăng nhập, router tự chuyển vào khu vực theo role (xem app_router.dart).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  LoginFailure? _failure;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// Khóa 15 phút: không cho bấm đăng nhập lại cho tới khi đổi email.
  bool get _locked => _failure?.kind == LoginFailureKind.temporarilyLocked;

  Future<void> _submit() async {
    if (_locked || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(email: _emailCtrl.text, password: _passwordCtrl.text);
      // Không cần điều hướng thủ công: router lắng nghe AuthState và tự chuyển trang.
    } on LoginFailure catch (e) {
      if (mounted) setState(() => _failure = e);
    } catch (e) {
      if (mounted) {
        setState(
          () => _failure = LoginFailure(
            LoginFailureKind.other,
            AsyncValueView.errorMessage(e),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _onEmailChanged(String _) {
    if (_failure != null) setState(() => _failure = null);
  }

  void _onPasswordChanged(String _) {
    if (_failure?.kind == LoginFailureKind.invalidCredentials) {
      setState(() => _failure = null);
    }
  }

  void _useAnotherAccount() {
    _emailCtrl.clear();
    _passwordCtrl.clear();
    setState(() => _failure = null);
  }

  void _fillDemo(String email) {
    _emailCtrl.text = email;
    _passwordCtrl.text = MockAccounts.password;
    setState(() => _failure = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final config = ref.watch(appConfigProvider);
    final authState = ref.watch(authControllerProvider);
    final expiredReason = authState is Unauthenticated
        ? authState.reason
        : null;
    final failure = _failure;
    final wrongPassword = failure?.kind == LoginFailureKind.invalidCredentials;

    return Scaffold(
      backgroundColor: context.soColors.surface,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              SoSpace.screen,
              SoSpace.s40,
              SoSpace.screen,
              SoSpace.s24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: SoLogo(),
                      ),
                      const SizedBox(height: SoSpace.s32),
                      Text(
                        l10n.loginTitle,
                        style: context.textTheme.titleLarge,
                      ),
                      const SizedBox(height: SoSpace.s4),
                      Text(
                        l10n.loginSubtitle,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.soColors.ink2,
                        ),
                      ),
                      const SizedBox(height: SoSpace.s24),
                      if (failure != null && !wrongPassword) ...[
                        _FailureBanner(
                          failure: failure,
                          onResetPassword: () =>
                              context.push(Routes.forgotPassword),
                        ),
                        const SizedBox(height: SoSpace.s16),
                      ] else if (expiredReason != null) ...[
                        SoBanner(tone: SoBannerTone.info, title: expiredReason),
                        const SizedBox(height: SoSpace.s16),
                      ],
                      SoTextField(
                        key: const Key('login_email'),
                        label: l10n.email,
                        controller: _emailCtrl,
                        hint: 'ten@cuahang.vn',
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        validator: Validators.email,
                        onChanged: _onEmailChanged,
                      ),
                      const SizedBox(height: SoSpace.s16),
                      SoTextField(
                        key: const Key('login_password'),
                        label: l10n.password,
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                        onChanged: _onPasswordChanged,
                        errorText: wrongPassword
                            ? l10n.loginWrongCredentials
                            : null,
                        errorKey: const Key('login_error'),
                        validator: (v) =>
                            Validators.required(v, field: l10n.password),
                        suffix: IconButton(
                          tooltip: _obscure
                              ? l10n.showPassword
                              : l10n.hidePassword,
                          icon: Icon(
                            _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                            color: context.soColors.ink2,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const Key('login_forgot'),
                          onPressed: () => context.push(Routes.forgotPassword),
                          child: Text(l10n.forgotPassword),
                        ),
                      ),
                      const SizedBox(height: SoSpace.s8),
                      SoButton(
                        key: const Key('login_submit'),
                        label: l10n.loginButton,
                        expand: true,
                        loading: _submitting,
                        onPressed: _locked ? null : _submit,
                      ),
                      if (failure?.kind == LoginFailureKind.superAdmin) ...[
                        const SizedBox(height: SoSpace.s12),
                        SoButton.secondary(
                          key: const Key('login_use_another'),
                          label: l10n.loginUseAnotherAccount,
                          expand: true,
                          onPressed: _useAnotherAccount,
                        ),
                      ],
                      if (config.useMock) ...[
                        const SizedBox(height: SoSpace.s32),
                        _DemoAccountsCard(onPick: _fillDemo),
                      ],
                      if (config.flavor == Flavor.dev)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            key: const Key('open_dev_gallery'),
                            onPressed: () => context.push(Routes.devGallery),
                            child: Text(l10n.devGalleryOpen),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner cho các lỗi không gắn với một ô nhập.
class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.failure, required this.onResetPassword});

  final LoginFailure failure;
  final VoidCallback onResetPassword;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const key = Key('login_error');
    return switch (failure.kind) {
      LoginFailureKind.temporarilyLocked => SoBanner(
        key: key,
        tone: SoBannerTone.warning,
        title: l10n.loginLockedTitle,
        message: l10n.loginLockedMessage,
        actionLabel: l10n.loginResetPasswordLink,
        onAction: onResetPassword,
      ),
      LoginFailureKind.accountDisabled => SoBanner(
        key: key,
        tone: SoBannerTone.danger,
        title: l10n.loginDisabledTitle,
        message: l10n.loginDisabledMessage,
      ),
      LoginFailureKind.tenantLocked => SoBanner(
        key: key,
        tone: SoBannerTone.danger,
        title: l10n.loginTenantLockedTitle,
        message: l10n.loginTenantLockedMessage,
      ),
      LoginFailureKind.superAdmin => SoBanner(
        key: key,
        tone: SoBannerTone.info,
        title: l10n.loginSuperAdminTitle,
        message: l10n.loginSuperAdminMessage,
      ),
      LoginFailureKind.invalidCredentials || LoginFailureKind.other => SoBanner(
        key: key,
        tone: SoBannerTone.danger,
        title: l10n.loginFailedTitle,
        message: failure.message,
      ),
    };
  }
}

/// Thẻ tài khoản demo (chỉ bản mock). Chạm email để điền sẵn.
class _DemoAccountsCard extends StatelessWidget {
  const _DemoAccountsCard({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Container(
      padding: SoSpace.card,
      decoration: BoxDecoration(
        color: c.ground,
        borderRadius: SoRadius.mdAll,
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.demoAccountsTitle, style: context.soText.overline),
          const SizedBox(height: SoSpace.s4),
          Text(
            context.l10n.demoAccountsHint(MockAccounts.password),
            style: context.textTheme.bodySmall,
          ),
          const SizedBox(height: SoSpace.s12),
          Wrap(
            spacing: SoSpace.s8,
            runSpacing: SoSpace.s8,
            children: [
              for (final email in MockAccounts.accounts.keys)
                InkWell(
                  key: Key('demo_$email'),
                  borderRadius: SoRadius.xsAll,
                  onTap: () => onPick(email),
                  child: SoCodeTag(email),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
