import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/features/loyalty/presentation/claim_order_screen.dart';
import 'package:smartomni_mobile/features/loyalty/presentation/claim_result_screen.dart';

import '../helpers/test_app.dart';

Future<void> _openClaim(WidgetTester tester, {bool tall = true}) async {
  await loginAs(tester, 'customer@demo.vn', tallView: tall);
  await tester.tap(find.text('Claim đơn'));
  await tester.pumpAndSettle();
  expect(find.byType(ClaimOrderScreen), findsOneWidget);
}

Finder get _codeField => find.descendant(
  of: find.byKey(const Key('claim_code')),
  matching: find.byType(EditableText),
);

String _code(WidgetTester tester) =>
    tester.widget<EditableText>(_codeField).controller.text;

Future<void> _claim(WidgetTester tester, String code) async {
  await tester.enterText(_codeField, code);
  await tapVisible(tester, find.byKey(const Key('claim_submit')));
}

/// Claim [code] và mong màn kết quả báo lỗi [kind]; trả về sau "Sửa mã đơn".
Future<void> _expectError(
  WidgetTester tester,
  String code,
  String kind,
  String title,
) async {
  await _claim(tester, code);
  expect(find.byType(ClaimResultScreen), findsOneWidget);
  final banner = find.byKey(Key('claim_error_$kind'));
  expect(banner, findsOneWidget);
  expect(tester.widget<SoBanner>(banner).title, title);
  await tester.tap(find.byKey(const Key('claim_edit')));
  await tester.pumpAndSettle();
  expect(find.byType(ClaimResultScreen), findsNothing);
}

void main() {
  testWidgets('C-30: viên cửa hàng, form, nút quét, bắt buộc mã, 3 điều kiện', (
    tester,
  ) async {
    await _openClaim(tester);

    expect(
      tester
          .widget<SoShopSwitcher>(find.byKey(const Key('shop_switcher')))
          .name,
      'Shop Demo',
    );
    expect(
      find.text('Nhập mã đơn đã mua trên sàn để cộng điểm cho Shop Demo.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('claim_platform')), findsOneWidget);
    expect(find.text('Xem ở mục Đơn mua của app sàn.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('claim_scan')));
    await tester.pump();
    expect(find.text('Quét mã sắp có, hãy nhập mã đơn.'), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('claim_submit')));
    expect(find.text('Mã đơn không được để trống'), findsOneWidget);
    expect(find.byType(ClaimResultScreen), findsNothing);

    expect(find.text('Điều kiện'), findsOneWidget);
    expect(
      find.text('Đơn chưa được claim ở cửa hàng này.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('Thành công: thẻ kết quả, lên hạng; Claim đơn khác xóa mã; C-20 '
      'cập nhật điểm', (tester) async {
    await _openClaim(tester);
    await _claim(tester, '240920shop01');

    expect(find.byKey(const Key('claim_success')), findsOneWidget);
    expect(find.text('+520 điểm'), findsOneWidget);
    expect(find.text('240920SHOP01'), findsOneWidget);
    expect(find.text('520.000 ₫'), findsOneWidget);
    expect(find.text('620 → 1.140'), findsOneWidget);
    expect(find.byKey(const Key('claim_tier_up')), findsOneWidget);
    expect(find.text('Bạn đã lên hạng'), findsOneWidget);

    await tester.tap(find.byKey(const Key('claim_another')));
    await tester.pumpAndSettle();
    expect(find.byType(ClaimResultScreen), findsNothing);
    expect(_code(tester), isEmpty);

    await tester.tap(find.text('Điểm & hạng'));
    await tester.pumpAndSettle();
    expect(find.text('1.140'), findsOneWidget);
  });

  testWidgets('Đủ 5 lỗi dạng banner; Sửa mã đơn giữ nguyên mã; khóa nút', (
    tester,
  ) async {
    await _openClaim(tester);

    await _expectError(tester, '241008SHOP02', 'tooEarly', 'Chưa đủ 15 ngày');
    expect(_code(tester), '241008SHOP02');
    await _expectError(
      tester,
      '241012SHOP03',
      'notCompleted',
      'Đơn chưa hoàn tất',
    );
    await _expectError(tester, 'KHONGCO1', 'notFound', 'Không tìm thấy đơn');

    // Claim hợp lệ (đặt lại bộ đếm lần sai), rồi claim lại -> đã claim.
    await _claim(tester, '240920SHOP01');
    await tester.tap(find.byKey(const Key('claim_another')));
    await tester.pumpAndSettle();
    await _expectError(
      tester,
      '240920SHOP01',
      'alreadyClaimed',
      'Đơn đã được claim',
    );

    // Đã sai 1 lần sau khi claim hợp lệ; sai thêm 4 lần nữa là bị khóa.
    for (var i = 0; i < 4; i++) {
      await _expectError(tester, 'SAI$i', 'notFound', 'Không tìm thấy đơn');
    }
    await _expectError(
      tester,
      'KHONGCO2',
      'tooManyAttempts',
      'Thử sai quá nhiều lần',
    );
    expect(
      tester.widget<SoButton>(find.byKey(const Key('claim_submit'))).onPressed,
      isNull,
    );
    expect(find.byKey(const Key('claim_locked')), findsOneWidget);
  });

  testWidgets('C-30 và kết quả vừa bề rộng 360dp, chữ phóng 1.3', (
    tester,
  ) async {
    useNarrowPhone(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _openClaim(tester, tall: false);
    expect(tester.takeException(), isNull);

    await _claim(tester, '240920SHOP01');
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -1500),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
