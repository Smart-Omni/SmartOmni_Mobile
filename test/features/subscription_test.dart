import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/utils/clock.dart';
import 'package:smartomni_mobile/core/utils/mock_delay.dart';
import 'package:smartomni_mobile/features/subscription/domain/subscription.dart';
import 'package:smartomni_mobile/features/subscription/presentation/subscription_providers.dart';
import 'package:smartomni_mobile/features/subscription/presentation/subscription_screen.dart';

import '../helpers/test_app.dart';

final _now = DateTime(2026, 10, 22, 9);

/// Lần đầu lỗi (nếu [failFirst]), sau đó trả [overview].
class _FakeSubscription implements SubscriptionRepository {
  _FakeSubscription(this.data, {this.failFirst = false});

  final SubscriptionOverview data;
  final bool failFirst;
  var calls = 0;

  @override
  Future<SubscriptionOverview> overview() async {
    calls++;
    if (failFirst && calls == 1) throw Exception('mất mạng');
    return data;
  }
}

final _allPaid = SubscriptionOverview(
  subscription: Subscription(
    planName: 'Gói mẫu',
    expiresAt: DateTime(2026, 10, 25),
    skus: const UsageQuota(10, null),
    connections: const UsageQuota(1, 2),
    imageStorageGb: const UsageQuota(0.5, 5),
  ),
  invoices: const [],
);

Future<void> _openPlan(
  WidgetTester tester, {
  SubscriptionRepository? repo,
}) async {
  await loginAs(
    tester,
    'admin@demo.vn',
    tallView: true,
    overrides: [
      clockProvider.overrideWithValue(() => _now),
      if (repo != null) subscriptionRepositoryProvider.overrideWithValue(repo),
    ],
  );
  await tester.tap(find.byKey(const Key('nav_more')));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byKey(const Key('menu_subscription')));
}

String _planStatus(WidgetTester tester) =>
    tester.widget<SoStatusTag>(find.byKey(const Key('plan_status'))).label;

Color? _barColor(WidgetTester tester, String key) => tester
    .widget<SoProgressBar>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(SoProgressBar),
      ),
    )
    .color;

void main() {
  setUp(() => MockDelay.enabled = false);

  group('quy tắc T-40', () {
    test('usageLevel: < 80% bình thường, ≥ 80% sắp chạm, đầy là hết', () {
      expect(usageLevel(const UsageQuota(79, 100)), UsageLevel.normal);
      expect(usageLevel(const UsageQuota(80, 100)), UsageLevel.near);
      expect(usageLevel(const UsageQuota(4.3, 5)), UsageLevel.near);
      expect(usageLevel(const UsageQuota(2, 2)), UsageLevel.full);
      expect(usageLevel(const UsageQuota(3, 2)), UsageLevel.full);
      expect(usageLevel(const UsageQuota(999, null)), UsageLevel.normal);
    });

    test('planStatus: theo ngày, còn ≤ 7 ngày là sắp hết hạn', () {
      final now = DateTime(2026, 10, 22, 23, 59);
      expect(planStatus(DateTime(2026, 11, 22), now), PlanStatus.active);
      expect(planStatus(DateTime(2026, 10, 30), now), PlanStatus.active);
      expect(planStatus(DateTime(2026, 10, 29), now), PlanStatus.expiringSoon);
      // Ngày cuối vẫn còn dùng được.
      expect(planStatus(DateTime(2026, 10, 22), now), PlanStatus.expiringSoon);
      expect(planStatus(DateTime(2026, 10, 21), now), PlanStatus.expired);
    });

    test('unpaid: chỉ hóa đơn chưa thanh toán', () {
      final o = SubscriptionOverview(
        subscription: _allPaid.subscription,
        invoices: [
          Invoice(
            code: 'A',
            period: DateTime(2026, 10),
            amount: 1,
            paid: false,
            dueDate: DateTime(2026, 10, 15),
          ),
          Invoice(
            code: 'B',
            period: DateTime(2026, 9),
            amount: 1,
            paid: true,
            dueDate: DateTime(2026, 9, 15),
          ),
        ],
      );
      expect([for (final i in o.unpaid) i.code], ['A']);
    });
  });

  testWidgets('M-50 Staff: không có mục Gói dịch vụ', (tester) async {
    await loginAs(tester, 'staff@demo.vn', tallView: true);
    await tester.tap(find.byKey(const Key('nav_more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu_subscription')), findsNothing);
  });

  testWidgets('T-40 mock: gói, mức dùng ba màu, hóa đơn, banner nợ', (
    tester,
  ) async {
    await _openPlan(tester);
    final c = tester.element(find.byType(SubscriptionScreen)).soColors;

    expect(find.byType(SoMockBanner), findsOneWidget);
    expect(find.byKey(const Key('plan_card')), findsOneWidget);
    expect(find.byType(SoGlass), findsWidgets);
    expect(find.text('Gói mẫu'), findsOneWidget);
    expect(_planStatus(tester), 'Đang dùng');
    expect(find.text('Hết hạn 22/11/2026'), findsOneWidget);

    expect(find.byKey(const Key('plan_unpaid')), findsOneWidget);
    expect(find.text('1 hóa đơn chưa thanh toán'), findsOneWidget);

    expect(find.text('312 / 500 SKU'), findsOneWidget);
    expect(_barColor(tester, 'usage_skus'), c.brand);
    expect(find.text('2 / 2 kết nối'), findsOneWidget);
    expect(_barColor(tester, 'usage_connections'), c.danger);
    expect(find.text('Đã hết hạn mức'), findsOneWidget);
    expect(find.text('4,3 / 5 GB'), findsOneWidget);
    expect(_barColor(tester, 'usage_storage'), c.warning);
    expect(find.text('Sắp chạm hạn mức'), findsOneWidget);

    expect(find.byKey(const Key('invoice_INV-202610-0001')), findsOneWidget);
    expect(find.text('INV-202610-0001'), findsOneWidget);
    expect(find.text('Chưa thanh toán'), findsOneWidget);
    expect(find.text('Đã thanh toán'), findsNWidgets(3));
  });

  testWidgets('T-40: Đổi gói / Thanh toán chỉ báo sắp có', (tester) async {
    await _openPlan(tester);
    await tester.tap(find.byKey(const Key('plan_pay')));
    await tester.pumpAndSettle();
    expect(find.text('Thanh toán sắp có'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plan_change')));
    await tester.pumpAndSettle();
    expect(find.text('Đổi gói sắp có'), findsOneWidget);
  });

  testWidgets('T-40: sắp hết hạn, không giới hạn, không nợ, chưa có hóa đơn', (
    tester,
  ) async {
    await _openPlan(tester, repo: _FakeSubscription(_allPaid));
    expect(_planStatus(tester), 'Sắp hết hạn');
    expect(find.byKey(const Key('plan_unpaid')), findsNothing);
    expect(find.text('10 SKU · Không giới hạn'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('usage_skus')),
        matching: find.byType(SoProgressBar),
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('invoices_empty')), findsOneWidget);
  });

  testWidgets('T-40: lỗi tải -> Thử lại', (tester) async {
    final repo = _FakeSubscription(_allPaid, failFirst: true);
    await _openPlan(tester, repo: repo);
    expect(find.byKey(const Key('plan_error')), findsOneWidget);

    await tapVisible(tester, find.text('Thử lại'));
    expect(repo.calls, 2);
    expect(find.byKey(const Key('plan_card')), findsOneWidget);
  });

  testWidgets('T-40 vừa bề rộng 360dp', (tester) async {
    await _openPlan(tester);
    tester.view.physicalSize = const Size(360, 740);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
