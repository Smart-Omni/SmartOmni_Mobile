import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';
import '../../loyalty/domain/loyalty_rules.dart';
import '../data/auth_mock_repository.dart';
import '../domain/registration.dart';
import 'auth_controller.dart';

/// Dữ liệu A-05 chuyển sang màn OTP (GoRouter `extra`).
class RegisterOtpArgs {
  const RegisterOtpArgs({required this.email, required this.shopName});

  final String email;

  /// Cửa hàng khách sẽ tham gia, hiện trên thẻ kính.
  final String shopName;
}

/// A-05 OTP (DESIGN.md mục 8b): 6 ô số, gửi lại sau 45 giây, báo số lần thử
/// còn lại. Xác minh xong thì đăng nhập; router tự đưa vào C-10.
class RegisterOtpScreen extends ConsumerStatefulWidget {
  const RegisterOtpScreen({super.key, required this.args});

  /// `null` khi mở thẳng route (không đi từ A-05).
  final RegisterOtpArgs? args;

  @override
  ConsumerState<RegisterOtpScreen> createState() => _RegisterOtpScreenState();
}

class _RegisterOtpScreenState extends ConsumerState<RegisterOtpScreen> {
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  bool _resending = false;
  OtpFailure? _failure;

  /// Đếm ngược "Gửi lại sau", giảm mỗi giây.
  int _secondsLeft = OtpRules.resendAfter.inSeconds;
  Timer? _ticker;

  bool get _noAttempts => _failure?.kind == OtpFailureKind.noAttemptsLeft;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _ticker?.cancel();
    _secondsLeft = OtpRules.resendAfter.inSeconds;
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  Future<void> _verify(String email) async {
    if (_busy || _noAttempts || !OtpRules.isComplete(_codeCtrl.text)) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final session = await ref
          .read(registrationRepositoryProvider)
          .verifyEmail(email: email, otp: _codeCtrl.text);
      // Không cần điều hướng: router thấy đã đăng nhập thì vào C-10.
      await ref.read(authControllerProvider.notifier).signIn(session);
    } on OtpFailure catch (f) {
      if (mounted) {
        setState(() {
          _failure = f;
          _codeCtrl.clear();
        });
      }
    } catch (_) {
      if (mounted) showSoToast(context, 'Kiểm tra kết nối mạng rồi thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend(String email) async {
    setState(() => _resending = true);
    try {
      await ref.read(registrationRepositoryProvider).resendOtp(email);
      if (!mounted) return;
      setState(() {
        _failure = null;
        _codeCtrl.clear();
        _startCountdown();
      });
      showSoToast(context, 'Đã gửi mã mới tới $email.');
    } catch (_) {
      if (mounted) showSoToast(context, 'Kiểm tra kết nối mạng rồi thử lại.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  String? get _errorText {
    final f = _failure;
    return switch (f?.kind) {
      null => null,
      OtpFailureKind.wrongCode =>
        'Mã không đúng. Bạn còn ${f!.attemptsLeft} lần thử.',
      OtpFailureKind.noAttemptsLeft =>
        'Bạn đã nhập sai quá nhiều lần. Hãy gửi lại mã.',
      OtpFailureKind.other => f!.message,
    };
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    if (args == null) {
      return SoScaffold(
        appBar: const SoAppBar(title: 'Xác minh email'),
        slivers: [
          SliverPadding(
            padding: SoSpace.page,
            sliver: SliverToBoxAdapter(
              child: SoEmptyState(
                title: 'Chưa có thông tin đăng ký',
                actionLabel: 'Về Đăng ký',
                onAction: () => context.go(Routes.register),
              ),
            ),
          ),
        ],
      );
    }

    final c = context.soColors;
    final error = _errorText;
    final complete = OtpRules.isComplete(_codeCtrl.text);

    return SoScaffold(
      appBar: const SoAppBar(title: 'Xác minh email'),
      bottomBar: SoActionBar(
        primary: SoButton(
          key: const Key('otp_submit'),
          label: 'Xác minh',
          loading: _busy,
          onPressed: complete && !_noAttempts
              ? () => _verify(args.email)
              : null,
        ),
      ),
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SoMockBanner(message: 'Mã OTP mẫu: ${MockAccounts.otp}.'),
                const SizedBox(height: SoSpace.s16),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Nhập mã 6 số đã gửi tới '),
                      TextSpan(
                        text: args.email,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  style: context.textTheme.bodyMedium?.copyWith(color: c.ink2),
                ),
                const SizedBox(height: SoSpace.s16),
                _OtpBoxes(
                  controller: _codeCtrl,
                  hasError: error != null,
                  enabled: !_noAttempts,
                  onChanged: (_) => setState(() {
                    if (_failure?.kind == OtpFailureKind.wrongCode) {
                      _failure = null;
                    }
                  }),
                  onCompleted: () => _verify(args.email),
                ),
                if (error != null) ...[
                  const SizedBox(height: SoSpace.s8),
                  Text(
                    error,
                    key: const Key('otp_error'),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: c.danger,
                    ),
                  ),
                ],
                const SizedBox(height: SoSpace.s8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _secondsLeft > 0
                      ? ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: SoSize.touch,
                          ),
                          child: Align(
                            widthFactor: 1,
                            child: Text(
                              'Gửi lại sau '
                              '${OtpRules.countdown(Duration(seconds: _secondsLeft))}',
                              key: const Key('otp_countdown'),
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: c.muted,
                              ),
                            ),
                          ),
                        )
                      : TextButton(
                          key: const Key('otp_resend'),
                          onPressed: _resending
                              ? null
                              : () => _resend(args.email),
                          child: const Text('Gửi lại mã'),
                        ),
                ),
                const SizedBox(height: SoSpace.s16),
                SoGlass(
                  key: const Key('otp_shop'),
                  padding: SoSpace.card,
                  child: Row(
                    children: [
                      SoShopLogo(name: args.shopName),
                      const SizedBox(width: SoSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bạn sẽ tham gia',
                              style: context.textTheme.bodySmall?.copyWith(
                                color: c.ink2,
                              ),
                            ),
                            Text(
                              '${args.shopName} · '
                              '${LoyaltyTier.standard.label}',
                              style: context.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 6 ô số mono. Thực chất là một ô nhập ẩn phủ lên 6 ô vẽ, nên dán mã và
/// tự điền OTP từ bàn phím vẫn chạy.
class _OtpBoxes extends StatefulWidget {
  const _OtpBoxes({
    required this.controller,
    required this.hasError,
    required this.enabled,
    required this.onChanged,
    required this.onCompleted,
  });

  final TextEditingController controller;
  final bool hasError;
  final bool enabled;
  final ValueChanged<String> onChanged;

  /// Gõ đủ 6 số rồi bấm "Xong" trên bàn phím.
  final VoidCallback onCompleted;

  @override
  State<_OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<_OtpBoxes> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final code = widget.controller.text;
    // Ô đang chờ nhập: ô kế tiếp, hoặc ô cuối khi đã đủ.
    final current = code.length.clamp(0, OtpRules.length - 1);

    return Semantics(
      label: 'Mã OTP 6 số',
      child: SizedBox(
        height: 56,
        child: Stack(
          children: [
            Row(
              children: [
                for (var i = 0; i < OtpRules.length; i++) ...[
                  if (i > 0) const SizedBox(width: SoSpace.s8),
                  Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: widget.enabled ? c.surface : c.fill,
                        shape: RoundedSuperellipseBorder(
                          borderRadius: SoRadius.mdAll,
                          side: BorderSide(
                            color: widget.hasError
                                ? c.danger
                                : _focus.hasFocus && i == current
                                ? c.brand
                                : c.fillStrong,
                            width: _focus.hasFocus && i == current ? 2 : 1,
                          ),
                        ),
                      ),
                      child: Text(
                        i < code.length ? code[i] : '',
                        style: context.soText.code.copyWith(
                          fontSize: 22,
                          color: c.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            // Ô nhập thật: trong suốt, phủ kín 6 ô để chạm đâu cũng mở bàn phím.
            // Vẫn giữ semantics để TalkBack/VoiceOver thấy ô nhập.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                alwaysIncludeSemantics: true,
                child: TextField(
                  key: const Key('otp_input'),
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  showCursor: false,
                  enableInteractiveSelection: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(OtpRules.length),
                  ],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  onChanged: widget.onChanged,
                  onSubmitted: (_) => widget.onCompleted(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
