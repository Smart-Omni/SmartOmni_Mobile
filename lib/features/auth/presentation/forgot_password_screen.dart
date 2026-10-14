import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import 'auth_controller.dart';

/// Quên mật khẩu (UC-03): gửi email -> nhập mã xác nhận + mật khẩu mới.
///
/// Lưu ý: backend hiện chưa gửi email thật (TODO trong AuthService), nên
/// mã xác nhận phải lấy từ bảng `password_reset_tokens` khi test local.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _requested = false;
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _tokenCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _request() => _run(() async {
    await ref
        .read(authRepositoryProvider)
        .forgotPassword(_emailCtrl.text.trim());
    if (!mounted) return;
    showInfoSnackBar(context, context.l10n.resetLinkSent);
    setState(() => _requested = true);
  });

  Future<void> _reset() => _run(() async {
    await ref
        .read(authRepositoryProvider)
        .resetPassword(
          token: _tokenCtrl.text.trim(),
          newPassword: _passwordCtrl.text,
        );
    if (!mounted) return;
    showInfoSnackBar(context, context.l10n.resetPasswordDone);
    context.go(Routes.login);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _requested ? l10n.resetPasswordTitle : l10n.forgotPasswordTitle,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (!_requested) ...[
              Text(l10n.forgotPasswordHint),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.email),
                validator: Validators.email,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _request,
                child: Text(l10n.sendResetLink),
              ),
            ] else ...[
              TextFormField(
                controller: _tokenCtrl,
                decoration: InputDecoration(labelText: l10n.resetToken),
                validator: (v) =>
                    Validators.required(v, field: l10n.resetToken),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.newPassword),
                validator: Validators.newPassword,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _reset,
                child: Text(l10n.resetPasswordButton),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
