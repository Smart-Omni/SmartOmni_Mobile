import 'package:dio/dio.dart';

import '../../../core/models/platform.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/api_response.dart';
import '../../../core/utils/formatters.dart';
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

  /// `LoyaltyClaimDto`: `{ id, orderId, customerId, eligibleAmountVnd,
  /// pointsAwarded, claimedAt }`. BE trả mới trước cũ.
  ///
  /// Chưa có mã đơn trên sàn và sàn (lỗi L3): hiện `Đơn #<orderId>`, không
  /// có nhãn sàn. Thiếu `pointsAwarded` thì tính từ `eligibleAmountVnd`.
  static PointEntry claim(JsonMap json) {
    final orderId = Json.asInt(json['orderId']);
    final amount = Json.asDouble(json['eligibleAmountVnd']);
    final points =
        Json.asInt(json['pointsAwarded']) ??
        (amount == null ? 0 : LoyaltyRules.pointsForAmount(amount));
    return PointEntry(
      orderCode: orderId == null ? 'Đơn không rõ mã' : 'Đơn #$orderId',
      points: points < 0 ? 0 : points,
      claimedAt: Json.asDate(json['claimedAt']),
      amountPaid: amount,
    );
  }

  /// Danh sách `LoyaltyClaimDto`; phần tử không phải object thì bỏ.
  static List<PointEntry> claims(Object? data) => [
    for (final e in (data is List ? data : const []))
      if (e is JsonMap) claim(e),
  ];

  /// `LoyaltyRewardRequestDto` (`/me/vouchers`): `{ id, tenantId, campaignId,
  /// campaignName, discountPercent, customerId, requestKey, status, code,
  /// externalVoucherId, failureReason, requestedAt, issuedAt, updatedAt }`.
  ///
  /// BE chưa có sàn và hạn dùng (lỗi L4) nên để `null`. Mô tả ghép từ
  /// `campaignName` và `discountPercent`.
  static CustomerVoucher voucher(JsonMap json) {
    final code = Json.asString(json['code'])?.trim();
    final name = Json.asString(json['campaignName'])?.trim();
    final percent = Json.asDouble(json['discountPercent']);
    final parts = [
      if (name != null && name.isNotEmpty) name,
      if (percent != null && percent > 0) 'Giảm ${Formatters.number(percent)}%',
    ];
    return CustomerVoucher(
      id: Json.asInt(json['id']),
      code: code == null || code.isEmpty ? null : code,
      description: parts.isEmpty ? 'Voucher' : parts.join(' · '),
      status: VoucherIssueStatus.fromBackend(json['status']),
    );
  }

  /// Danh sách `LoyaltyRewardRequestDto`; phần tử không phải object thì bỏ.
  static List<CustomerVoucher> vouchers(Object? data) => [
    for (final e in (data is List ? data : const []))
      if (e is JsonMap) voucher(e),
  ];
}

/// C-20 gọi `/api/v1/loyalty/me`, `/me/claims`, `/me/vouchers` (chỉ role
/// CUSTOMER). BE lấy tenant và khách từ JWT nên không gửi `tenantId` hay
/// header `X-Tenant-Id`; tham số `tenantId` của interface bị bỏ qua (lỗi
/// L6: luôn là cửa hàng trong JWT).
///
/// C-30 claim đơn vẫn chạy mock qua [claims]: `POST /loyalty/claims` đòi
/// `orderId` nội bộ và `totalAmount`, khách chỉ biết mã đơn trên sàn (lỗi L2).
class LoyaltyRemoteRepository implements LoyaltyRepository {
  LoyaltyRemoteRepository(this._dio, {required LoyaltyRepository claims})
    : _claims = claims;

  final Dio _dio;
  final LoyaltyRepository _claims;

  @override
  Future<LoyaltySummary> getSummary(int tenantId) async {
    // Gọi song song; lỗi request nào trước thì ném lỗi đó.
    final [profile, history] = await Future.wait<Object?>([
      _get(ApiPaths.loyaltyMe, (d) => d),
      _get(ApiPaths.loyaltyMyClaims, LoyaltyJson.claims),
    ], eagerError: true);
    return LoyaltyJson.summary(profile, history: history! as List<PointEntry>);
  }

  @override
  Future<List<CustomerVoucher>> getVouchers(int tenantId) =>
      _get(ApiPaths.loyaltyMyVouchers, LoyaltyJson.vouchers);

  @override
  Future<ClaimResult> claimOrder({
    required int tenantId,
    required Platform platform,
    required String orderCode,
  }) => _claims.claimOrder(
    tenantId: tenantId,
    platform: platform,
    orderCode: orderCode,
  );

  Future<T> _get<T>(String path, T Function(Object? data) parse) async {
    try {
      final res = await _dio.get<Object?>(path);
      return unwrapResponse<T>(res.data, parse);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
