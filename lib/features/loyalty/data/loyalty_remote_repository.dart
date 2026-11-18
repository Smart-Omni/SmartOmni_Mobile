import '../../../core/network/api_response.dart';
import '../domain/loyalty_repository.dart';
import '../domain/loyalty_rules.dart';

/// Đọc JSON của `/api/v1/loyalty/*` (BE `develop` @ `361e8b5`, order-service,
/// `dto/loyalty`). Tên trường camelCase như DTO Java (order-service không
/// cấu hình snake_case); `Instant` là chuỗi ISO-8601, `BigDecimal` là số.
abstract final class LoyaltyJson {
  /// `LoyaltyProfileDto`: `{ customerId, tenantId, totalPoints, tier,
  /// nextTier, nextTierThreshold, pointsToNextTier }`.
  ///
  /// `tier` lạ hoặc thiếu thì tính hạng theo `totalPoints` (BE luôn trả
  /// "Standard" cho hạng thấp nhất, xem [LoyaltyTier.fromBackend]).
  /// `pointsToNextTier` chỉ tin khi đọc được `tier`, để hai số không lệch
  /// nhau.
  static LoyaltySummary summary(
    Object? profile, {
    List<PointEntry> history = const [],
  }) {
    final map = profile is JsonMap ? profile : const <String, dynamic>{};
    final points = Json.asInt(map['totalPoints']) ?? 0;
    final safePoints = points < 0 ? 0 : points;
    final tier = LoyaltyTier.fromBackend(map['tier']);
    final toNext = Json.asInt(map['pointsToNextTier']);
    return LoyaltySummary(
      totalPoints: safePoints,
      history: history,
      backendTier: tier,
      backendPointsToNext: tier == null || toNext == null || toNext < 0
          ? null
          : toNext,
    );
  }
}
