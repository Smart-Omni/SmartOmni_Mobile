import '../../../core/mock/mock_data.dart';
import '../../../core/models/platform.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/loyalty_repository.dart';
import '../domain/loyalty_rules.dart';

class LoyaltyMockRepository implements LoyaltyRepository {
  LoyaltyMockRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  final List<PointEntry> _history = [
    PointEntry(
      orderCode: '240801SHOP99',
      platform: Platform.shopee,
      points: 380,
      claimedAt: MockData.daysAgo(40),
    ),
  ];

  /// Mã đơn đã claim (trong tenant). Mỗi đơn chỉ claim 1 lần.
  final Set<String> _claimed = {'240801SHOP99'};

  @override
  Future<LoyaltySummary> getSummary() async {
    await MockDelay.short();
    final total = _history.fold<int>(0, (s, e) => s + e.points);
    return LoyaltySummary(
      totalPoints: total,
      history: List.unmodifiable(_history.reversed),
    );
  }

  @override
  Future<List<CustomerVoucher>> getVouchers() async {
    await MockDelay.short();
    return [
      CustomerVoucher(
        code: 'SILVER50K',
        platform: Platform.shopee,
        description: 'Giảm 50.000 ₫ cho đơn từ 300.000 ₫',
        expiresAt: MockData.daysAgo(-20),
      ),
    ];
  }

  @override
  Future<int> claimOrder({
    required Platform platform,
    required String orderCode,
  }) async {
    await MockDelay.short();
    final code = orderCode.trim().toUpperCase();
    final match = MockData.claimableOrders
        .where((o) => o.$1.toUpperCase() == code && o.$2 == platform)
        .firstOrNull;

    final eligibility = match == null
        ? ClaimEligibility.notFound
        : LoyaltyRules.checkEligibility(
            completedAt: match.$4,
            alreadyClaimed: _claimed.contains(code),
            now: _clock(),
          );

    if (eligibility != ClaimEligibility.eligible) {
      throw ApiException(
        type: ApiErrorType.validation,
        message: eligibility.message,
      );
    }

    final points = LoyaltyRules.pointsForAmount(match!.$3);
    _claimed.add(code);
    _history.add(
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
