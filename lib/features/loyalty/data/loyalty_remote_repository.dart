import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show Locale;

import '../../../core/models/platform.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/api_response.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/loyalty_repository.dart';
import '../domain/loyalty_rules.dart';

/// Đọc JSON của `/api/v1/loyalty/*` (BE `develop` @ `361e8b5`, order-service,
/// `dto/loyalty`). Tên trường camelCase như DTO Java (order-service không
/// cấu hình snake_case); `Instant` là chuỗi ISO-8601, `BigDecimal` là số.
abstract final class LoyaltyJson {
  /// `LoyaltyProfileDto`: `{ customerId, tenantId, totalPoints, tier,
  /// nextTier, nextTierThreshold, pointsToNextTier }`.
  ///
  /// Có `tier` thì hiện đúng tên BE trả (kể cả tên mốc shop tự đặt); thiếu
  /// `tier` thì tính hạng theo `totalPoints`. `nextTier`/`pointsToNextTier`
  /// chỉ dùng khi có `tier`, để các số không lệch nhau.
  static LoyaltySummary summary(
    Object? profile, {
    List<PointEntry> history = const [],
  }) {
    final map = profile is JsonMap ? profile : const <String, dynamic>{};
    final points = Json.asInt(map['totalPoints']) ?? 0;
    final safePoints = points < 0 ? 0 : points;
    final tier = _name(map['tier']);
    final toNext = Json.asInt(map['pointsToNextTier']);
    return LoyaltySummary(
      totalPoints: safePoints,
      history: history,
      backendTierName: tier,
      backendNextTierName: tier == null ? null : _name(map['nextTier']),
      backendPointsToNext: tier == null || toNext == null || toNext < 0
          ? null
          : toNext,
    );
  }

  static String? _name(Object? value) {
    final s = value is String ? value.trim() : null;
    return s == null || s.isEmpty ? null : s;
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

  /// Mã lỗi của `POST /loyalty/claims` (BE `084b908`) → loại lỗi C-30.
  static const claimErrorKinds = {
    'ORDER_NOT_FOUND': ClaimEligibility.notFound,
    'ORDER_NOT_COMPLETED': ClaimEligibility.notCompleted,
    'ORDER_NOT_ELIGIBLE_YET': ClaimEligibility.tooEarly,
    'ORDER_ALREADY_CLAIMED': ClaimEligibility.alreadyClaimed,
    'PLATFORM_REQUIRED': ClaimEligibility.platformRequired,
    'ORDER_SYNCING': ClaimEligibility.syncing,
    'TOO_MANY_CLAIM_ATTEMPTS': ClaimEligibility.tooManyAttempts,
  };

  /// Lỗi claim của BE → [ClaimFailure]; `null` nếu không phải mã đã biết.
  ///
  /// `ORDER_NOT_ELIGIBLE_YET`: BE ghi ngày trong message
  /// ("... (eligible from 2026-12-09)", lịch Việt Nam); đọc thêm các trường
  /// ngày trong body nếu BE trả sau này.
  static ClaimFailure? claimFailure(ApiException e, {Object? body}) {
    final kind = claimErrorKinds[e.code];
    if (kind == null) return null;
    return ClaimFailure(
      kind,
      eligibleFrom: kind == ClaimEligibility.tooEarly
          ? _eligibleDate(body) ?? _dateIn(e.message)
          : null,
    );
  }

  static final _isoDate = RegExp(r'(\d{4})-(\d{2})-(\d{2})');

  static DateTime? _dateIn(String? text) {
    final m = text == null ? null : _isoDate.firstMatch(text);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  static DateTime? _eligibleDate(Object? body) {
    for (final map in [
      if (body is JsonMap) body,
      if (body is JsonMap && body['data'] is JsonMap) body['data'] as JsonMap,
    ]) {
      for (final key in const [
        'eligibleFrom',
        'eligibleForPointsAt',
        'eligible_for_points_at',
      ]) {
        final v = map[key];
        if (v is String) {
          final d = _dateIn(v);
          if (d != null) return d;
        }
      }
    }
    return null;
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
/// C-30 claim đơn gọi `POST /loyalty/claims` với mã đơn trên sàn
/// (`platformOrderId` + `platform`, BE `084b908`; L2 đã sửa). BE tự kiểm tra
/// 15 ngày, app không kiểm tra trước.
class LoyaltyRemoteRepository implements LoyaltyRepository {
  LoyaltyRemoteRepository(this._dio);

  final Dio _dio;

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
  }) async {
    final code = orderCode.trim();
    final JsonMap dto;
    try {
      final res = await _dio.post<Object?>(
        ApiPaths.loyaltyClaims,
        // BE nhận `shopee` / `tiktok_shop` không phân biệt hoa thường.
        data: {'platformOrderId': code, 'platform': platform.backendValue},
      );
      dto = unwrapResponse<JsonMap>(
        res.data,
        (d) => d is JsonMap ? d : const <String, dynamic>{},
      );
    } on DioException catch (e) {
      final api = ApiException.fromDio(e);
      final failure = LoyaltyJson.claimFailure(api, body: e.response?.data);
      if (failure != null) throw failure;
      // Mã lỗi khác (vd. đơn có hoàn trả): câu tiếng Việt chung, giữ mã lỗi.
      if (api.code != null) {
        throw ApiException(
          type: api.type,
          message: lookupAppLocalizations(const Locale('vi')).claimErrGeneric,
          statusCode: api.statusCode,
          code: api.code,
        );
      }
      throw api;
    }

    final amount = Json.asDouble(dto['eligibleAmountVnd']);
    final points =
        Json.asInt(dto['pointsAwarded']) ??
        (amount == null ? 0 : LoyaltyRules.pointsForAmount(amount));
    // Tổng điểm sau claim để hiện "điểm cũ → mới"; lỗi thì chỉ hiện +điểm.
    int? before;
    try {
      final summary = await _get(ApiPaths.loyaltyMe, LoyaltyJson.summary);
      before = summary.totalPoints - points;
      if (before < 0) before = 0;
    } on ApiException {
      before = null;
    }
    return ClaimResult(
      orderCode: code,
      platform: platform,
      amountPaid: amount,
      points: points < 0 ? 0 : points,
      pointsBefore: before,
      claimedAt: Json.asDate(dto['claimedAt']) ?? DateTime.now(),
    );
  }

  Future<T> _get<T>(String path, T Function(Object? data) parse) async {
    try {
      final res = await _dio.get<Object?>(path);
      return unwrapResponse<T>(res.data, parse);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
