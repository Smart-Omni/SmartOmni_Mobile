/// Quy tắc điểm và hạng của SmartOmni (docs/project-context.md của backend).
///
/// Đặt logic ở đây (không nằm trong UI) để dễ viết unit test.
/// Backend là nơi quyết định cuối cùng; app dùng các hàm này để hiển thị
/// trước cho khách (vd: "đơn này sẽ được ~520 điểm").
library;

enum LoyaltyTier {
  standard('Standard', 0),
  silver('Silver', 500),
  platinum('Platinum', 1000),
  diamond('Diamond', 1500);

  const LoyaltyTier(this.label, this.minPoints);

  final String label;

  /// Số điểm tích lũy tối thiểu để đạt hạng.
  final int minPoints;

  /// Hạng kế tiếp, `null` nếu đã là hạng cao nhất.
  LoyaltyTier? get next => index + 1 < LoyaltyTier.values.length
      ? LoyaltyTier.values[index + 1]
      : null;
}

class LoyaltyRules {
  const LoyaltyRules._();

  /// Đơn chỉ được claim sau 15 ngày kể từ khi sàn xác nhận hoàn tất.
  static const claimWaitingPeriod = Duration(days: 15);

  /// 1 điểm cho mỗi 1.000 ₫ tiền hàng thực trả (sau giảm giá,
  /// KHÔNG tính phí vận chuyển và thuế), làm tròn xuống.
  static int pointsForAmount(num amountPaidVnd) {
    if (amountPaidVnd <= 0) return 0;
    return amountPaidVnd ~/ 1000;
  }

  /// Hạng theo tổng điểm tích lũy. Điểm không hết hạn, không bị trừ khi đổi thưởng.
  static LoyaltyTier tierFor(int totalPoints) {
    var tier = LoyaltyTier.standard;
    for (final t in LoyaltyTier.values) {
      if (totalPoints >= t.minPoints) tier = t;
    }
    return tier;
  }

  /// Số điểm còn thiếu để lên hạng kế tiếp (0 nếu đã hạng cao nhất).
  static int pointsToNextTier(int totalPoints) {
    final next = tierFor(totalPoints).next;
    return next == null ? 0 : next.minPoints - totalPoints;
  }

  /// Tiến độ 3 nấc trên thẻ hạng (C-20): Standard → Silver, Silver →
  /// Platinum, Platinum → Diamond; mỗi nấc từ 0 đến 1.
  static List<double> tierSegments(int totalPoints) => [
    for (final tier in LoyaltyTier.values.skip(1))
      ((totalPoints - LoyaltyTier.values[tier.index - 1].minPoints) /
              (tier.minPoints - LoyaltyTier.values[tier.index - 1].minPoints))
          .clamp(0.0, 1.0),
  ];

  /// Voucher còn từ chừng này ngày trở xuống thì báo "Hết hạn sau N ngày".
  static const voucherExpiringDays = 14;

  /// Số ngày lịch còn lại tới hạn dùng (0 = hết hạn trong hôm nay, âm = đã
  /// hết hạn); `null` khi voucher không có hạn.
  static int? voucherDaysLeft(DateTime? expiresAt, DateTime now) {
    if (expiresAt == null) return null;
    final end = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
    final today = DateTime(now.year, now.month, now.day);
    return end.difference(today).inDays;
  }

  /// Thời điểm sớm nhất đơn được claim.
  static DateTime claimableFrom(DateTime completedAt) =>
      completedAt.add(claimWaitingPeriod);

  /// Kiểm tra điều kiện thời gian để claim đơn.
  static ClaimEligibility checkEligibility({
    required DateTime? completedAt,
    required bool alreadyClaimed,
    DateTime? now,
  }) {
    if (alreadyClaimed) return ClaimEligibility.alreadyClaimed;
    if (completedAt == null) return ClaimEligibility.notCompleted;
    final current = now ?? DateTime.now();
    if (current.isBefore(claimableFrom(completedAt))) {
      return ClaimEligibility.tooEarly;
    }
    return ClaimEligibility.eligible;
  }
}

enum ClaimEligibility {
  eligible('Đơn hợp lệ'),
  notCompleted('Đơn chưa được sàn xác nhận hoàn tất'),
  tooEarly('Đơn chưa đủ 15 ngày kể từ khi hoàn tất'),
  alreadyClaimed('Đơn này đã được claim'),
  notFound('Không tìm thấy đơn trong shop đã chọn'),

  /// Thử sai quá nhiều lần, tạm khóa claim (backend quyết định ngưỡng).
  tooManyAttempts('Thử sai quá nhiều lần');

  const ClaimEligibility(this.message);

  final String message;
}
