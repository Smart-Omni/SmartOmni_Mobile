import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/features/customer_shop/presentation/customer_shops_screen.dart';

import '../helpers/test_app.dart';

Future<void> _openShops(WidgetTester tester) async {
  await loginAs(tester, 'customer@demo.vn', tallView: true);
  await tester.tap(find.byKey(const Key('shop_switcher')));
  await tester.pumpAndSettle();
  expect(find.byType(CustomerShopsScreen), findsOneWidget);
}

String _switcherName(WidgetTester tester) =>
    tester.widget<SoShopSwitcher>(find.byKey(const Key('shop_switcher'))).name;

Future<void> _typeCode(WidgetTester tester, String code) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('add_shop_code')),
      matching: find.byType(EditableText),
    ),
    code,
  );
  // Tự tra sau khi ngừng gõ 0,5 giây.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('C-00: 2 cửa hàng, cửa hàng đang xem có nhãn; chọn thì đổi', (
    tester,
  ) async {
    await _openShops(tester);

    expect(find.text('Cửa hàng của bạn'), findsOneWidget);
    expect(find.byType(SoMockBanner), findsOneWidget);
    expect(find.byKey(const Key('shop_1')), findsOneWidget);
    expect(find.byKey(const Key('shop_2')), findsOneWidget);
    expect(find.text('620 điểm'), findsOneWidget);
    expect(find.text('Silver'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('shop_1')),
        matching: find.byKey(const Key('shop_current')),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('shop_2')));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerShopsScreen), findsNothing);
    expect(_switcherName(tester), 'Hoa Mộc Cosmetics');
    expect(find.text('Son kem lì Hoa Mộc'), findsOneWidget);
  });

  testWidgets('Thêm cửa hàng: mã sai / đã tham gia báo lỗi; mã đúng thì '
      'tham gia và về C-10', (tester) async {
    await _openShops(tester);
    await tester.tap(find.byKey(const Key('shops_add')));
    await tester.pumpAndSettle();
    expect(find.text('Thêm cửa hàng'), findsWidgets);

    SoButton join() =>
        tester.widget<SoButton>(find.byKey(const Key('add_shop_join')));
    expect(join().onPressed, isNull);

    await _typeCode(tester, 'khongco');
    expect(find.text('Không tìm thấy cửa hàng với mã này.'), findsOneWidget);
    expect(join().onPressed, isNull);

    await _typeCode(tester, 'shop demo');
    expect(find.text('Bạn đã tham gia cửa hàng này.'), findsOneWidget);

    // Quét QR chưa có: báo ngay dưới ô.
    await tester.tap(find.byKey(const Key('add_shop_qr')));
    await tester.pump();
    expect(
      find.text('Quét mã QR sắp có, hãy nhập mã cửa hàng.'),
      findsOneWidget,
    );

    await _typeCode(tester, 'bepxinh');
    expect(find.byKey(const Key('add_shop_preview')), findsOneWidget);
    expect(find.text('Bếp Xinh'), findsOneWidget);
    expect(join().onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('add_shop_join')));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerShopsScreen), findsNothing);
    expect(_switcherName(tester), 'Bếp Xinh');
    expect(find.text('Đã tham gia Bếp Xinh'), findsOneWidget);
  });

  testWidgets('C-00 và sheet vừa bề rộng 360dp', (tester) async {
    useNarrowPhone(tester);
    await loginAs(tester, 'customer@demo.vn');
    await tester.tap(find.byKey(const Key('shop_switcher')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('shops_add')));
    await tester.pumpAndSettle();
    await _typeCode(tester, 'bepxinh');
    expect(tester.takeException(), isNull);
  });
}
