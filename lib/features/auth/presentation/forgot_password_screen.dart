import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import 'auth_controller.dart';

/// A-03 Quên mật khẩu (UC-03): nhập email để nhận mã đặt lại.
///
/// Luôn báo "Nếu email đã đăng ký…" để không tiết lộ email có tồn tại hay không.
/// Lưu ý: backend hiện chưa gửi email thật (TODO trong AuthService), nên khi
/// test local phải lấy mã trong bảng `password_reset_tokens`.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _sent = false;
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .forgotPassword(_emailCtrl.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) showSoToast(context, AsyncValueView.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: SoAppBar(title: l10n.forgotPasswordTitle),
      bottomNavigationBar: SoActionBar(
        primary: SoButton(
          key: const Key('forgot_submit'),
          label: _sent ? l10n.resetResendCode : l10n.sendResetLink,
          loading: _busy,
          onPressed: _send,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(SoSpace.screen),
          children: [
            Text(l10n.forgotPasswordHint, style: context.textTheme.bodyMedium),
            const SizedBox(height: SoSpace.s24),
            SoTextField(
              key: const Key('forgot_email'),
              label: l10n.email,
              controller: _emailCtrl,
              hint: 'ten@cuahang.vn',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.send,
              validator: Validators.email,
              onSubmitted: (_) => _send(),
            ),
            if (_sent) ...[
              const SizedBox(height: SoSpace.s24),
              SoBanner(
                key: const Key('forgot_sent'),
                tone: SoBannerTone.info,
                title: l10n.resetSentTitle,
                message: l10n.resetLinkSent,
                actionLabel: l10n.resetHaveCode,
                onAction: () => context.push(Routes.resetPassword),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
