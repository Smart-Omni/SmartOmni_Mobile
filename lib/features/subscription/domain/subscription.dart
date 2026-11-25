/// Gói SaaS của cửa hàng (T-40). BE `develop` @ `f9495df` có
/// `/api/v1/tenants/subscription` (tenant-service): trạng thái gói, hóa đơn,
/// thanh toán SePay (VietQR). Hạn mức và mức đã dùng BE chưa có (lỗi P3).
library;

import '../../../core/network/api_exception.dart';

/// Trạng thái gói theo `SubscriptionSummaryResponse.status` của BE.
enum PlanStatus {
  free,
  active,

  /// PRO còn ≤ [earlyRenewalDays] ngày.
  expiringSoon,
  expired;

  /// Chuỗi lạ hoặc thiếu thì coi là [free] (BE trả `FREE` cho mọi trường hợp
  /// không có PRO đang chạy).
  static PlanStatus fromBackend(Object? value) =>
      switch (value?.toString().trim().toUpperCase()) {
        'ACTIVE' => active,
        'EXPIRING_SOON' => expiringSoon,
        'EXPIRED' => expired,
        _ => free,
      };
}

/// BE chỉ cho tạo phiên thanh toán khi PRO còn từ chừng này ngày trở xuống
/// (`SUBSCRIPTION_EARLY_RENEWAL_TOO_EARLY`).
const earlyRenewalDays = 5;

/// `GET /tenants/subscription/status`.
class SubscriptionSummary {
  const SubscriptionSummary({
    required this.planName,
    required this.isPro,
    required this.status,
    this.periodStart,
    this.periodEnd,
    this.daysRemaining = 0,
    this.canRenewEarly = false,
    this.currentInvoiceId,
  });

  /// `PRO` hoặc `FREE`.
  final String planName;
  final bool isPro;
  final PlanStatus status;
  final DateTime? periodStart;

  /// Ngày cuối kỳ (BE `LocalDate`).
  final DateTime? periodEnd;
  final int daysRemaining;
  final bool canRenewEarly;
  final int? currentInvoiceId;

  /// Nút Thanh toán / Nâng cấp PRO chỉ hiện khi BE sẽ nhận `checkout`.
  bool get canPay =>
      status == PlanStatus.free ||
      status == PlanStatus.expired ||
      canRenewEarly;
}

/// Một hóa đơn (`SubscriptionInvoiceDto`).
class Invoice {
  const Invoice({
    required this.code,
    required this.amount,
    required this.paid,
    this.periodStart,
    this.periodEnd,
    this.dueDate,
    this.paidAt,
    this.paymentMethod,
  });

  /// `invoiceNumber`, vd. `INV-12`.
  final String code;
  final num amount;
  final bool paid;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final String? paymentMethod;
}

/// Một hạn mức: đã dùng / tối đa. [limit] `null` = không giới hạn.
class UsageQuota {
  const UsageQuota(this.used, this.limit);

  final num used;
  final num? limit;
}

/// Hạn mức và mức đã dùng. BE chưa có (lỗi P3): luôn là dữ liệu mẫu.
class PlanUsage {
  const PlanUsage({
    required this.skus,
    required this.connections,
    required this.imageStorageGb,
  });

  final UsageQuota skus;
  final UsageQuota connections;
  final UsageQuota imageStorageGb;
}

/// Phiên thanh toán VietQR (`SubscriptionCheckoutResponse`).
class CheckoutSession {
  const CheckoutSession({
    required this.orderCode,
    required this.amount,
    required this.qrUrl,
    required this.accountNumber,
    required this.bankId,
    required this.accountHolder,
    required this.memo,
    required this.planName,
    required this.expiresAt,
  });

  final String orderCode;
  final num amount;

  /// Ảnh QR (`vietqr.app`). Rỗng thì sheet chỉ hiện thông tin chuyển khoản.
  final String qrUrl;
  final String accountNumber;
  final String bankId;
  final String accountHolder;

  /// Nội dung chuyển khoản (BE dùng chính [orderCode]).
  final String memo;
  final String planName;

  /// Hết hạn mã QR (BE: 15 phút sau khi tạo).
  final DateTime expiresAt;
}

/// `SubscriptionOrderStatusResponse.status`.
enum PaymentStatus {
  pending,
  paid,
  failed,
  expired;

  /// Chuỗi lạ thì coi là [pending] (hỏi tiếp, không báo sai kết quả).
  static PaymentStatus fromBackend(Object? value) =>
      switch (value?.toString().trim().toUpperCase()) {
        'PAID' => paid,
        'FAILED' => failed,
        'EXPIRED' => expired,
        _ => pending,
      };

  bool get isFinal => this != pending;
}

abstract interface class SubscriptionRepository {
  Future<SubscriptionSummary> status();

  /// Mới nhất trước.
  Future<List<Invoice>> invoices();

  /// Luôn là dữ liệu mẫu (BE chưa có, lỗi P3).
  Future<PlanUsage> usage();

  /// Tạo (hoặc dùng lại) phiên thanh toán PRO.
  Future<CheckoutSession> checkout();

  Future<PaymentStatus> orderStatus(String orderCode);

  /// Chỉ dùng ở bản dev. Xem `SubscriptionRemoteRepository.simulatePay`.
  Future<void> simulatePay(String orderCode);
}

/// Mã lỗi BE khi PRO còn hơn [earlyRenewalDays] ngày mà vẫn gọi `checkout`.
const earlyRenewalTooEarlyCode = 'SUBSCRIPTION_EARLY_RENEWAL_TOO_EARLY';

/// Câu hiện khi không tạo được phiên thanh toán. Lỗi gia hạn sớm dùng câu của
/// app (không phụ thuộc message BE), các lỗi khác dùng message của
/// [ApiException].
String checkoutErrorMessage(Object error) {
  if (error is ApiException) {
    if (error.code == earlyRenewalTooEarlyCode) {
      return 'Gói PRO còn hơn $earlyRenewalDays ngày hiệu lực. Bạn chỉ gia '
          'hạn được khi còn từ $earlyRenewalDays ngày trở xuống.';
    }
    return error.message;
  }
  return 'Không tạo được mã thanh toán. Vui lòng thử lại.';
}

enum UsageLevel {
  normal,

  /// ≥ 80% hạn mức: "Sắp chạm hạn mức".
  near,

  /// Đã dùng hết hạn mức.
  full,
}

/// Ngưỡng [UsageLevel.near].
const usageNearRatio = 0.8;

UsageLevel usageLevel(UsageQuota q) {
  final limit = q.limit;
  if (limit == null) return UsageLevel.normal;
  if (limit <= 0 || q.used >= limit) return UsageLevel.full;
  return q.used / limit >= usageNearRatio ? UsageLevel.near : UsageLevel.normal;
}
