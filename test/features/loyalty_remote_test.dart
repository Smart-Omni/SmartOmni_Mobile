import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/models/platform.dart';
import 'package:smartomni_mobile/core/network/api_exception.dart';
import 'package:smartomni_mobile/core/network/api_paths.dart';
import 'package:smartomni_mobile/core/utils/mock_delay.dart';
import 'package:smartomni_mobile/features/loyalty/data/loyalty_remote_repository.dart';
import 'package:smartomni_mobile/features/loyalty/domain/loyalty_repository.dart';
import 'package:smartomni_mobile/features/loyalty/domain/loyalty_rules.dart';
import 'package:smartomni_mobile/features/loyalty/presentation/claim_order_screen.dart';
import 'package:smartomni_mobile/features/loyalty/presentation/claim_result_screen.dart';
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
    >= 500 => ('Gold', 'Platinum', 1000),
    _ => ('Standard', 'Gold', 500),
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

    test('ngưỡng GOLD 500, PLATINUM 1000, DIAMOND 1500', () {
      expect(LoyaltyTier.gold.minPoints, 500);
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
      expect(LoyaltyTier.fromBackend('Gold'), LoyaltyTier.gold);
      expect(LoyaltyTier.fromBackend('PLATINUM'), LoyaltyTier.platinum);
      expect(LoyaltyTier.fromBackend(' diamond '), LoyaltyTier.diamond);
    });

    test('null, rỗng, tên lạ trả null; "Silver" (tên cũ) là Gold', () {
      expect(LoyaltyTier.fromBackend(null), isNull);
      expect(LoyaltyTier.fromBackend(''), isNull);
      expect(LoyaltyTier.fromBackend('Vàng'), isNull);
      expect(LoyaltyTier.fromBackend('Silver'), LoyaltyTier.gold);
    });
  });

  group('LoyaltyJson.summary (GET /loyalty/me)', () {
    test('đọc LoyaltyProfileDto: dùng hạng và điểm còn thiếu của BE', () {
      final s = LoyaltyJson.summary(_profile(620));
      expect(s.totalPoints, 620);
      expect(s.tier, LoyaltyTier.gold);
      expect(s.pointsToNext, 380);
      expect(s.history, isEmpty);
    });

    test('hạng cao nhất: nextTier, nextTierThreshold null', () {
      final s = LoyaltyJson.summary(_profile(1800));
      expect(s.tier, LoyaltyTier.diamond);
      expect(s.nextTierLabel, isNull);
      expect(s.pointsToNext, 0);
    });

    test('tier thiếu: tính hạng theo điểm, không tin pointsToNextTier', () {
      final s = LoyaltyJson.summary({
        'totalPoints': 120,
        'tier': null,
        'nextTier': 'Diamond',
        'pointsToNextTier': 9999,
      });
      expect(s.tier, LoyaltyTier.standard);
      expect(s.tierLabel, 'Standard');
      expect(s.nextTierLabel, 'Gold');
      expect(s.pointsToNext, 380);
      expect(
        LoyaltyJson.summary({'totalPoints': 700, 'tier': ' '}).tierLabel,
        'Gold',
      );
    });

    test('hiện ĐÚNG tên tier BE trả, kể cả tên mốc shop tự đặt', () {
      final s = LoyaltyJson.summary({
        'totalPoints': 700,
        'tier': 'Hạng Vàng Shopee',
        'nextTier': 'Kim cương',
        'pointsToNextTier': 300,
      });
      expect(s.tierLabel, 'Hạng Vàng Shopee');
      expect(s.nextTierLabel, 'Kim cương');
      expect(s.pointsToNext, 300);
      // Tên lạ: màu huy hiệu theo hạng chuẩn của số điểm.
      expect(s.tier, LoyaltyTier.gold);

      // BE nói Standard dù 700 điểm (mốc shop cao hơn): tin BE.
      final low = LoyaltyJson.summary({
        'totalPoints': 700,
        'tier': 'Standard',
        'nextTier': 'Gold',
        'pointsToNextTier': 100,
      });
      expect(low.tierLabel, 'Standard');
      expect(low.tier, LoyaltyTier.standard);
      expect(low.pointsToNext, 100);

      final top = LoyaltyJson.summary({
        'totalPoints': 2000,
        'tier': 'VIP',
        'nextTier': null,
        'pointsToNextTier': 0,
      });
      expect(top.nextTierLabel, isNull);
      expect(top.pointsToNext, 0);
    });

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
        _voucher(id: 1, status: 'issued', code: 'SO-GOLD-7Q2'),
      );
      expect(v.id, 1);
      expect(v.code, 'SO-GOLD-7Q2');
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
      final repo = LoyaltyRemoteRepository(fakeDio(backend));
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
      final repo = LoyaltyRemoteRepository(fakeDio(backend));
      expect(repo.getSummary(1), throwsA(isA<ApiException>()));
    });

    test('C-30 claim: POST /loyalty/claims với platformOrderId + platform, '
        'đọc LoyaltyClaimDto, tổng điểm mới từ /me', () async {
      final backend = FakeBackend(
        (o) async => switch ((o.method, o.path)) {
          ('POST', ApiPaths.loyaltyClaims) => (
            201,
            ok({
              'id': 9,
              'orderId': 77,
              'customerId': 42,
              'eligibleAmountVnd': 520000,
              'pointsAwarded': 520,
              'claimedAt': '2026-11-27T03:00:00Z',
            }),
          ),
          ('GET', ApiPaths.loyaltyMe) => (200, ok(_profile(1140))),
          _ => (404, apiError('Not found')),
        },
      );
      final repo = LoyaltyRemoteRepository(fakeDio(backend));
      final r = await repo.claimOrder(
        tenantId: 1,
        platform: Platform.tiktokShop,
        orderCode: ' 5760028171077135663 ',
      );

      final post = backend.requests.first;
      expect(post.method, 'POST');
      expect(post.path, ApiPaths.loyaltyClaims);
      expect(post.data, {
        'platformOrderId': '5760028171077135663',
        'platform': 'TIKTOK_SHOP',
      });
      expect(r.points, 520);
      expect(r.amountPaid, 520000);
      expect(r.orderCode, '5760028171077135663');
      expect(r.pointsBefore, 620);
      expect(r.pointsAfter, 1140);
      expect(r.tieredUp, isTrue);
      expect(r.claimedAt, DateTime.utc(2026, 11, 27, 3).toLocal());
    });

    test(
      'claim xong nhưng /me lỗi: vẫn thành công, không có điểm cũ',
      () async {
        final backend = FakeBackend(
          (o) async => o.method == 'POST'
              ? (201, ok({'pointsAwarded': 12, 'claimedAt': null}))
              : (500, apiError('boom')),
        );
        final r = await LoyaltyRemoteRepository(
          fakeDio(backend),
        ).claimOrder(tenantId: 1, platform: Platform.shopee, orderCode: 'A1');
        expect(r.points, 12);
        expect(r.pointsBefore, isNull);
        expect(r.amountPaid, isNull);
        expect(r.tieredUp, isFalse);
        expect(backend.requests.first.data, {
          'platformOrderId': 'A1',
          'platform': 'SHOPEE',
        });
      },
    );

    Future<Object?> claimError(int status, String code, String message) async {
      final backend = FakeBackend(
        (o) async =>
            (status, {'success': false, 'message': message, 'code': code}),
      );
      try {
        await LoyaltyRemoteRepository(
          fakeDio(backend),
        ).claimOrder(tenantId: 1, platform: Platform.shopee, orderCode: 'X');
      } catch (e) {
        return e;
      }
      fail('claimOrder phải ném lỗi');
    }

    test('mã lỗi BE → ClaimFailure đúng loại', () async {
      final cases = {
        (404, 'ORDER_NOT_FOUND'): ClaimEligibility.notFound,
        (400, 'ORDER_NOT_COMPLETED'): ClaimEligibility.notCompleted,
        (400, 'ORDER_NOT_ELIGIBLE_YET'): ClaimEligibility.tooEarly,
        (409, 'ORDER_ALREADY_CLAIMED'): ClaimEligibility.alreadyClaimed,
        (409, 'PLATFORM_REQUIRED'): ClaimEligibility.platformRequired,
        (409, 'ORDER_SYNCING'): ClaimEligibility.syncing,
        (429, 'TOO_MANY_CLAIM_ATTEMPTS'): ClaimEligibility.tooManyAttempts,
      };
      for (final MapEntry(key: (status, code), :value) in cases.entries) {
        final e = await claimError(status, code, 'English message');
        expect(e, isA<ClaimFailure>(), reason: code);
        expect((e! as ClaimFailure).kind, value, reason: code);
      }
    });

    test(
      'ORDER_NOT_ELIGIBLE_YET: đọc ngày đủ điều kiện trong message',
      () async {
        final e = await claimError(
          400,
          'ORDER_NOT_ELIGIBLE_YET',
          'Order has not reached the 15-day eligibility date yet '
              '(eligible from 2026-12-09)',
        );
        expect((e! as ClaimFailure).claimableFrom, DateTime(2026, 12, 9));

        final noDate = await claimError(
          400,
          'ORDER_NOT_ELIGIBLE_YET',
          'Order has not reached the 15-day eligibility date yet',
        );
        expect((noDate! as ClaimFailure).claimableFrom, isNull);
      },
    );

    test('ngày đủ điều kiện trong body (data.eligibleForPointsAt)', () {
      final f = LoyaltyJson.claimFailure(
        const ApiException(
          type: ApiErrorType.validation,
          message: 'not yet',
          code: 'ORDER_NOT_ELIGIBLE_YET',
        ),
        body: {
          'data': {'eligibleForPointsAt': '2026-12-20T00:00:00+07:00'},
        },
      );
      expect(f!.claimableFrom, DateTime(2026, 12, 20));
    });

    test('mã lỗi khác: ApiException câu tiếng Việt, giữ mã', () async {
      final e = await claimError(
        400,
        'ORDER_HAS_APPROVED_RETURN',
        'Order with an approved or completed return/refund cannot be claimed',
      );
      expect(e, isA<ApiException>());
      final api = e! as ApiException;
      expect(api.code, 'ORDER_HAS_APPROVED_RETURN');
      expect(api.message, startsWith('Không claim được'));
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
        _voucher(id: 1, status: 'issued', code: 'SO-GOLD-7Q2'),
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
          LoyaltyRemoteRepository(fakeDio(backend)),
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
      LoyaltyTier.gold,
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
    final issued = find.byKey(const Key('voucher_SO-GOLD-7Q2'));
    expect(issued, findsOneWidget);
    expect(find.byKey(const Key('copy_SO-GOLD-7Q2')), findsOneWidget);
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

  Future<void> openRemoteClaim(WidgetTester tester, FakeBackend backend) async {
    await loginAs(
      tester,
      'customer@demo.vn',
      tallView: true,
      overrides: [
        loyaltyUseRemoteProvider.overrideWithValue(true),
        loyaltyRepositoryProvider.overrideWithValue(
          LoyaltyRemoteRepository(fakeDio(backend)),
        ),
      ],
    );
    await tester.tap(find.text('Claim đơn'));
    await tester.pumpAndSettle();
    expect(find.byType(ClaimOrderScreen), findsOneWidget);
  }

  Future<void> claimCode(WidgetTester tester, String code) async {
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('claim_code')),
        matching: find.byType(EditableText),
      ),
      code,
    );
    await tapVisible(tester, find.byKey(const Key('claim_submit')));
  }

  testWidgets('C-30 BE thật: không banner mock, claim thành công báo +điểm, '
      'C-20 tải lại và hiện đúng tên hạng BE', (tester) async {
    var points = 620;
    var tierName = 'Gold';
    final backend = FakeBackend((o) async {
      switch ((o.method, o.path)) {
        case ('POST', ApiPaths.loyaltyClaims):
          points += 520;
          tierName = 'Bạch Kim Shopee';
          return (
            201,
            ok({
              'orderId': 77,
              'eligibleAmountVnd': 520000,
              'pointsAwarded': 520,
              'claimedAt': '2026-11-27T03:00:00Z',
            }),
          );
        case ('GET', ApiPaths.loyaltyMe):
          return (200, ok({..._profile(points), 'tier': tierName}));
        case ('GET', ApiPaths.loyaltyMyClaims):
        case ('GET', ApiPaths.loyaltyMyVouchers):
          return (200, ok(const []));
      }
      return (404, apiError('Not found'));
    });
    await openRemoteClaim(tester, backend);
    expect(find.byType(SoMockBanner), findsNothing);

    await claimCode(tester, '5760028171077135663');
    expect(find.byType(ClaimResultScreen), findsOneWidget);
    expect(find.byKey(const Key('claim_success')), findsOneWidget);
    expect(find.text('+520 điểm'), findsOneWidget);
    expect(find.text('620 → 1.140'), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('claim_view_tier')));
    expect(find.byType(LoyaltyScreen), findsOneWidget);
    expect(find.text('1.140'), findsOneWidget);
    final badge = tester.widget<SoTierBadge>(
      find.byKey(const Key('tier_badge')),
    );
    expect(badge.label, 'Bạch Kim Shopee');
    expect(find.text('Bạch Kim Shopee'), findsOneWidget);
  });

  testWidgets('C-30 BE thật: ORDER_NOT_ELIGIBLE_YET hiện ngày BE báo', (
    tester,
  ) async {
    final backend = FakeBackend(
      (o) async => (
        400,
        {
          'success': false,
          'message':
              'Order has not reached the 15-day eligibility date yet '
              '(eligible from 2026-12-09)',
          'code': 'ORDER_NOT_ELIGIBLE_YET',
        },
      ),
    );
    await openRemoteClaim(tester, backend);
    await claimCode(tester, '5760028171077135663');

    final banner = find.byKey(const Key('claim_error_tooEarly'));
    expect(banner, findsOneWidget);
    expect(tester.widget<SoBanner>(banner).message, contains('09/12/2026'));
  });
}
