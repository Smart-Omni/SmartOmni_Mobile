import '../../../core/utils/mock_delay.dart';
import '../domain/subscription.dart';

/// Dữ liệu mẫu chạy như BE `f9495df`: cửa hàng đang ở PRO, còn 3 ngày (được
/// gia hạn sớm), 3 hóa đơn đã thanh toán. Số tiền 499.000 ₫ là giá mặc định
/// trong `application.yml` của BE, không phải bảng giá chốt.
///
/// Có trạng thái: [simulatePay] cộng thêm một kỳ và thêm hóa đơn. Không có
/// ảnh QR (`qrUrl` rỗng) để không ai quét chuyển tiền thật vào tài khoản mẫu.
///
/// [usage] luôn là mẫu, kể cả khi dùng BE thật (lỗi P3): ba hạn mức cho đủ
/// ba mức màu (SKU bình thường, kết nối sàn đầy, dung lượng ảnh 86%).
class SubscriptionMockRepository implements SubscriptionRepository {
  SubscriptionMockRepository({required DateTime Function() clock})
    : _clock = clock {
    final today = _today();
    _periodEnd = today.add(const Duration(days: 3));
    _invoices = [
      for (var back = 0; back < 3; back++)
        _invoice(
          id: 3 - back,
          start: DateTime(today.year, today.month - back - 1, today.day + 3),
        ),
    ];
  }

  static const price = 499000;

  final DateTime Function() _clock;
  late DateTime _periodEnd;
  late List<Invoice> _invoices;
  final _paid = <String>{};
  var _nextPayment = 1;

  DateTime _today() {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  Invoice _invoice({required int id, required DateTime start}) => Invoice(
    code: 'INV-$id',
    amount: price,
    paid: true,
    periodStart: start,
    periodEnd: DateTime(start.year, start.month + 1, start.day),
    dueDate: start,
    paidAt: start,
    paymentMethod: 'Chuyển khoản SePay (VietQR)',
  );

  @override
  Future<SubscriptionSummary> status() async {
    await MockDelay.short();
    final days = _periodEnd.difference(_today()).inDays;
    final expired = days < 0;
    return SubscriptionSummary(
      planName: expired ? 'FREE' : 'PRO',
      isPro: !expired,
      status: expired
          ? PlanStatus.expired
          : (days <= earlyRenewalDays
                ? PlanStatus.expiringSoon
                : PlanStatus.active),
      periodStart: DateTime(
        _periodEnd.year,
        _periodEnd.month - 1,
        _periodEnd.day,
      ),
      periodEnd: _periodEnd,
      daysRemaining: expired ? 0 : days,
      canRenewEarly: !expired && days <= earlyRenewalDays,
      currentInvoiceId: _invoices.length,
    );
  }

  @override
  Future<List<Invoice>> invoices() async {
    await MockDelay.short();
    return List.unmodifiable(_invoices);
  }

  @override
  Future<PlanUsage> usage() async {
    await MockDelay.short();
    return const PlanUsage(
      skus: UsageQuota(312, 500),
      connections: UsageQuota(2, 2),
      imageStorageGb: UsageQuota(4.3, 5),
    );
  }

  @override
  Future<CheckoutSession> checkout() async {
    await MockDelay.short();
    final code = 'PRO0001${(_nextPayment++).toString().padLeft(5, '0')}';
    return CheckoutSession(
      orderCode: code,
      amount: price,
      qrUrl: '',
      accountNumber: '0000000001',
      bankId: 'MBBank',
      accountHolder: 'HO KINH DOANH SmartOmni',
      memo: code,
      planName: 'PRO',
      expiresAt: _clock().add(const Duration(minutes: 15)),
    );
  }

  @override
  Future<PaymentStatus> orderStatus(String orderCode) async {
    await MockDelay.short();
    return _paid.contains(orderCode)
        ? PaymentStatus.paid
        : PaymentStatus.pending;
  }

  @override
  Future<void> simulatePay(String orderCode) async {
    await MockDelay.short();
    if (!_paid.add(orderCode)) return;
    final today = _today();
    final start = _periodEnd.isAfter(today) ? _periodEnd : today;
    _periodEnd = DateTime(start.year, start.month + 1, start.day);
    _invoices = [
      _invoice(id: _invoices.length + 1, start: start),
      ..._invoices,
    ];
  }
}
