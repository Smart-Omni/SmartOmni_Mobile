import '../../../core/utils/mock_delay.dart';
import '../domain/subscription.dart';

/// Dữ liệu mẫu: "Gói mẫu", hạn mức và số tiền chỉ để dựng giao diện, **không**
/// phải bảng giá thật (chờ backend). Ba hạn mức cho đủ ba mức màu: SKU bình
/// thường, kết nối sàn đầy, dung lượng ảnh sắp chạm (86%).
class SubscriptionMockRepository implements SubscriptionRepository {
  SubscriptionMockRepository({required DateTime Function() clock})
    : _clock = clock;

  final DateTime Function() _clock;

  @override
  Future<SubscriptionOverview> overview() async {
    await MockDelay.short();
    final now = _clock();
    DateTime month(int back) => DateTime(now.year, now.month - back);
    Invoice invoice(int back, {bool paid = true}) {
      final p = month(back);
      return Invoice(
        code: 'INV-${p.year}${p.month.toString().padLeft(2, '0')}-0001',
        period: p,
        amount: 450000,
        paid: paid,
        dueDate: DateTime(p.year, p.month, 15),
      );
    }

    return SubscriptionOverview(
      subscription: Subscription(
        planName: 'Gói mẫu',
        expiresAt: DateTime(now.year, now.month + 1, now.day),
        skus: const UsageQuota(312, 500),
        connections: const UsageQuota(2, 2),
        imageStorageGb: const UsageQuota(4.3, 5),
      ),
      invoices: [invoice(0, paid: false), invoice(1), invoice(2), invoice(3)],
    );
  }
}
