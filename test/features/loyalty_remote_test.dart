import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/features/loyalty/data/loyalty_remote_repository.dart';
import 'package:smartomni_mobile/features/loyalty/domain/loyalty_rules.dart';

/// `LoyaltyProfileDto` đúng như `LoyaltyTierCalculator.buildProfile` của BE
/// `361e8b5` trả cho [points] điểm (bảng chép từ code BE).
Map<String, Object?> _profile(int points) {
  final (tier, next, threshold) = switch (points) {
    >= 1500 => ('Diamond', null, null),
    >= 1000 => ('Platinum', 'Diamond', 1500),
    >= 500 => ('Silver', 'Platinum', 1000),
    _ => ('Standard', 'Silver', 500),
  };
  return {
    'customerId': 42,
    'tenantId': 3,
    'totalPoints': points,
    'tier': tier,
    'nextTier': next,
    'nextTierThreshold': threshold,
    'pointsToNextTier': threshold == null ? 0 : threshold - points,
  };
}

void main() {
  group('LoyaltyRules khớp BE 361e8b5', () {
    test(
      'hạng, hạng kế, ngưỡng, điểm còn thiếu giống LoyaltyTierCalculator',
      () {
        for (final p in [0, 1, 499, 500, 501, 999, 1000, 1499, 1500, 9999]) {
          final be = _profile(p);
          final tier = LoyaltyRules.tierFor(p);
          expect(tier.label, be['tier'], reason: '$p điểm');
          expect(tier.next?.label, be['nextTier'], reason: '$p điểm');
          expect(tier.next?.minPoints, be['nextTierThreshold'], reason: '$p');
          expect(
            LoyaltyRules.pointsToNextTier(p),
            be['pointsToNextTier'],
            reason: '$p điểm',
          );
        }
      },
    );

    test('ngưỡng SILVER 500, PLATINUM 1000, DIAMOND 1500', () {
      expect(LoyaltyTier.silver.minPoints, 500);
      expect(LoyaltyTier.platinum.minPoints, 1000);
      expect(LoyaltyTier.diamond.minPoints, 1500);
    });

    test('1 điểm / 1.000 ₫ làm tròn xuống như claimOrderPoints '
        '(totalAmount / 1000, RoundingMode.FLOOR)', () {
      int be(num amount) => (amount / 1000).floor();
      for (final amount in [1000, 1999, 125000, 520500, 999999]) {
        expect(LoyaltyRules.pointsForAmount(amount), be(amount));
      }
    });
  });

  group('LoyaltyTier.fromBackend', () {
    test('đọc 4 hạng của BE, không phân biệt hoa thường', () {
      expect(LoyaltyTier.fromBackend('Standard'), LoyaltyTier.standard);
      expect(LoyaltyTier.fromBackend('Silver'), LoyaltyTier.silver);
      expect(LoyaltyTier.fromBackend('PLATINUM'), LoyaltyTier.platinum);
      expect(LoyaltyTier.fromBackend(' diamond '), LoyaltyTier.diamond);
    });

    test('null, rỗng, tên lạ trả null', () {
      expect(LoyaltyTier.fromBackend(null), isNull);
      expect(LoyaltyTier.fromBackend(''), isNull);
      expect(LoyaltyTier.fromBackend('Gold'), isNull);
    });
  });

  group('LoyaltyJson.summary (GET /loyalty/me)', () {
    test('đọc LoyaltyProfileDto: dùng hạng và điểm còn thiếu của BE', () {
      final s = LoyaltyJson.summary(_profile(620));
      expect(s.totalPoints, 620);
      expect(s.tier, LoyaltyTier.silver);
      expect(s.pointsToNext, 380);
      expect(s.history, isEmpty);
    });

    test('hạng cao nhất: nextTier, nextTierThreshold null', () {
      final s = LoyaltyJson.summary(_profile(1800));
      expect(s.tier, LoyaltyTier.diamond);
      expect(s.tier.next, isNull);
      expect(s.pointsToNext, 0);
    });

    test(
      'tier null hoặc lạ: tính hạng theo điểm, không tin pointsToNextTier',
      () {
        final s = LoyaltyJson.summary({
          'totalPoints': 120,
          'tier': null,
          'pointsToNextTier': 9999,
        });
        expect(s.tier, LoyaltyTier.standard);
        expect(s.pointsToNext, 380);
        expect(
          LoyaltyJson.summary({'totalPoints': 700, 'tier': 'Gold'}).tier,
          LoyaltyTier.silver,
        );
      },
    );

    test('thiếu dữ liệu: data null, thiếu điểm, điểm âm, số dạng chuỗi', () {
      final empty = LoyaltyJson.summary(null);
      expect(empty.totalPoints, 0);
      expect(empty.tier, LoyaltyTier.standard);
      expect(empty.pointsToNext, 500);
      expect(LoyaltyJson.summary(const {}).totalPoints, 0);
      expect(LoyaltyJson.summary({'totalPoints': -5}).totalPoints, 0);
      expect(
        LoyaltyJson.summary({
          'totalPoints': '1200',
          'tier': 'Platinum',
        }).pointsToNext,
        300,
      );
    });
  });
}
