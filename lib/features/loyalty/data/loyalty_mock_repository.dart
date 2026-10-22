import '../../../core/mock/mock_data.dart';
import '../../../core/models/platform.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/loyalty_repository.dart';
import '../domain/loyalty_rules.dart';

/// Mock theo cửa hàng, khớp số điểm với C-00: Shop Demo (1) 620 điểm và 2
/// voucher; Hoa Mộc (2) 120 điểm; cửa hàng khác chưa có gì. Đơn claim được
/// (`MockData.claimableOrders`) thuộc Shop Demo.
class LoyaltyMockRepository implements LoyaltyRepository {
  /// [demoData] = false cho tài khoản đăng ký mới: chưa có điểm, voucher.
  LoyaltyMockRepository({DateTime Function()? clock, bool demoData = true})
    : _clock = clock ?? DateTime.now {
    if (!demoData) return;
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

  /// Khóa claim sau [_maxFailures] lần sai liên tiếp, trong [_lockFor].
  /// shortcut: ngưỡng thật do backend quyết định (REQUIREMENTS CUS-5).
  static const _maxFailures = 5;
  static const _lockFor = Duration(minutes: 30);
  final Map<int, int> _failures = {};
  final Map<int, DateTime> _lockedUntil = {};

  @override
  Future<LoyaltySummary> getSummary(int tenantId) async {
    await MockDelay.short();
    final history = _history[tenantId] ?? const <PointEntry>[];
    return LoyaltySummary(
      totalPoints: _total(tenantId),
      history: List.unmodifiable(history.reversed),
    );
  }

  int _total(int tenantId) => (_history[tenantId] ?? const <PointEntry>[])
      .fold<int>(0, (s, e) => s + e.points);

  @override
  Future<List<CustomerVoucher>> getVouchers(int tenantId) async {
    await MockDelay.short();
    return List.unmodifiable(_vouchers[tenantId] ?? const []);
  }

  @override
  Future<ClaimResult> claimOrder({
    required int tenantId,
    required Platform platform,
    required String orderCode,
  }) async {
    await MockDelay.short();
    final now = _clock();
    final lockedUntil = _lockedUntil[tenantId];
    if (lockedUntil != null && now.isBefore(lockedUntil)) {
      throw ClaimFailure(
        ClaimEligibility.tooManyAttempts,
        retryAfter: lockedUntil.difference(now),
      );
    }

    final code = orderCode.trim().toUpperCase();
    final match = tenantId != 1
        ? null
        : MockData.claimableOrders
              .where((o) => o.$1.toUpperCase() == code && o.$2 == platform)
              .firstOrNull;
    final claimed = (_history[tenantId] ?? const <PointEntry>[])
        .where((e) => e.orderCode == code)
        .firstOrNull;

    final eligibility = match == null
        ? ClaimEligibility.notFound
        : LoyaltyRules.checkEligibility(
            completedAt: match.$4,
            alreadyClaimed: claimed != null,
            now: now,
          );

    if (eligibility != ClaimEligibility.eligible) {
      final failures = (_failures[tenantId] ?? 0) + 1;
      _failures[tenantId] = failures;
      // Đủ số lần sai: khóa và đếm lại từ đầu sau khi hết khóa.
      if (failures >= _maxFailures) {
        _lockedUntil[tenantId] = now.add(_lockFor);
        _failures.remove(tenantId);
      }
      throw ClaimFailure(
        eligibility,
        completedAt: match?.$4,
        claimedAt: claimed?.claimedAt,
      );
    }

    _failures.remove(tenantId);
    final before = _total(tenantId);
    final points = LoyaltyRules.pointsForAmount(match!.$3);
    (_history[tenantId] ??= []).add(
      PointEntry(
        orderCode: code,
        platform: platform,
        points: points,
        claimedAt: now,
      ),
    );
    return ClaimResult(
      orderCode: code,
      platform: platform,
      amountPaid: match.$3,
      points: points,
      pointsBefore: before,
      claimedAt: now,
    );
  }
}
