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

/// Kết quả claim thành công (thẻ kết quả C-30).
class ClaimResult {
  const ClaimResult({
    required this.orderCode,
    required this.platform,
    required this.amountPaid,
    required this.points,
    required this.pointsBefore,
    required this.claimedAt,
  });

  final String orderCode;
  final Platform platform;

  /// Tiền hàng thực trả (VND), căn cứ tính điểm.
  final num amountPaid;
  final int points;
  final int pointsBefore;
  final DateTime claimedAt;

  int get pointsAfter => pointsBefore + points;

  LoyaltyTier get tierBefore => LoyaltyRules.tierFor(pointsBefore);

  LoyaltyTier get tierAfter => LoyaltyRules.tierFor(pointsAfter);

  bool get tieredUp => tierAfter.index > tierBefore.index;
}

/// Claim không hợp lệ, kèm dữ liệu để báo cụ thể (ngày được claim, ngày đã
/// claim, thời gian còn khóa).
class ClaimFailure implements Exception {
  const ClaimFailure(
    this.kind, {
    this.completedAt,
    this.claimedAt,
    this.retryAfter,
  }) : assert(kind != ClaimEligibility.eligible);

  final ClaimEligibility kind;

  /// [ClaimEligibility.tooEarly]: ngày sàn xác nhận hoàn tất.
  final DateTime? completedAt;

  /// [ClaimEligibility.alreadyClaimed]: ngày đơn đã được claim.
  final DateTime? claimedAt;

  /// [ClaimEligibility.tooManyAttempts]: còn khóa bao lâu.
  final Duration? retryAfter;

  /// Ngày sớm nhất được claim (ca chưa đủ 15 ngày).
  DateTime? get claimableFrom =>
      completedAt == null ? null : LoyaltyRules.claimableFrom(completedAt!);

  @override
  String toString() => 'ClaimFailure(${kind.name})';
}

/// ⚠️ Backend CHƯA có API Customer Portal / loyalty -> toàn bộ là mock.
/// API đề xuất xem docs/API_CONTRACT.md. Điểm, voucher, claim tính riêng
/// theo từng cửa hàng ([tenantId]; API thật gửi qua header `X-Tenant-Id`).
abstract class LoyaltyRepository {
  Future<LoyaltySummary> getSummary(int tenantId);

  Future<List<CustomerVoucher>> getVouchers(int tenantId);

  /// Claim đơn: khách chọn shop (sàn) + nhập mã đơn.
  /// Không hợp lệ thì ném [ClaimFailure]; lỗi mạng thì ném `ApiException`.
  Future<ClaimResult> claimOrder({
    required int tenantId,
    required Platform platform,
    required String orderCode,
  });
}
