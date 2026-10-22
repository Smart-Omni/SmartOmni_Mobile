import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/models/platform.dart';
import 'package:smartomni_mobile/core/utils/clock.dart';
import 'package:smartomni_mobile/core/utils/mock_delay.dart';
import 'package:smartomni_mobile/features/loyalty/domain/loyalty_rules.dart';
import 'package:smartomni_mobile/features/voucher/data/voucher_mock_repository.dart';
import 'package:smartomni_mobile/features/voucher/domain/voucher.dart';
import 'package:smartomni_mobile/features/voucher/presentation/voucher_providers.dart';
import 'package:smartomni_mobile/features/voucher/presentation/voucher_screen.dart';

import '../helpers/test_app.dart';

final _now = DateTime(2026, 10, 22, 9);

const _customers = [
  VoucherCustomer(id: 1, name: 'A', email: 'a@x.vn', tier: LoyaltyTier.diamond),
  VoucherCustomer(id: 2, name: 'B', email: 'b@x.vn', tier: LoyaltyTier.silver),
  VoucherCustomer(
    id: 3,
    name: 'C',
    email: 'c@x.vn',
    tier: LoyaltyTier.standard,
  ),
];

/// Lần `setup()` đầu lỗi; [support] cho từng sàn.
class _FakeVouchers implements VoucherRepository {
  _FakeVouchers({
    this.failFirst = false,
    this.support = const {},
    this.customers = _customers,
  });

  final bool failFirst;
  final List<VoucherCustomer> customers;
  final Map<Platform, VoucherSupport> support;
  var setupCalls = 0;

  @override
  Future<VoucherSetup> setup() async {
    setupCalls++;
    if (failFirst && setupCalls == 1) throw Exception('mất mạng');
    return VoucherSetup(customers: customers, support: support);
  }

  @override
  Future<List<VoucherBatch>> recentBatches() async => const [];

  @override
  Future<VoucherBatch> issue(VoucherDraft draft) => throw UnimplementedError();
}

Future<void> _openVouchers(
  WidgetTester tester, {
  VoucherRepository? repo,
}) async {
  await loginAs(
    tester,
    'admin@demo.vn',
    tallView: true,
    overrides: [
      clockProvider.overrideWithValue(() => _now),
      if (repo != null) voucherRepositoryProvider.overrideWithValue(repo),
    ],
  );
  await tester.tap(find.byKey(const Key('nav_more')));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byKey(const Key('menu_voucher')));
}

SoFilterChip _chip(WidgetTester tester, String key) =>
    tester.widget<SoFilterChip>(find.byKey(Key(key)));

SoButton _submit(WidgetTester tester) =>
    tester.widget<SoButton>(find.byKey(const Key('voucher_submit')));

Future<void> _fill(WidgetTester tester, String discount, String min) async {
  await tester.enterText(find.byKey(const Key('voucher_discount')), discount);
  await tester.enterText(find.byKey(const Key('voucher_min_order')), min);
  await tester.pump();
}

void main() {
  setUp(() => MockDelay.enabled = false);

  group('quy tắc T-30', () {
    test('countFromTier: từ hạng trở lên, cộng dồn', () {
      expect(countFromTier(_customers, LoyaltyTier.standard), 3);
      expect(countFromTier(_customers, LoyaltyTier.silver), 2);
      expect(countFromTier(_customers, LoyaltyTier.platinum), 1);
      expect(countFromTier(_customers, LoyaltyTier.diamond), 1);
      expect(audienceCount(_customers, const PickedAudience({2, 3, 99})), 2);
    });

    test('audienceLabel', () {
      expect(audienceLabel(const TierAudience(LoyaltyTier.standard)), 'Tất cả');
      expect(audienceLabel(const TierAudience(LoyaltyTier.silver)), 'Silver+');
      expect(audienceLabel(const TierAudience(LoyaltyTier.diamond)), 'Diamond');
      expect(audienceLabel(const PickedAudience({1, 2})), '2 khách đã chọn');
    });

    test('giá trị giảm > 0, đơn tối thiểu phải lớn hơn giá trị giảm', () {
      expect(validateDiscount(null), isNotNull);
      expect(validateDiscount(0), 'Giá trị giảm phải lớn hơn 0');
      expect(validateDiscount(30000), isNull);
      expect(validateMinOrder(null, 30000), isNotNull);
      expect(
        validateMinOrder(30000, 30000),
        'Đơn tối thiểu phải lớn hơn giá trị giảm',
      );
      expect(validateMinOrder(200000, 30000), isNull);
      // Chưa nhập giá trị giảm: chỉ báo lỗi ở ô giá trị giảm.
      expect(validateMinOrder(0, null), isNull);
    });

    test('voucherExpiry: hết ngày thứ N, qua tháng', () {
      expect(
        voucherExpiry(DateTime(2026, 10, 28, 23), 7),
        DateTime(2026, 11, 4),
      );
    });

    test('mock: 128 khách, TikTok Shop khóa, đợt mới tự thành công', () async {
      var now = _now;
      final repo = VoucherMockRepository(clock: () => now);
      final setup = await repo.setup();
      expect(countFromTier(setup.customers, LoyaltyTier.standard), 128);
      expect(countFromTier(setup.customers, LoyaltyTier.silver), 42);
      expect(setup.supportOf(Platform.tiktokShop), VoucherSupport.unsupported);

      final batch = await repo.issue(
        VoucherDraft(
          platform: Platform.shopee,
          discount: 30000,
          minOrder: 200000,
          expiresAt: voucherExpiry(now, 7),
          audience: 'Silver+',
          customerIds: const [1, 2],
        ),
      );
      expect(batch.status, VoucherBatchStatus.creating);
      expect(
        (await repo.recentBatches()).first.status,
        VoucherBatchStatus.creating,
      );

      now = now.add(VoucherMockRepository.confirmAfter);
      final batches = await repo.recentBatches();
      expect(batches.first.status, VoucherBatchStatus.success);
      // Đợt mẫu "Đang tạo" (không phát trong phiên) giữ nguyên.
      expect(
        batches.where((b) => b.status == VoucherBatchStatus.creating),
        hasLength(1),
      );
    });
  });

  testWidgets('M-50 Staff: không có mục Phát voucher', (tester) async {
    await loginAs(tester, 'staff@demo.vn', tallView: true);
    await tester.tap(find.byKey(const Key('nav_more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu_voucher')), findsNothing);
  });

  testWidgets('T-30: chip hạng có số khách, TikTok Shop bị khóa có lý do', (
    tester,
  ) async {
    await _openVouchers(tester);

    expect(find.byType(VoucherScreen), findsOneWidget);
    expect(find.byType(SoMockBanner), findsOneWidget);
    expect(_chip(tester, 'voucher_tier_standard').count, 128);
    expect(_chip(tester, 'voucher_tier_silver').count, 42);
    expect(_chip(tester, 'voucher_tier_platinum').count, 15);
    expect(_chip(tester, 'voucher_tier_diamond').count, 4);
    expect(_chip(tester, 'voucher_tier_silver').selected, isTrue);

    final seg = tester.widget<SoSegmented<Platform>>(
      find.byKey(const Key('voucher_platform')),
    );
    expect(seg.selected, Platform.shopee);
    expect(seg.segments.last.enabled, isFalse);
    expect(
      find.text('TikTok Shop chưa cho tạo voucher qua API.'),
      findsOneWidget,
    );
    await tester.tap(find.text('TikTok Shop'));
    await tester.pump();
    expect(
      tester
          .widget<SoSegmented<Platform>>(
            find.byKey(const Key('voucher_platform')),
          )
          .selected,
      Platform.shopee,
    );

    expect(find.text('Hết hạn 29/10/2026'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('voucher_days_30')));
    expect(find.text('Hết hạn 21/11/2026'), findsOneWidget);

    expect(find.text('Chưa rõ · đối soát'), findsOneWidget);
    expect(find.text('Lỗi'), findsOneWidget);
    expect(find.text('Thành công'), findsOneWidget);
    expect(find.text('Đang tạo'), findsOneWidget);
  });

  testWidgets('T-30: kiểm tra ô, xác nhận rồi phát -> đợt Đang tạo', (
    tester,
  ) async {
    await _openVouchers(tester);
    expect(_submit(tester).label, 'Phát cho 42 khách trên Shopee');

    await tester.tap(find.byKey(const Key('voucher_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Giá trị giảm không được để trống'), findsOneWidget);
    expect(find.byType(SoBottomSheet), findsNothing);

    await _fill(tester, '300000', '200000');
    await tester.tap(find.byKey(const Key('voucher_submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Đơn tối thiểu phải lớn hơn giá trị giảm'),
      findsOneWidget,
    );

    await _fill(tester, '30000', '200000');
    await tester.tap(find.byKey(const Key('voucher_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Phát voucher cho 42 khách?'), findsOneWidget);
    expect(find.text('Silver+ · 42 khách'), findsOneWidget);
    expect(find.text('29/10/2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('voucher_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Đã gửi yêu cầu tạo voucher lên Shopee'), findsOneWidget);
    expect(find.byKey(const Key('voucher_batch_5')), findsOneWidget);
    expect(find.text('Đang tạo'), findsNWidgets(2));
    // Ô tiền đã xóa để không phát lặp.
    expect(find.text('30.000'), findsNothing);
  });

  testWidgets('T-30: hủy xác nhận thì không phát', (tester) async {
    await _openVouchers(tester);
    await _fill(tester, '30000', '200000');
    await tester.tap(find.byKey(const Key('voucher_submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('voucher_confirm_cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voucher_batch_5')), findsNothing);
  });

  testWidgets('T-30: chọn từng khách có tìm kiếm', (tester) async {
    await _openVouchers(tester);
    await tapVisible(tester, find.byKey(const Key('voucher_pick')));
    expect(find.text('Chọn khách'), findsWidgets);
    expect(
      tester.widget<SoButton>(find.byKey(const Key('pick_done'))).onPressed,
      isNull,
    );

    await tester.enterText(find.byKey(const Key('pick_search')), 'khach12@');
    await tester.pump();
    expect(find.byKey(const Key('pick_12')), findsOneWidget);
    expect(find.byKey(const Key('pick_13')), findsNothing);
    await tester.tap(find.byKey(const Key('pick_12')));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('pick_search')), 'khach5@');
    await tester.pump();
    await tester.tap(find.byKey(const Key('pick_5')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pick_done')));
    await tester.pumpAndSettle();

    expect(_chip(tester, 'voucher_pick').label, '2 khách đã chọn');
    expect(_chip(tester, 'voucher_pick').selected, isTrue);
    expect(_chip(tester, 'voucher_tier_silver').selected, isFalse);
    expect(_submit(tester).label, 'Phát cho 2 khách trên Shopee');
  });

  testWidgets('T-30: hạng 0 khách thì khóa nút phát', (tester) async {
    await _openVouchers(
      tester,
      repo: _FakeVouchers(
        support: const {Platform.shopee: VoucherSupport.available},
        customers: [_customers.last],
      ),
    );
    await tapVisible(tester, find.byKey(const Key('voucher_tier_platinum')));
    expect(find.byKey(const Key('voucher_no_customers')), findsOneWidget);
    expect(_submit(tester).onPressed, isNull);
  });

  testWidgets('T-30: không sàn nào phát được -> banner, nút khóa', (
    tester,
  ) async {
    await _openVouchers(
      tester,
      repo: _FakeVouchers(
        support: const {Platform.tiktokShop: VoucherSupport.unsupported},
      ),
    );
    expect(find.byKey(const Key('voucher_no_platform')), findsOneWidget);
    expect(
      find.text('Chưa kết nối Shopee. Kết nối ở mục Kết nối sàn.'),
      findsOneWidget,
    );
    expect(_submit(tester).onPressed, isNull);
    expect(find.byKey(const Key('voucher_batches_empty')), findsOneWidget);
  });

  testWidgets('T-30: lỗi tải khách -> Thử lại', (tester) async {
    final repo = _FakeVouchers(
      failFirst: true,
      support: const {Platform.shopee: VoucherSupport.available},
    );
    await _openVouchers(tester, repo: repo);
    expect(find.byKey(const Key('voucher_setup_error')), findsOneWidget);
    expect(_submit(tester).onPressed, isNull);

    await tapVisible(tester, find.text('Thử lại'));
    expect(repo.setupCalls, 2);
    expect(find.byKey(const Key('voucher_tier_standard')), findsOneWidget);
  });

  testWidgets('T-30 vừa bề rộng 360dp', (tester) async {
    await _openVouchers(tester);
    tester.view.physicalSize = const Size(360, 740);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
