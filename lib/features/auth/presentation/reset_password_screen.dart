import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/app_config.dart';
import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../data/auth_mock_repository.dart';
import '../domain/auth_failure.dart';
import 'auth_controller.dart';

/// A-04 Đặt lại mật khẩu: mã trong email + mật khẩu mới (≥ 8 ký tự).
/// Thành công -> về A-02 kèm toast "Đã đặt lại mật khẩu".
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  ResetFailure? _failure;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(
            token: _codeCtrl.text.trim(),
            newPassword: _passwordCtrl.text,
          );
      if (!mounted) return;
      showSoToast(context, context.l10n.resetPasswordDone);
      context.go(Routes.login);
    } on ApiException catch (e) {
      if (mounted) setState(() => _failure = ResetFailure.fromApi(e));
    } catch (e) {
      if (mounted) {
        setState(
          () => _failure = ResetFailure(
            ResetFailureKind.other,
            AsyncValueView.errorMessage(e),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _resendCode() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.forgotPassword);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final useMock = ref.watch(appConfigProvider).useMock;
    final failure = _failure;

    return Scaffold(
      appBar: SoAppBar(title: l10n.resetPasswordTitle),
      bottomNavigationBar: SoActionBar(
        primary: SoButton(
          key: const Key('reset_submit'),
          label: l10n.resetPasswordButton,
          loading: _busy,
          onPressed: _save,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(SoSpace.screen),
          children: [
            Text(l10n.resetPasswordHint, style: context.textTheme.bodyMedium),
            const SizedBox(height: SoSpace.s24),
            if (failure != null &&
                failure.kind != ResetFailureKind.invalidCode) ...[
              SoBanner(
                key: const Key('reset_error'),
                tone: SoBannerTone.danger,
                title: failure.kind == ResetFailureKind.expired
                    ? l10n.resetCodeExpiredTitle
                    : l10n.resetFailedTitle,
                message: failure.kind == ResetFailureKind.expired
                    ? l10n.resetCodeExpiredMessage
                    : failure.message,
                actionLabel: failure.kind == ResetFailureKind.expired
                    ? l10n.resetResendCode
                    : null,
                onAction: _resendCode,
              ),
              const SizedBox(height: SoSpace.s16),
            ],
            SoTextField(
              key: const Key('reset_code'),
              label: l10n.resetToken,
              controller: _codeCtrl,
              mono: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.oneTimeCode],
              helper: useMock
                  ? l10n.resetMockHint(
                      MockAccounts.resetCode,
                      MockAccounts.expiredResetCode,
                    )
                  : null,
              errorText: failure?.kind == ResetFailureKind.invalidCode
                  ? l10n.resetCodeInvalid
                  : null,
              errorKey: const Key('reset_code_error'),
              onChanged: (_) {
                if (failure != null) setState(() => _failure = null);
              },
              validator: (v) => Validators.required(v, field: l10n.resetToken),
            ),
            const SizedBox(height: SoSpace.s16),
            SoTextField(
              key: const Key('reset_password'),
              label: l10n.newPassword,
              controller: _passwordCtrl,
              obscureText: true,
              helper: l10n.newPasswordHelper,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              validator: Validators.newPassword,
            ),
            const SizedBox(height: SoSpace.s16),
            SoTextField(
              key: const Key('reset_confirm'),
              label: l10n.confirmPassword,
              controller: _confirmCtrl,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _save(),
              validator: (v) =>
                  Validators.confirmPassword(v, _passwordCtrl.text),
            ),
          ],
        ),
      ),
    );
  }
}
