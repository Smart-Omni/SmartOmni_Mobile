import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../../auth/presentation/auth_controller.dart';
import 'account_providers.dart';

/// Thông báo ở màn đăng nhập sau khi đổi mật khẩu.
const passwordChangedReason = 'Đã đổi mật khẩu, vui lòng đăng nhập lại.';

/// Mở sheet "Đổi mật khẩu" (dùng chung, hiện ở C-40). Đổi xong thì đăng xuất:
/// BE thu hồi refresh token khi đổi mật khẩu, nên phiên cũ không gia hạn được.
Future<void> showChangePasswordSheet(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  final changed = await showSoBottomSheet<bool>(
    context: context,
    builder: (_) => const ChangePasswordSheet(),
  );
  if (changed ?? false) {
    await container
        .read(authControllerProvider.notifier)
        .logout(reason: passwordChangedReason);
  }
}

class ChangePasswordSheet extends ConsumerStatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  ConsumerState<ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(accountRepositoryProvider)
          .changePassword(
            currentPassword: _currentCtrl.text,
            newPassword: _newCtrl.text,
            confirmPassword: _confirmCtrl.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = AsyncValueView.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validateNew(String? v) {
    final rule = Validators.newPassword(v);
    if (rule != null) return rule;
    if (v == _currentCtrl.text) {
      return 'Mật khẩu mới phải khác mật khẩu hiện tại';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SoBottomSheet(
      title: 'Đổi mật khẩu',
      secondary: SoButton.secondary(
        label: l10n.cancel,
        onPressed: _busy ? null : () => Navigator.of(context).pop(false),
      ),
      primary: SoButton(
        key: const Key('change_password_submit'),
        label: 'Đổi mật khẩu',
        loading: _busy,
        onPressed: _submit,
      ),
      child: Form(
        key: _formKey,
        // Sau lần bấm đầu tiên: kiểm tra lại khi gõ để lỗi tự mất.
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoTextField(
              key: const Key('change_password_current'),
              label: 'Mật khẩu hiện tại',
              controller: _currentCtrl,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.required(v, field: 'Mật khẩu'),
            ),
            const SizedBox(height: SoSpace.s16),
            SoTextField(
              key: const Key('change_password_new'),
              label: 'Mật khẩu mới',
              controller: _newCtrl,
              obscureText: true,
              helper: l10n.newPasswordHelper,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              validator: _validateNew,
            ),
            const SizedBox(height: SoSpace.s16),
            SoTextField(
              key: const Key('change_password_confirm'),
              label: l10n.confirmPassword,
              controller: _confirmCtrl,
              obscureText: true,
              textInputAction: TextInputAction.done,
              validator: (v) => Validators.confirmPassword(v, _newCtrl.text),
            ),
            const SizedBox(height: SoSpace.s16),
            const SoBanner(
              tone: SoBannerTone.info,
              title: 'Bạn sẽ cần đăng nhập lại',
              message:
                  'Đổi xong, app đăng xuất để bạn đăng nhập bằng mật khẩu '
                  'mới.',
            ),
            if (_error != null) ...[
              const SizedBox(height: SoSpace.s12),
              SoBanner(
                key: const Key('change_password_error'),
                tone: SoBannerTone.danger,
                title: 'Chưa đổi được mật khẩu',
                message: _error,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
