import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/features/loyalty/domain/loyalty_rules.dart';
import 'package:smartomni_mobile/features/loyalty/presentation/loyalty_screen.dart';

import '../helpers/test_app.dart';

Future<void> _openLoyalty(WidgetTester tester, {bool tall = true}) async {
  await loginAs(tester, 'customer@demo.vn', tallView: tall);
  await tester.tap(find.text('Điểm & hạng'));
  await tester.pumpAndSettle();
  expect(find.byType(LoyaltyScreen), findsOneWidget);
}

String _richText(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).textSpan!.toPlainText();

void main() {
  testWidgets('C-20 Shop Demo: thẻ hạng, 2 voucher, lịch sử trong thẻ', (
    tester,
  ) async {
    await _openLoyalty(tester);

    expect(
      tester
          .widget<SoShopSwitcher>(find.byKey(const Key('shop_switcher')))
          .name,
      'Shop Demo',
    );
    expect(find.byType(SoMockBanner), findsOneWidget);

    // Thẻ hạng: khớp số điểm ở C-00.
    final tier = find.byKey(const Key('tier_card'));
    expect(tier, findsOneWidget);
    expect(tester.widget(tier), isA<SoGlass>());
    expect(find.text('620'), findsOneWidget);
    expect(
      tester.widget<SoTierBadge>(find.byType(SoTierBadge)).tier,
      LoyaltyTier.silver,
    );
    expect(
      _richText(tester, 'tier_next'),
      startsWith('Còn 380 điểm để lên Platinum.'),
    );
    expect(find.text('Platinum · 1.000'), findsOneWidget);

    // Voucher: mỗi voucher một thẻ; sắp hết hạn thì báo.
    expect(find.byKey(const Key('voucher_SILVER50K')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('voucher_TTSILVER10')),
        matching: find.text('Hết hạn sau 12 ngày'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('voucher_SILVER50K')),
        matching: find.textContaining('HSD '),
      ),
      findsOneWidget,
    );

    // Giả lập clipboard của nền tảng.
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tapVisible(tester, find.byKey(const Key('copy_SILVER50K')));
    expect(copied, 'SILVER50K');
    expect(find.text('Đã sao chép SILVER50K'), findsOneWidget);

    // Lịch sử: mới nhất trước; số điểm nằm trọn trong thẻ (không bị cắt).
    final row = find.byKey(const Key('history_240905SHOP11'));
    final points = find.descendant(of: row, matching: find.text('+520'));
    expect(points, findsOneWidget);
    expect(
      tester.getRect(points).right,
      lessThanOrEqualTo(tester.getRect(row).right - SoSpace.s16 + 0.5),
    );
    expect(
      tester.getRect(row).top,
      lessThan(
        tester.getRect(find.byKey(const Key('history_240815SHOP09'))).top,
      ),
    );
  });

  testWidgets('C-20 đổi sang Hoa Mộc: điểm, voucher, lịch sử theo cửa hàng', (
    tester,
  ) async {
    await _openLoyalty(tester);
    await tester.tap(find.byKey(const Key('shop_switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shop_2')));
    await tester.pumpAndSettle();

    expect(find.text('120'), findsOneWidget);
    expect(
      tester.widget<SoTierBadge>(find.byType(SoTierBadge)).tier,
      LoyaltyTier.standard,
    );
    expect(
      find.text('Chưa có voucher. Cửa hàng sẽ gửi khi có ưu đãi.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('history_240930HM0007')), findsOneWidget);
    expect(find.byKey(const Key('history_240905SHOP11')), findsNothing);
  });

  testWidgets('C-20 vừa bề rộng 360dp, chữ phóng 1.3', (tester) async {
    useNarrowPhone(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _openLoyalty(tester, tall: false);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
