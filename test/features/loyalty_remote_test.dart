import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/models/platform.dart';
import 'package:smartomni_mobile/core/network/api_exception.dart';
import 'package:smartomni_mobile/core/network/api_paths.dart';
import 'package:smartomni_mobile/core/utils/mock_delay.dart';
import 'package:smartomni_mobile/features/loyalty/data/loyalty_mock_repository.dart';
import 'package:smartomni_mobile/features/loyalty/data/loyalty_remote_repository.dart';
import 'package:smartomni_mobile/features/loyalty/domain/loyalty_repository.dart';
import 'package:smartomni_mobile/features/loyalty/domain/loyalty_rules.dart';
import 'package:smartomni_mobile/features/loyalty/presentation/loyalty_providers.dart';
import 'package:smartomni_mobile/features/loyalty/presentation/loyalty_screen.dart';

import '../helpers/fake_backend.dart';
import '../helpers/test_app.dart';

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

/// `LoyaltyRewardRequestDto` như `LoyaltyRewardService.mapRequest` trả.
Map<String, Object?> _voucher({
  required int id,
  required String status,
  String? code,
  String? campaignName = 'Tri ân hạng Bạc',
  Object? discountPercent = 10.00,
}) => {
  'id': id,
  'tenantId': 3,
  'campaignId': 5,
  'campaignName': campaignName,
  'discountPercent': discountPercent,
  'customerId': 42,
  'requestKey': '6f1c2d3e-0000-4000-8000-000000000001',
  'status': status,
  'code': code,
  'externalVoucherId': code == null ? null : 'ext-$id',
  'failureReason': status == 'failed' ? 'Shop disconnected' : null,
  'requestedAt': '2026-11-10T02:00:00Z',
  'issuedAt': code == null ? null : '2026-11-10T02:05:00Z',
  'updatedAt': '2026-11-10T02:05:00Z',
};

/// BE giả cho 3 endpoint của C-20.
FakeBackend _loyaltyBackend({
  int points = 620,
  List<Object?> claims = const [],
  List<Object?> vouchers = const [],
}) => FakeBackend(
  (o) async => switch (o.path) {
    ApiPaths.loyaltyMe => (200, ok(_profile(points))),
    ApiPaths.loyaltyMyClaims => (200, ok(claims)),
    ApiPaths.loyaltyMyVouchers => (200, ok(vouchers)),
    _ => (404, apiError('Not found')),
  },
);

void main() {
  setUp(() => MockDelay.enabled = false);

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

  group('LoyaltyJson.claims (GET /loyalty/me/claims)', () {
    test('đọc LoyaltyClaimDto: "Đơn #<orderId>", không có sàn', () {
      final list = LoyaltyJson.claims([
        {
          'id': 9,
          'orderId': 1024,
          'customerId': 42,
          'eligibleAmountVnd': 125000.00,
          'pointsAwarded': 125,
          'claimedAt': '2026-11-01T03:15:00Z',
        },
        {
          'id': 8,
          'orderId': 1001,
          'customerId': 42,
          'eligibleAmountVnd': 520500,
          'pointsAwarded': 520,
          'claimedAt': '2026-10-20T10:00:00.123456Z',
        },
      ]);
      expect(list, hasLength(2));
      final e = list.first;
      expect(e.orderCode, 'Đơn #1024');
      expect(e.platform, isNull);
      expect(e.points, 125);
      expect(e.amountPaid, 125000);
      expect(e.claimedAt, DateTime.utc(2026, 11, 1, 3, 15).toLocal());
      // Giữ thứ tự BE (mới trước cũ).
      expect(list.last.orderCode, 'Đơn #1001');
    });

    test(
      'thiếu dữ liệu: thiếu điểm thì tính từ tiền, thiếu ngày, thiếu đơn',
      () {
        final e = LoyaltyJson.claim({
          'orderId': '77',
          'eligibleAmountVnd': '45900',
          'claimedAt': null,
        });
        expect(e.orderCode, 'Đơn #77');
        expect(e.points, 45);
        expect(e.claimedAt, isNull);

        final bare = LoyaltyJson.claim(const {});
        expect(bare.orderCode, 'Đơn không rõ mã');
        expect(bare.points, 0);
        expect(bare.amountPaid, isNull);
      },
    );

    test('data null hoặc phần tử hỏng: bỏ qua, không lỗi', () {
      expect(LoyaltyJson.claims(null), isEmpty);
      expect(LoyaltyJson.claims(const {}), isEmpty);
      expect(
        LoyaltyJson.claims([null, 'x', <String, dynamic>{}]),
        hasLength(1),
      );
    });
  });

  group('LoyaltyJson.vouchers (GET /loyalty/me/vouchers)', () {
    test('đã phát: có mã, mô tả từ campaignName + discountPercent', () {
      final v = LoyaltyJson.voucher(
        _voucher(id: 1, status: 'issued', code: 'SO-SILVER-7Q2'),
      );
      expect(v.id, 1);
      expect(v.code, 'SO-SILVER-7Q2');
      expect(v.description, 'Tri ân hạng Bạc · Giảm 10%');
      expect(v.status, VoucherIssueStatus.issued);
      expect(v.status.label, isNull);
      // L4: BE chưa có sàn và hạn dùng.
      expect(v.platform, isNull);
      expect(v.expiresAt, isNull);
    });

    test('chưa phát xong: không mã, nhãn trung tính theo status', () {
      final pending = LoyaltyJson.voucher(_voucher(id: 2, status: 'pending'));
      expect(pending.code, isNull);
      expect(pending.status, VoucherIssueStatus.pending);
      expect(pending.status.label, 'Đang phát');
      expect(
        LoyaltyJson.voucher(_voucher(id: 3, status: 'FAILED')).status.label,
        'Chưa phát được',
      );
      expect(
        LoyaltyJson.voucher(_voucher(id: 4, status: 'reserved')).status,
        VoucherIssueStatus.unknown,
      );
      expect(VoucherIssueStatus.fromBackend(null), VoucherIssueStatus.unknown);
    });

    test('thiếu dữ liệu: mã rỗng, thiếu tên, % lẻ hoặc dạng chuỗi', () {
      final blank = LoyaltyJson.voucher(
        _voucher(id: 5, status: 'issued', code: '  '),
      );
      expect(blank.code, isNull);
      expect(
        LoyaltyJson.voucher(
          _voucher(id: 6, status: 'issued', campaignName: null),
        ).description,
        'Giảm 10%',
      );
      expect(
        LoyaltyJson.voucher(
          _voucher(id: 7, status: 'issued', discountPercent: '12.5'),
        ).description,
        'Tri ân hạng Bạc · Giảm 12,5%',
      );
      final bare = LoyaltyJson.voucher(const {});
      expect(bare.description, 'Voucher');
      expect(bare.id, isNull);
      expect(bare.status, VoucherIssueStatus.unknown);
      expect(LoyaltyJson.vouchers(null), isEmpty);
      expect(LoyaltyJson.vouchers([42, null]), isEmpty);
    });
  });

  group('LoyaltyRemoteRepository', () {
    test('gọi đúng 3 endpoint, không gửi X-Tenant-Id hay tenantId', () async {
      final backend = _loyaltyBackend(
        points: 1200,
        claims: [
          {'orderId': 5, 'pointsAwarded': 1200, 'claimedAt': null},
        ],
        vouchers: [_voucher(id: 1, status: 'issued', code: 'A1')],
      );
      final repo = LoyaltyRemoteRepository(
        fakeDio(backend),
        claims: LoyaltyMockRepository(),
      );
      final summary = await repo.getSummary(99);
      final vouchers = await repo.getVouchers(99);

      expect(summary.totalPoints, 1200);
      expect(summary.tier, LoyaltyTier.platinum);
      expect(summary.history.single.orderCode, 'Đơn #5');
      expect(vouchers.single.code, 'A1');
      expect(backend.requests.map((r) => r.path).toSet(), {
        ApiPaths.loyaltyMe,
        ApiPaths.loyaltyMyClaims,
        ApiPaths.loyaltyMyVouchers,
      });
      for (final r in backend.requests) {
        expect(r.method, 'GET');
        expect(r.queryParameters, isEmpty);
        expect(
          r.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('x-tenant-id')),
        );
      }
    });

    test('lỗi một trong hai request của getSummary thì ném ApiException', () {
      final backend = FakeBackend(
        (o) async => o.path == ApiPaths.loyaltyMyClaims
            ? (403, apiError('Access denied'))
            : (200, ok(_profile(10))),
      );
      final repo = LoyaltyRemoteRepository(
        fakeDio(backend),
        claims: LoyaltyMockRepository(),
      );
      expect(repo.getSummary(1), throwsA(isA<ApiException>()));
    });

    test('C-30 claim đơn vẫn chạy mock (lỗi L2), không gọi BE', () async {
      final backend = _loyaltyBackend();
      final repo = LoyaltyRemoteRepository(
        fakeDio(backend),
        claims: LoyaltyMockRepository(),
      );
      await expectLater(
        repo.claimOrder(
          tenantId: 1,
          platform: Platform.shopee,
          orderCode: 'KHONGCO',
        ),
        throwsA(isA<ClaimFailure>()),
      );
      expect(backend.requests, isEmpty);
    });
  });

  testWidgets('C-20 BE thật: không banner, đơn #id không nhãn sàn, voucher '
      'chưa phát không có nút Sao chép', (tester) async {
    final backend = _loyaltyBackend(
      points: 620,
      claims: [
        {
          'id': 1,
          'orderId': 1024,
          'customerId': 42,
          'eligibleAmountVnd': 125000,
          'pointsAwarded': 125,
          'claimedAt': '2026-11-01T03:15:00Z',
        },
      ],
      vouchers: [
        _voucher(id: 1, status: 'issued', code: 'SO-SILVER-7Q2'),
        _voucher(id: 2, status: 'pending'),
      ],
    );
    await loginAs(
      tester,
      'customer@demo.vn',
      tallView: true,
      overrides: [
        loyaltyUseRemoteProvider.overrideWithValue(true),
        loyaltyRepositoryProvider.overrideWithValue(
          LoyaltyRemoteRepository(
            fakeDio(backend),
            claims: LoyaltyMockRepository(),
          ),
        ),
      ],
    );
    await tester.tap(find.text('Điểm & hạng'));
    await tester.pumpAndSettle();
    expect(find.byType(LoyaltyScreen), findsOneWidget);

    expect(find.byType(SoMockBanner), findsNothing);
    expect(find.text('620'), findsOneWidget);
    expect(
      tester.widget<SoTierBadge>(find.byType(SoTierBadge)).tier,
      LoyaltyTier.silver,
    );

    // Lịch sử: "Đơn #1024", không nhãn sàn.
    final row = find.byKey(const Key('history_Đơn #1024'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.byType(SoChannelTag)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.textContaining('125.000 ₫ · Claim ngày'),
      ),
      findsOneWidget,
    );

    // Voucher đã phát: mã + Sao chép; chưa phát: nhãn trung tính, không nút.
    final issued = find.byKey(const Key('voucher_SO-SILVER-7Q2'));
    expect(issued, findsOneWidget);
    expect(find.byKey(const Key('copy_SO-SILVER-7Q2')), findsOneWidget);
    expect(
      find.descendant(of: issued, matching: find.byType(SoChannelTag)),
      findsNothing,
    );
    final pending = find.byKey(const Key('voucher_id2'));
    expect(pending, findsOneWidget);
    expect(
      find.descendant(of: pending, matching: find.text('Đang phát')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: pending, matching: find.byType(SoButton)),
      findsNothing,
    );
    expect(
      tester
          .widget<SoStatusTag>(
            find.descendant(of: pending, matching: find.byType(SoStatusTag)),
          )
          .status,
      SoStatus.neutral,
    );
  });
}
