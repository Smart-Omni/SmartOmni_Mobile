import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/models/platform.dart';
import 'package:smartomni_mobile/core/network/api_exception.dart';
import 'package:smartomni_mobile/core/utils/mock_delay.dart';
import 'package:smartomni_mobile/features/loyalty/data/loyalty_mock_repository.dart';
import 'package:smartomni_mobile/features/loyalty/domain/loyalty_rules.dart';

void main() {
  setUpAll(() => MockDelay.enabled = false);

  group('LoyaltyRules.pointsForAmount', () {
    test('1 điểm / 1.000 ₫, làm tròn xuống', () {
      expect(LoyaltyRules.pointsForAmount(0), 0);
      expect(LoyaltyRules.pointsForAmount(999), 0);
      expect(LoyaltyRules.pointsForAmount(1000), 1);
      expect(LoyaltyRules.pointsForAmount(520500), 520);
      expect(LoyaltyRules.pointsForAmount(-5000), 0);
    });
  });

  group('LoyaltyRules.tierFor', () {
    test(
      'ngưỡng hạng: Standard < 500 ≤ Silver < 1000 ≤ Platinum < 1500 ≤ Diamond',
      () {
        expect(LoyaltyRules.tierFor(0), LoyaltyTier.standard);
        expect(LoyaltyRules.tierFor(499), LoyaltyTier.standard);
        expect(LoyaltyRules.tierFor(500), LoyaltyTier.silver);
        expect(LoyaltyRules.tierFor(999), LoyaltyTier.silver);
        expect(LoyaltyRules.tierFor(1000), LoyaltyTier.platinum);
        expect(LoyaltyRules.tierFor(1499), LoyaltyTier.platinum);
        expect(LoyaltyRules.tierFor(1500), LoyaltyTier.diamond);
        expect(LoyaltyRules.tierFor(99999), LoyaltyTier.diamond);
      },
    );

    test('điểm còn thiếu để lên hạng', () {
      expect(LoyaltyRules.pointsToNextTier(380), 120);
      expect(LoyaltyRules.pointsToNextTier(1200), 300);
      expect(LoyaltyRules.pointsToNextTier(2000), 0);
    });
  });

  group('LoyaltyRules.checkEligibility', () {
    final completed = DateTime(2026, 10, 1);

    test('chưa hoàn tất', () {
      expect(
        LoyaltyRules.checkEligibility(completedAt: null, alreadyClaimed: false),
        ClaimEligibility.notCompleted,
      );
    });

    test('chưa đủ 15 ngày', () {
      expect(
        LoyaltyRules.checkEligibility(
          completedAt: completed,
          alreadyClaimed: false,
          now: DateTime(2026, 10, 15, 23, 59),
        ),
        ClaimEligibility.tooEarly,
      );
    });

    test('đủ 15 ngày', () {
      expect(
        LoyaltyRules.checkEligibility(
          completedAt: completed,
          alreadyClaimed: false,
          now: DateTime(2026, 10, 16),
        ),
        ClaimEligibility.eligible,
      );
    });

    test('đã claim thì không claim lại', () {
      expect(
        LoyaltyRules.checkEligibility(
          completedAt: completed,
          alreadyClaimed: true,
          now: DateTime(2026, 12, 1),
        ),
        ClaimEligibility.alreadyClaimed,
      );
    });
  });

  group('LoyaltyMockRepository.claimOrder', () {
    test('claim hợp lệ cộng điểm và không cho claim lần 2', () async {
      final repo = LoyaltyMockRepository();
      final before = (await repo.getSummary()).totalPoints;

      final points = await repo.claimOrder(
        platform: Platform.shopee,
        orderCode: '240920shop01',
      );
      expect(points, 520);
      expect((await repo.getSummary()).totalPoints, before + 520);

      expect(
        () => repo.claimOrder(
          platform: Platform.shopee,
          orderCode: '240920SHOP01',
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('sai sàn -> không tìm thấy', () async {
      final repo = LoyaltyMockRepository();
      expect(
        () => repo.claimOrder(
          platform: Platform.tiktokShop,
          orderCode: '240920SHOP01',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            ClaimEligibility.notFound.message,
          ),
        ),
      );
    });
  });
}
