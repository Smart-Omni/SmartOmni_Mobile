/// Gói SaaS của cửa hàng (T-40). Bảng `subscription_plans`, `tenant_invoices`
/// đã có trong ERD nhưng backend chưa có API.
library;

/// Một hạn mức: đã dùng / tối đa. [limit] `null` = không giới hạn.
class UsageQuota {
  const UsageQuota(this.used, this.limit);

  final num used;
  final num? limit;
}

class Subscription {
  const Subscription({
    required this.planName,
    required this.expiresAt,
    required this.skus,
    required this.connections,
    required this.imageStorageGb,
  });

  final String planName;
  final DateTime expiresAt;
  final UsageQuota skus;
  final UsageQuota connections;
  final UsageQuota imageStorageGb;
}

class Invoice {
  const Invoice({
    required this.code,
    required this.period,
    required this.amount,
    required this.paid,
    required this.dueDate,
  });

  final String code;

  /// Tháng tính phí (ngày 1 của tháng).
  final DateTime period;
  final int amount;
  final bool paid;
  final DateTime dueDate;
}

class SubscriptionOverview {
  const SubscriptionOverview({
    required this.subscription,
    required this.invoices,
  });

  final Subscription subscription;

  /// Mới nhất trước.
  final List<Invoice> invoices;

  List<Invoice> get unpaid => [
    for (final i in invoices)
      if (!i.paid) i,
  ];
}

/// ⚠️ Backend chưa có API gói SaaS -> mock. Không thanh toán trong app.
abstract interface class SubscriptionRepository {
  Future<SubscriptionOverview> overview();
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

enum PlanStatus { active, expiringSoon, expired }

/// Còn ≤ [planExpiringDays] ngày thì "Sắp hết hạn".
const planExpiringDays = 7;

/// [expiresAt] là ngày cuối còn dùng được (tính theo ngày, không theo giờ).
PlanStatus planStatus(DateTime expiresAt, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final end = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
  final daysLeft = end.difference(today).inDays;
  if (daysLeft < 0) return PlanStatus.expired;
  if (daysLeft <= planExpiringDays) return PlanStatus.expiringSoon;
  return PlanStatus.active;
}
