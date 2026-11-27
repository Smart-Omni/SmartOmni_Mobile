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
/// BE (`GET /api/v1/loyalty/me`) tự tính hạng (mặc định Standard / Gold /
/// Platinum / Diamond, hoặc tên mốc shop cấu hình). Có `tier` thì hiện
/// ĐÚNG tên BE trả ([backendTierName], [backendNextTierName],
/// [backendPointsToNext]); chỉ khi BE thiếu `tier` (hoặc bản mock) mới tính
/// bằng [LoyaltyRules].
class LoyaltySummary {
  const LoyaltySummary({
    required this.totalPoints,
    required this.history,
    this.backendTierName,
    this.backendNextTierName,
    this.backendPointsToNext,
  });

  final int totalPoints;
  final List<PointEntry> history;

  /// `tier` của BE, đã bỏ khoảng trắng; `null` khi BE không trả.
  final String? backendTierName;

  /// `nextTier` của BE; `null` = đang ở hạng cao nhất (chỉ có nghĩa khi có
  /// [backendTierName]).
  final String? backendNextTierName;

  /// `pointsToNextTier` của BE (chỉ dùng khi có [backendTierName]).
  final int? backendPointsToNext;

  bool get _fromBackend => backendTierName != null;

  /// Hạng chuẩn gần nhất, dùng để chọn màu huy hiệu. Tên BE lạ (mốc shop tự
  /// đặt) thì lấy hạng chuẩn theo điểm.
  LoyaltyTier get tier =>
      LoyaltyTier.fromBackend(backendTierName) ??
      LoyaltyRules.tierFor(totalPoints);

  /// Tên hạng để hiện: đúng chuỗi BE trả, thiếu thì tự tính.
  String get tierLabel => backendTierName ?? tier.label;

  /// Tên hạng kế tiếp; `null` nếu đã hạng cao nhất.
  String? get nextTierLabel =>
      _fromBackend ? backendNextTierName : tier.next?.label;

  int get pointsToNext => _fromBackend && backendPointsToNext != null
      ? backendPointsToNext!
      : LoyaltyRules.pointsToNextTier(totalPoints);
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

  /// Tiền hàng thực trả (VND), căn cứ tính điểm; `null` khi BE không trả
  /// (ẩn dòng "Đã thanh toán").
  final num? amountPaid;
  final int points;

  /// Điểm trước khi claim; `null` khi không đọc lại được tổng điểm sau claim
  /// (BE thật: `GET /loyalty/me` lỗi), khi đó ẩn dòng "Điểm" và "lên hạng".
  final int? pointsBefore;
  final DateTime claimedAt;

  int? get pointsAfter => pointsBefore == null ? null : pointsBefore! + points;

  LoyaltyTier? get tierBefore =>
      pointsBefore == null ? null : LoyaltyRules.tierFor(pointsBefore!);

  LoyaltyTier? get tierAfter =>
      pointsAfter == null ? null : LoyaltyRules.tierFor(pointsAfter!);

  bool get tieredUp =>
      tierBefore != null && tierAfter!.index > tierBefore!.index;
}

/// Claim không hợp lệ, kèm dữ liệu để báo cụ thể (ngày được claim, ngày đã
/// claim, thời gian còn khóa).
class ClaimFailure implements Exception {
  const ClaimFailure(
    this.kind, {
    this.completedAt,
    this.eligibleFrom,
    this.claimedAt,
    this.retryAfter,
  }) : assert(kind != ClaimEligibility.eligible);

  final ClaimEligibility kind;

  /// [ClaimEligibility.tooEarly]: ngày sàn xác nhận hoàn tất.
  final DateTime? completedAt;

  /// [ClaimEligibility.tooEarly]: ngày đủ điều kiện BE báo (đọc từ message
  /// hoặc body lỗi `ORDER_NOT_ELIGIBLE_YET`); có thì ưu tiên hơn ngày tự tính.
  final DateTime? eligibleFrom;

  /// [ClaimEligibility.alreadyClaimed]: ngày đơn đã được claim.
  final DateTime? claimedAt;

  /// [ClaimEligibility.tooManyAttempts]: còn khóa bao lâu.
  final Duration? retryAfter;

  /// Ngày sớm nhất được claim (ca chưa đủ 15 ngày).
  DateTime? get claimableFrom =>
      eligibleFrom ??
      (completedAt == null ? null : LoyaltyRules.claimableFrom(completedAt!));

  @override
  String toString() => 'ClaimFailure(${kind.name})';
}

/// Điểm, voucher, claim của khách, tính riêng theo từng cửa hàng.
///
/// `tenantId` là cửa hàng đang xem ở C-00, chỉ bản mock dùng để tách dữ liệu
/// mẫu giữa các cửa hàng. BE (`/api/v1/loyalty/*`) lấy tenant và khách từ
/// JWT (`TenantContext`), nên bản Remote bỏ qua tham số này và không gửi
/// header `X-Tenant-Id` (Nginx cũng xóa header đó). Muốn xem cửa hàng khác
/// thì phải có JWT của cửa hàng đó: đổi cửa hàng ở C-00 (còn mock) không
/// đổi dữ liệu Remote (lỗi L6, docs/API_CONTRACT.md mục 0).
///
/// Đã nối BE (`LoyaltyRemoteRepository`): [getSummary], [getVouchers],
/// [claimOrder] (`POST /loyalty/claims` bằng mã đơn trên sàn, BE `084b908`).
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
