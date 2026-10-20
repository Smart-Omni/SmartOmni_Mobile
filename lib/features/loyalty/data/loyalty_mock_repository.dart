import '../../../core/mock/mock_data.dart';
import '../../../core/models/platform.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/loyalty_repository.dart';
import '../domain/loyalty_rules.dart';

/// Mock theo cửa hàng, khớp số điểm với C-00: Shop Demo (1) 620 điểm và 2
/// voucher; Hoa Mộc (2) 120 điểm; cửa hàng khác chưa có gì. Đơn claim được
/// (`MockData.claimableOrders`) thuộc Shop Demo.
class LoyaltyMockRepository implements LoyaltyRepository {
  LoyaltyMockRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    final now = _clock();
    _history.addAll({
      1: [
        PointEntry(
          orderCode: '240815SHOP09',
          platform: Platform.tiktokShop,
          points: 100,
          claimedAt: now.subtract(const Duration(days: 45)),
        ),
        PointEntry(
          orderCode: '240905SHOP11',
          platform: Platform.shopee,
          points: 520,
          claimedAt: now.subtract(const Duration(days: 10)),
        ),
      ],
      2: [
        PointEntry(
          orderCode: '240930HM0007',
          platform: Platform.shopee,
          points: 120,
          claimedAt: now.subtract(const Duration(days: 18)),
        ),
      ],
    });
    _vouchers[1] = [
      CustomerVoucher(
        code: 'SILVER50K',
        platform: Platform.shopee,
        description: 'Giảm 50.000 ₫ cho đơn từ 300.000 ₫',
        expiresAt: now.add(const Duration(days: 20)),
      ),
      CustomerVoucher(
        code: 'TTSILVER10',
        platform: Platform.tiktokShop,
        description: 'Giảm 10%, tối đa 30.000 ₫',
        expiresAt: now.add(const Duration(days: 12)),
      ),
    ];
  }

  final DateTime Function() _clock;

  /// Lịch sử cộng điểm theo cửa hàng, cũ trước mới sau.
  final Map<int, List<PointEntry>> _history = {};
  final Map<int, List<CustomerVoucher>> _vouchers = {};

  /// Mã đơn đã claim. Mỗi đơn chỉ claim 1 lần trong một cửa hàng.
  Set<String> _claimed(int tenantId) => {
    for (final e in _history[tenantId] ?? const <PointEntry>[]) e.orderCode,
  };

  @override
  Future<LoyaltySummary> getSummary(int tenantId) async {
    await MockDelay.short();
    final history = _history[tenantId] ?? const <PointEntry>[];
    return LoyaltySummary(
      totalPoints: history.fold<int>(0, (s, e) => s + e.points),
      history: List.unmodifiable(history.reversed),
    );
  }

  @override
  Future<List<CustomerVoucher>> getVouchers(int tenantId) async {
    await MockDelay.short();
    return List.unmodifiable(_vouchers[tenantId] ?? const []);
  }

  @override
  Future<int> claimOrder({
    required int tenantId,
    required Platform platform,
    required String orderCode,
  }) async {
    await MockDelay.short();
    final code = orderCode.trim().toUpperCase();
    final match = tenantId != 1
        ? null
        : MockData.claimableOrders
              .where((o) => o.$1.toUpperCase() == code && o.$2 == platform)
              .firstOrNull;

    final eligibility = match == null
        ? ClaimEligibility.notFound
        : LoyaltyRules.checkEligibility(
            completedAt: match.$4,
            alreadyClaimed: _claimed(tenantId).contains(code),
            now: _clock(),
          );

    if (eligibility != ClaimEligibility.eligible) {
      throw ApiException(
        type: ApiErrorType.validation,
        message: eligibility.message,
      );
    }

    final points = LoyaltyRules.pointsForAmount(match!.$3);
    (_history[tenantId] ??= []).add(
      PointEntry(
        orderCode: code,
        platform: platform,
        points: points,
        claimedAt: _clock(),
      ),
    );
    return points;
  }
}
