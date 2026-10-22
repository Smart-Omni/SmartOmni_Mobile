import '../../../core/models/platform.dart';
import '../../loyalty/domain/loyalty_rules.dart';

/// Khách của cửa hàng, dùng để chọn đối tượng phát voucher (T-30).
class VoucherCustomer {
  const VoucherCustomer({
    required this.id,
    required this.name,
    required this.email,
    required this.tier,
  });

  final int id;
  final String name;
  final String email;
  final LoyaltyTier tier;
}

/// Sàn có tạo voucher qua API được không.
enum VoucherSupport {
  available,

  /// Sàn không cho tạo voucher qua API (F-T4 bước 5): khóa lựa chọn.
  unsupported,

  /// Chưa kết nối shop trên sàn này (T-10).
  notConnected,
}

/// Dữ liệu để dựng form: khách và khả năng của từng sàn.
class VoucherSetup {
  const VoucherSetup({required this.customers, required this.support});

  final List<VoucherCustomer> customers;
  final Map<Platform, VoucherSupport> support;

  VoucherSupport supportOf(Platform p) =>
      support[p] ?? VoucherSupport.notConnected;
}

/// Đối tượng nhận: theo hạng (từ hạng đó trở lên) hoặc chọn từng khách.
sealed class VoucherAudience {
  const VoucherAudience();
}

class TierAudience extends VoucherAudience {
  const TierAudience(this.fromTier);

  final LoyaltyTier fromTier;
}

class PickedAudience extends VoucherAudience {
  const PickedAudience(this.customerIds);

  final Set<int> customerIds;
}

/// Số khách từ hạng [tier] trở lên (Standard = tất cả).
int countFromTier(Iterable<VoucherCustomer> customers, LoyaltyTier tier) =>
    customers.where((c) => c.tier.index >= tier.index).length;

/// Id các khách sẽ nhận voucher với [a] (giữ thứ tự của [customers]).
List<int> audienceIds(Iterable<VoucherCustomer> customers, VoucherAudience a) =>
    [
      for (final c in customers)
        if (switch (a) {
          TierAudience(:final fromTier) => c.tier.index >= fromTier.index,
          PickedAudience(:final customerIds) => customerIds.contains(c.id),
        })
          c.id,
    ];

/// Số khách sẽ nhận voucher với [a].
int audienceCount(Iterable<VoucherCustomer> customers, VoucherAudience a) =>
    audienceIds(customers, a).length;

/// Nhãn đối tượng trên chip và trong đợt phát: "Tất cả", "Silver+",
/// "Diamond", "5 khách đã chọn".
String audienceLabel(VoucherAudience a) => switch (a) {
  TierAudience(fromTier: LoyaltyTier.standard) => 'Tất cả',
  TierAudience(fromTier: LoyaltyTier.diamond) => 'Diamond',
  TierAudience(:final fromTier) => '${fromTier.label}+',
  PickedAudience(:final customerIds) => '${customerIds.length} khách đã chọn',
};

/// Các hạn dùng cho chọn (ngày).
const voucherValidDays = [7, 14, 30];

/// Ngày hết hạn: hết ngày thứ [days] kể từ hôm nay.
DateTime voucherExpiry(DateTime now, int days) =>
    DateTime(now.year, now.month, now.day + days);

/// Giá trị giảm (₫) phải > 0.
String? validateDiscount(int? amount) {
  if (amount == null) return 'Giá trị giảm không được để trống';
  if (amount <= 0) return 'Giá trị giảm phải lớn hơn 0';
  return null;
}

/// Đơn tối thiểu (₫) phải lớn hơn giá trị giảm, nếu không voucher thành
/// tặng không.
String? validateMinOrder(int? minOrder, int? discount) {
  if (minOrder == null) return 'Đơn tối thiểu không được để trống';
  if (discount != null && discount > 0 && minOrder <= discount) {
    return 'Đơn tối thiểu phải lớn hơn giá trị giảm';
  }
  return null;
}

/// Trạng thái đợt phát. "Chưa rõ" = không biết sàn đã tạo hay chưa: đối soát
/// trên sàn, **không** tạo lại (F-T4 bước 4).
enum VoucherBatchStatus { creating, success, failed, unknown }

/// Một đợt phát voucher.
class VoucherBatch {
  const VoucherBatch({
    required this.id,
    required this.platform,
    required this.discount,
    required this.minOrder,
    required this.expiresAt,
    required this.audience,
    required this.customerCount,
    required this.status,
    required this.createdAt,
    this.failureReason,
  });

  final int id;
  final Platform platform;
  final int discount;
  final int minOrder;
  final DateTime expiresAt;

  /// Nhãn đối tượng lúc phát (vd. "Silver+").
  final String audience;
  final int customerCount;
  final VoucherBatchStatus status;
  final DateTime createdAt;

  /// Lý do ngắn khi [VoucherBatchStatus.failed].
  final String? failureReason;

  VoucherBatch copyWith({VoucherBatchStatus? status}) => VoucherBatch(
    id: id,
    platform: platform,
    discount: discount,
    minOrder: minOrder,
    expiresAt: expiresAt,
    audience: audience,
    customerCount: customerCount,
    status: status ?? this.status,
    createdAt: createdAt,
    failureReason: failureReason,
  );
}

/// Yêu cầu phát voucher đã kiểm tra hợp lệ.
class VoucherDraft {
  const VoucherDraft({
    required this.platform,
    required this.discount,
    required this.minOrder,
    required this.expiresAt,
    required this.audience,
    required this.customerIds,
  });

  final Platform platform;
  final int discount;
  final int minOrder;
  final DateTime expiresAt;

  /// Nhãn đối tượng (vd. "Silver+").
  final String audience;
  final List<int> customerIds;
}

/// ⚠️ Backend chưa có API phát voucher (phụ thuộc API tạo voucher của sàn,
/// docs/API_CONTRACT.md) -> mock.
abstract interface class VoucherRepository {
  Future<VoucherSetup> setup();

  /// Đợt phát gần đây, mới nhất trước.
  Future<List<VoucherBatch>> recentBatches();

  /// Gửi yêu cầu tạo voucher trên sàn; trả về đợt ở trạng thái "Đang tạo".
  /// Email cho khách chỉ gửi khi sàn xác nhận tạo thành công.
  Future<VoucherBatch> issue(VoucherDraft draft);
}
