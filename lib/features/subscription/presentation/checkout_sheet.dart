import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/formatters.dart';
import 'checkout_controller.dart';

/// Mở sheet thanh toán PRO. Trả `true` khi BE báo đã thanh toán.
Future<bool?> showCheckoutSheet(BuildContext context) =>
    showSoBottomSheet<bool>(
      context: context,
      builder: (_) => const CheckoutSheet(),
    );

/// Sheet "Thanh toán gói PRO": ảnh VietQR, thông tin chuyển khoản (Sao chép
/// STK và nội dung), số tiền, đếm ngược tới `expiresAt`. Sheet còn mở thì
/// [CheckoutController] hỏi trạng thái mỗi 5 giây; PAID thì tự đóng.
///
/// Kính chỉ là khung sheet; QR và thông tin chuyển khoản nằm trên thẻ trắng.
class CheckoutSheet extends ConsumerWidget {
  const CheckoutSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkoutControllerProvider);
    final controller = ref.read(checkoutControllerProvider.notifier);
    ref.listen(checkoutControllerProvider.select((s) => s.phase), (_, phase) {
      if (phase == CheckoutPhase.paid) Navigator.of(context).pop(true);
    });

    final retry = SoButton(
      key: const Key('checkout_retry'),
      label: 'Tạo mã mới',
      onPressed: controller.retry,
    );
    final close = SoButton.secondary(
      key: const Key('checkout_close'),
      label: 'Đóng',
      onPressed: () => Navigator.of(context).pop(),
    );

    final (Widget body, Widget? primary) = switch (state.phase) {
      CheckoutPhase.creating || CheckoutPhase.paid => (const _Loading(), null),
      CheckoutPhase.waiting => (_Waiting(state: state), null),
      CheckoutPhase.expired => (
        const SoBanner(
          key: Key('checkout_expired'),
          tone: SoBannerTone.warning,
          title: 'Mã đã hết hạn.',
          message:
              'Nếu bạn đã chuyển khoản, đừng chuyển lại - hệ thống sẽ ghi '
              'nhận trong vài phút, hãy tải lại trang Gói dịch vụ.',
        ),
        retry,
      ),
      CheckoutPhase.failed => (
        const SoBanner(
          key: Key('checkout_failed'),
          tone: SoBannerTone.danger,
          title: 'Thanh toán không thành công',
          message:
              'Số tiền chuyển chưa đủ hoặc giao dịch bị từ chối. Tạo mã '
              'mới để thanh toán lại.',
        ),
        retry,
      ),
      CheckoutPhase.error => (
        SoBanner(
          key: const Key('checkout_error'),
          tone: SoBannerTone.danger,
          title: 'Không tạo được mã thanh toán',
          message: state.error,
        ),
        state.canRetry ? retry : null,
      ),
    };

    return SoBottomSheet(
      title: 'Thanh toán gói PRO',
      secondary: close,
      primary: primary,
      child: body,
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Column(
    key: Key('checkout_loading'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SoSkeleton(height: 232, radius: SoRadius.lg),
      SizedBox(height: SoSpace.s12),
      SoSkeleton(height: 180, radius: SoRadius.lg),
    ],
  );
}

class _Waiting extends ConsumerWidget {
  const _Waiting({required this.state});

  final CheckoutState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = state.session!;
    final c = context.soColors;
    final text = context.textTheme;
    final simulate = ref.watch(appConfigProvider).allowsPaymentSimulation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: SoSpace.card,
          decoration: SoShape.card(c),
          child: Column(
            children: [
              _Qr(url: s.qrUrl),
              const SizedBox(height: SoSpace.s12),
              _Countdown(expiresAt: s.expiresAt),
            ],
          ),
        ),
        const SizedBox(height: SoSpace.s12),
        Container(
          padding: SoSpace.card,
          decoration: SoShape.card(c),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoRow(label: 'Ngân hàng', value: s.bankId),
              _InfoRow(
                label: 'Số tài khoản',
                value: s.accountNumber,
                code: true,
                copyKey: const Key('copy_account'),
              ),
              _InfoRow(label: 'Chủ tài khoản', value: s.accountHolder),
              _InfoRow(
                label: 'Số tiền',
                value: Formatters.vnd(s.amount),
                money: true,
              ),
              _InfoRow(
                label: 'Nội dung',
                value: s.memo,
                code: true,
                copyKey: const Key('copy_memo'),
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: SoSpace.s12),
        Text(
          'Ghi đúng nội dung chuyển khoản để hệ thống tự xác nhận. Màn này '
          'tự cập nhật khi nhận được tiền.',
          style: text.bodySmall?.copyWith(color: c.ink2),
        ),
        // Chỉ bản dev. BE đang mở `simulate-pay` cho mọi user (lỗi P1); bản
        // staging / prod không được có nút này và không phụ thuộc vào nó.
        if (simulate) ...[
          const SizedBox(height: SoSpace.s12),
          SoButton.ghost(
            key: const Key('pay_simulate'),
            label: 'Giả lập đã thanh toán (bản dev)',
            loading: state.simulating,
            onPressed: state.simulating
                ? null
                : () async {
                    final error = await ref
                        .read(checkoutControllerProvider.notifier)
                        .simulatePay();
                    if (error != null && context.mounted) {
                      showSoToast(context, error);
                    }
                  },
          ),
        ],
      ],
    );
  }
}

/// Ảnh QR 200×200: đang tải (khung xám) / lỗi (câu hướng dẫn chuyển khoản
/// tay). [url] rỗng (dữ liệu mẫu) cũng hiện câu hướng dẫn.
class _Qr extends StatelessWidget {
  const _Qr({required this.url});

  final String url;
  static const size = 200.0;

  @override
  Widget build(BuildContext context) {
    final fallback = _QrFallback(
      message: url.isEmpty
          ? 'Bản mẫu không có mã QR. Chuyển khoản theo thông tin bên dưới.'
          : 'Không tải được mã QR. Chuyển khoản theo thông tin bên dưới.',
    );
    if (url.isEmpty) return fallback;
    return Image.network(
      url,
      key: const Key('checkout_qr'),
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Mã QR chuyển khoản',
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const SoSkeleton(
              key: Key('checkout_qr_loading'),
              width: size,
              height: size,
              radius: SoRadius.md,
            ),
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _QrFallback extends StatelessWidget {
  const _QrFallback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('checkout_qr_error'),
    width: _Qr.size,
    height: _Qr.size,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(SoSpace.s16),
    decoration: ShapeDecoration(
      color: context.soColors.fill,
      shape: SoShape.squircle(SoRadius.mdAll),
    ),
    child: Text(message, style: context.textTheme.bodySmall),
  );
}

/// "Mã hết hạn sau mm:ss", cập nhật mỗi giây theo `clockProvider`.
class _Countdown extends ConsumerStatefulWidget {
  const _Countdown({required this.expiresAt});

  final DateTime expiresAt;

  @override
  ConsumerState<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends ConsumerState<_Countdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.expiresAt.difference(ref.watch(clockProvider)());
    final c = context.soColors;
    final style = context.textTheme.bodyMedium;
    if (left <= Duration.zero) {
      return Text(
        'Mã đã hết hạn',
        key: const Key('checkout_countdown'),
        style: style?.copyWith(color: c.warning),
      );
    }
    final mm = left.inMinutes.toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      'Mã hết hạn sau $mm:$ss',
      key: const Key('checkout_countdown'),
      style: style?.copyWith(color: c.ink2),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.code = false,
    this.money = false,
    this.copyKey,
    this.last = false,
  });

  final String label;
  final String value;
  final bool code;
  final bool money;

  /// Có thì hiện nút "Sao chép".
  final Key? copyKey;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final so = context.soText;
    final shown = value.isEmpty ? '—' : value;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : SoSpace.s12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodySmall),
                const SizedBox(height: 2),
                Text(
                  shown,
                  style: code ? so.code : (money ? so.money : text.bodyLarge),
                ),
              ],
            ),
          ),
          if (copyKey != null && value.isNotEmpty) ...[
            const SizedBox(width: SoSpace.s12),
            SoButton.secondary(
              key: copyKey,
              label: 'Sao chép',
              size: SoButtonSize.small,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) {
                  showSoToast(context, 'Đã sao chép ${label.toLowerCase()}');
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
