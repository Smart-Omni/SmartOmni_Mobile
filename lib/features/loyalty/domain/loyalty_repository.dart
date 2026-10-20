import '../../../core/models/platform.dart';
import 'loyalty_rules.dart';

/// Một lần cộng điểm từ đơn đã claim.
class PointEntry {
  const PointEntry({
    required this.orderCode,
    required this.platform,
    required this.points,
    required this.claimedAt,
  });

  final String orderCode;
  final Platform platform;
  final int points;
  final DateTime claimedAt;
}

/// Tổng quan điểm của khách.
class LoyaltySummary {
  const LoyaltySummary({required this.totalPoints, required this.history});

  final int totalPoints;
  final List<PointEntry> history;

  LoyaltyTier get tier => LoyaltyRules.tierFor(totalPoints);

  int get pointsToNext => LoyaltyRules.pointsToNextTier(totalPoints);
}

/// Voucher Tenant Admin phát cho khách (khách dùng mã trên app sàn).
class CustomerVoucher {
  const CustomerVoucher({
    required this.code,
    required this.platform,
    required this.description,
    this.expiresAt,
  });

  final String code;
  final Platform platform;
  final String description;
  final DateTime? expiresAt;
}

/// ⚠️ Backend CHƯA có API Customer Portal / loyalty -> toàn bộ là mock.
/// API đề xuất xem docs/API_CONTRACT.md. Điểm, voucher, claim tính riêng
/// theo từng cửa hàng ([tenantId]; API thật gửi qua header `X-Tenant-Id`).
abstract class LoyaltyRepository {
  Future<LoyaltySummary> getSummary(int tenantId);

  Future<List<CustomerVoucher>> getVouchers(int tenantId);

  /// Claim đơn: khách chọn shop (sàn) + nhập mã đơn.
  /// Trả về số điểm được cộng. Ném ApiException nếu không hợp lệ.
  Future<int> claimOrder({
    required int tenantId,
    required Platform platform,
    required String orderCode,
  });
}
