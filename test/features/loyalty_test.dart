import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/models/platform.dart';
import 'package:smartomni_mobile/core/utils/mock_delay.dart';
import 'package:smartomni_mobile/features/customer_shop/data/customer_shop_mock_repository.dart';
import 'package:smartomni_mobile/features/loyalty/data/loyalty_mock_repository.dart';
import 'package:smartomni_mobile/features/loyalty/domain/loyalty_repository.dart';
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
    // Đồng hồ cố định để ngày trong lỗi xác định được.
    final now = DateTime(2026, 10, 20, 10, 30);
    LoyaltyMockRepository repo() => LoyaltyMockRepository(clock: () => now);

    Future<ClaimResult> claim(
      LoyaltyMockRepository r,
      String code, {
      int tenantId = 1,
      Platform platform = Platform.shopee,
    }) => r.claimOrder(tenantId: tenantId, platform: platform, orderCode: code);

    Matcher failure(ClaimEligibility kind) =>
        throwsA(isA<ClaimFailure>().having((f) => f.kind, 'kind', kind));

    test(
      'claim hợp lệ: điểm cũ → mới, lên hạng; không cho claim lần 2',
      () async {
        final r = repo();
        final result = await claim(r, '240920shop01');
        expect(result.orderCode, '240920SHOP01');
        expect(result.amountPaid, 520000);
        expect(result.points, 520);
        expect(result.pointsBefore, 620);
        expect(result.pointsAfter, 1140);
        expect(result.tierBefore, LoyaltyTier.silver);
        expect(result.tierAfter, LoyaltyTier.platinum);
        expect(result.tieredUp, isTrue);
        expect((await r.getSummary(1)).totalPoints, 1140);

        await expectLater(
          claim(r, '240920SHOP01'),
          throwsA(
            isA<ClaimFailure>()
                .having((f) => f.kind, 'kind', ClaimEligibility.alreadyClaimed)
                .having((f) => f.claimedAt, 'claimedAt', now),
          ),
        );
      },
    );

    test('chưa đủ 15 ngày: kèm ngày hoàn tất và ngày được claim', () async {
      await expectLater(
        claim(repo(), '241008SHOP02'),
        throwsA(
          isA<ClaimFailure>()
              .having((f) => f.kind, 'kind', ClaimEligibility.tooEarly)
              .having(
                (f) => f.claimableFrom!.difference(f.completedAt!),
                'chờ',
                LoyaltyRules.claimWaitingPeriod,
              ),
        ),
      );
    });

    test('chưa hoàn tất, sai sàn, cửa hàng khác', () {
      final r = repo();
      expect(
        () => claim(r, '241012SHOP03'),
        failure(ClaimEligibility.notCompleted),
      );
      expect(
        () => claim(r, '240920SHOP01', platform: Platform.tiktokShop),
        failure(ClaimEligibility.notFound),
      );
      expect(
        () => claim(r, '240920SHOP01', tenantId: 2),
        failure(ClaimEligibility.notFound),
      );
    });

    test('sai 5 lần liên tiếp thì tạm khóa 30 phút', () async {
      final r = repo();
      for (var i = 0; i < 5; i++) {
        await expectLater(
          claim(r, 'SAI$i'),
          failure(ClaimEligibility.notFound),
        );
      }
      await expectLater(
        claim(r, '240920SHOP01'),
        throwsA(
          isA<ClaimFailure>()
              .having((f) => f.kind, 'kind', ClaimEligibility.tooManyAttempts)
              .having(
                (f) => f.retryAfter,
                'retryAfter',
                const Duration(minutes: 30),
              ),
        ),
      );
    });

    test('claim hợp lệ đặt lại bộ đếm lần sai', () async {
      final r = repo();
      for (var i = 0; i < 4; i++) {
        await expectLater(
          claim(r, 'SAI$i'),
          failure(ClaimEligibility.notFound),
        );
      }
      await claim(r, '240920SHOP01');
      await expectLater(claim(r, 'SAI9'), failure(ClaimEligibility.notFound));
    });
  });

  group('thẻ hạng và voucher (C-20)', () {
    test('tierSegments: 3 nấc Standard→Silver→Platinum→Diamond', () {
      expect(LoyaltyRules.tierSegments(0), [0, 0, 0]);
      expect(LoyaltyRules.tierSegments(250), [0.5, 0, 0]);
      expect(LoyaltyRules.tierSegments(620), [1, closeTo(0.24, 1e-9), 0]);
      expect(LoyaltyRules.tierSegments(1500), [1, 1, 1]);
      expect(LoyaltyRules.tierSegments(9000), [1, 1, 1]);
    });

    test('voucherDaysLeft tính theo ngày lịch', () {
      final now = DateTime(2026, 10, 20, 23, 30);
      expect(LoyaltyRules.voucherDaysLeft(null, now), isNull);
      expect(LoyaltyRules.voucherDaysLeft(DateTime(2026, 10, 20, 8), now), 0);
      expect(LoyaltyRules.voucherDaysLeft(DateTime(2026, 11, 3), now), 14);
      expect(LoyaltyRules.voucherDaysLeft(DateTime(2026, 10, 19), now), -1);
    });
  });

  group('LoyaltyMockRepository theo cửa hàng', () {
    test(
      'điểm khớp C-00: Shop Demo 620, Hoa Mộc 120, cửa hàng khác 0',
      () async {
        final repo = LoyaltyMockRepository();
        final shops = await CustomerShopMockRepository().listMyShops();
        for (final shop in shops) {
          expect(
            (await repo.getSummary(shop.tenantId)).totalPoints,
            shop.points,
            reason: shop.name,
          );
        }
        expect((await repo.getSummary(3)).totalPoints, 0);
        expect(await repo.getVouchers(1), hasLength(2));
        expect(await repo.getVouchers(2), isEmpty);
      },
    );
  });
}
