import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/input_formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../l10n/l10n.dart';
import '../../customer_shop/presentation/shop_code_lookup.dart';
import '../domain/registration.dart';
import 'auth_controller.dart';
import 'register_otp_screen.dart';

/// A-05 Đăng ký tài khoản khách (DESIGN.md mục 8b): mã cửa hàng, thông tin
/// cá nhân, đồng ý điều khoản -> gửi OTP tới email -> màn OTP.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopKey = GlobalKey<ShopCodeLookupState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _agreed = false;
  bool _agreeError = false;
  bool _busy = false;
  String? _emailError;
  String? _shopError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final shop = await _shopKey.currentState!.resolve();
      if (!mounted) return;
      final valid = _formKey.currentState!.validate();
      setState(() => _agreeError = !_agreed);
      if (!valid || shop == null || !_agreed) return;

      final email = _emailCtrl.text.trim();
      await ref
          .read(registrationRepositoryProvider)
          .register(
            RegistrationRequest(
              shopCode: shop.code,
              fullName: _nameCtrl.text,
              email: email,
              phone: _phoneCtrl.text,
              password: _passwordCtrl.text,
            ),
          );
      if (!mounted) return;
      await context.push(
        Routes.registerVerify,
        extra: RegisterOtpArgs(email: email, shopName: shop.name),
      );
    } on RegisterFailure catch (f) {
      if (!mounted) return;
      switch (f.kind) {
        case RegisterFailureKind.emailTaken:
          setState(() => _emailError = f.message);
        case RegisterFailureKind.shopNotFound:
          setState(() => _shopError = f.message);
        case RegisterFailureKind.other:
          showSoToast(context, f.message);
      }
    } catch (_) {
      if (mounted) showSoToast(context, 'Kiểm tra kết nối mạng rồi thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _backToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.soColors;

    return Form(
      key: _formKey,
      child: SoScaffold(
        appBar: const SoAppBar(title: 'Tạo tài khoản khách'),
        bottomBar: SoActionBar(
          stacked: true,
          primary: SoButton(
            key: const Key('register_submit'),
            label: 'Tạo tài khoản',
            loading: _busy,
            onPressed: _submit,
          ),
          secondary: SoButton.ghost(
            key: const Key('register_login'),
            label: 'Đã có tài khoản? Đăng nhập',
            onPressed: _busy ? null : _backToLogin,
          ),
        ),
        slivers: [
          // Form: dựng hết các ô một lần để validate() thấy mọi ô.
          SliverPadding(
            padding: SoSpace.page,
            sliver: SliverToBoxAdapter(
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SoMockBanner(
                      message:
                          'Thử mã SHOPDEMO, HOAMOC hoặc BEPXINH. Email demo '
                          '(vd. customer@demo.vn) đã có tài khoản.',
                    ),
                    const SizedBox(height: SoSpace.s16),
                    Text(
                      'Nhập mã của cửa hàng bạn mua. Cửa hàng khác thêm sau '
                      'khi đã có tài khoản.',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: c.ink2,
                      ),
                    ),
                    const SizedBox(height: SoSpace.s16),
                    Container(
                      padding: SoSpace.card,
                      decoration: SoShape.card(c),
                      child: ShopCodeLookup(
                        key: _shopKey,
                        keyPrefix: 'register_shop',
                        errorText: _shopError,
                        onChanged: (_) {
                          if (_shopError != null) {
                            setState(() => _shopError = null);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: SoSpace.cardGap),
                    Container(
                      padding: SoSpace.card,
                      decoration: SoShape.card(c),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SoTextField(
                            key: const Key('register_name'),
                            label: 'Họ tên',
                            controller: _nameCtrl,
                            hint: 'Vd: Nguyễn Văn An',
                            autofillHints: const [AutofillHints.name],
                            textInputAction: TextInputAction.next,
                            validator: (v) =>
                                Validators.required(v, field: 'Họ tên'),
                          ),
                          const SizedBox(height: SoSpace.s16),
                          SoTextField(
                            key: const Key('register_email'),
                            label: l10n.email,
                            controller: _emailCtrl,
                            hint: 'ten@email.com',
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            validator: Validators.email,
                            errorText: _emailError,
                            errorKey: const Key('register_email_error'),
                            onChanged: (_) {
                              if (_emailError != null) {
                                setState(() => _emailError = null);
                              }
                            },
                          ),
                          const SizedBox(height: SoSpace.s16),
                          SoTextField(
                            key: const Key('register_phone'),
                            label: 'Số điện thoại',
                            controller: _phoneCtrl,
                            hint: 'Vd: 0901234567',
                            keyboardType: TextInputType.phone,
                            autofillHints: const [
                              AutofillHints.telephoneNumber,
                            ],
                            inputFormatters: phoneFormatters,
                            textInputAction: TextInputAction.next,
                            validator: Validators.phone,
                          ),
                          const SizedBox(height: SoSpace.s16),
                          SoTextField(
                            key: const Key('register_password'),
                            label: l10n.password,
                            controller: _passwordCtrl,
                            obscureText: _obscure,
                            helper: l10n.newPasswordHelper,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: Validators.newPassword,
                            suffix: IconButton(
                              tooltip: _obscure
                                  ? l10n.showPassword
                                  : l10n.hidePassword,
                              icon: Icon(
                                _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                                color: c.ink2,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: SoSpace.s8),
                    _TermsRow(
                      agreed: _agreed,
                      showError: _agreeError && !_agreed,
                      onChanged: (v) => setState(() => _agreed = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ô đồng ý điều khoản: chạm cả hàng để tick. Chưa tick mà bấm "Tạo tài
/// khoản" thì báo lỗi ngay dưới.
class _TermsRow extends StatelessWidget {
  const _TermsRow({
    required this.agreed,
    required this.showError,
    required this.onChanged,
  });

  final bool agreed;
  final bool showError;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const Key('register_terms'),
          customBorder: SoShape.squircle(SoRadius.mdAll),
          onTap: () => onChanged(!agreed),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: SoSize.touch),
            child: Row(
              children: [
                Checkbox(
                  value: agreed,
                  activeColor: c.brand,
                  side: BorderSide(
                    color: showError ? c.danger : c.muted,
                    width: 1.5,
                  ),
                  onChanged: (v) => onChanged(v ?? false),
                ),
                Expanded(
                  child: Text(
                    'Tôi đồng ý với Điều khoản sử dụng và Chính sách quyền '
                    'riêng tư.',
                    style: context.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(left: SoSize.touch),
            child: Text(
              'Hãy đồng ý điều khoản để tạo tài khoản.',
              key: const Key('register_terms_error'),
              style: context.textTheme.bodySmall?.copyWith(color: c.danger),
            ),
          ),
      ],
    );
  }
}
