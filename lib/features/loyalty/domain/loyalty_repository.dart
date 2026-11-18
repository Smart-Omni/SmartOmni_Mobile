import '../../../core/models/platform.dart';
import 'loyalty_rules.dart';

/// Một lần cộng điểm từ đơn đã claim.
class PointEntry {
  const PointEntry({
    required this.orderCode,
    this.platform,
    required this.points,
    this.claimedAt,
    this.amountPaid,
  });

  /// Mã đơn để hiện. BE (`LoyaltyClaimDto`) chưa có mã đơn trên sàn (lỗi L3)
  /// nên tạm là `Đơn #<orderId>` (id nội bộ).
  final String orderCode;

  /// Sàn của đơn; `null` khi BE chưa trả (lỗi L3): ẩn nhãn sàn.
  final Platform? platform;
  final int points;
  final DateTime? claimedAt;

  /// Tiền hàng được tính điểm (VND), `null` nếu không biết.
  final num? amountPaid;
}

/// Tổng quan điểm của khách.
///
/// BE (`GET /api/v1/loyalty/me`) tự tính hạng và số điểm còn thiếu; khi có
/// thì dùng số của BE ([backendTier], [backendPointsToNext]), không có thì
/// tính bằng [LoyaltyRules] (mock, hoặc BE trả thiếu / tên hạng lạ).
class LoyaltySummary {
  const LoyaltySummary({
    required this.totalPoints,
    required this.history,
    this.backendTier,
    this.backendPointsToNext,
  });

  final int totalPoints;
  final List<PointEntry> history;
  final LoyaltyTier? backendTier;
  final int? backendPointsToNext;

  LoyaltyTier get tier => backendTier ?? LoyaltyRules.tierFor(totalPoints);

  int get pointsToNext =>
      backendPointsToNext ?? LoyaltyRules.pointsToNextTier(totalPoints);
}

/// Trạng thái phát voucher (`status` của `LoyaltyRewardRequestDto`: BE lưu
/// chữ thường `pending` / `issued` / `failed`).
enum VoucherIssueStatus {
  issued(null),
  pending('Đang phát'),
  failed('Chưa phát được'),

  /// Giá trị BE mới hoặc thiếu.
  unknown('Đang xử lý');

  const VoucherIssueStatus(this.label);

  /// Nhãn trung tính cho voucher chưa phát xong; `null` khi đã phát.
  final String? label;

  static VoucherIssueStatus fromBackend(Object? value) =>
      switch (value?.toString().trim().toLowerCase()) {
        'issued' => issued,
        'pending' => pending,
        'failed' => failed,
        _ => unknown,
      };
}

/// Voucher Tenant Admin phát cho khách (khách dùng mã trên app sàn).
class CustomerVoucher {
  const CustomerVoucher({
    this.id,
    this.code,
    this.platform,
    required this.description,
    this.expiresAt,
    this.status = VoucherIssueStatus.issued,
  });

  /// Id yêu cầu đổi thưởng ở BE; `null` với dữ liệu mẫu.
  final int? id;

  /// Mã dùng trên sàn; `null` khi chưa phát xong (BE chỉ có mã khi `issued`).
  final String? code;

  /// `null` khi BE chưa trả sàn (lỗi L4): ẩn nhãn sàn.
  final Platform? platform;
  final String description;

  /// `null` khi không có hạn hoặc BE chưa trả (lỗi L4).
  final DateTime? expiresAt;
  final VoucherIssueStatus status;
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
