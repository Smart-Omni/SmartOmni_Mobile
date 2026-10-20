import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';

import '../helpers/test_app.dart';

/// Điện thoại có tai thỏ và thanh cử chỉ: an toàn trên 47, dưới 34.
const _top = 47.0;
const _bottom = 34.0;
const _size = Size(390, 844);

void _usePhone(WidgetTester tester) {
  tester.view
    ..physicalSize = _size
    ..devicePixelRatio = 1
    ..padding = const FakeViewPadding(top: _top, bottom: _bottom)
    ..viewPadding = const FakeViewPadding(top: _top, bottom: _bottom);
  addTearDown(tester.view.reset);
}

Future<void> _openTab(WidgetTester tester, String email, String tab) async {
  _usePhone(tester);
  await loginAs(tester, email);
  await tester.tap(find.byKey(Key(tab)));
  await tester.pumpAndSettle();
}

/// Mép trên của thanh tab nổi: 64 + lề 12 + an toàn dưới.
const _tabBarTop = 844 - (SoSize.bottomNav + SoSpace.s12 + _bottom);

void main() {
  testWidgets('M-50: cuộn hết thì "Đăng xuất" nằm trên thanh tab, bấm được', (
    tester,
  ) async {
    await _openTab(tester, 'admin@demo.vn', 'nav_more');

    final position = tester
        .state<ScrollableState>(
          find.ancestor(
            of: find.byType(SoAppBar),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();

    final logout = find.text('Đăng xuất');
    expect(logout.hitTestable(), findsOneWidget);
    // Chừa thêm 16 dưới mục cuối.
    final groupBottom = tester
        .getRect(find.ancestor(of: logout, matching: find.byType(SoListGroup)))
        .bottom;
    expect(groupBottom, lessThanOrEqualTo(_tabBarTop - SoSpace.s16));
  });

  for (final (tab, title) in [
    ('nav_dashboard', 'Tổng quan cửa hàng'),
    ('nav_orders', 'Đơn hàng'),
    ('nav_products', 'Sản phẩm'),
    ('nav_inventory', 'Tồn kho'),
    ('nav_more', 'Thêm'),
  ]) {
    testWidgets('$title: tiêu đề lớn cuộn cùng nội dung rồi thu vào thanh', (
      tester,
    ) async {
      await _openTab(tester, 'admin@demo.vn', tab);

      // Chỉ chữ trong AppBar (nhãn thanh tab cũng có thể trùng chữ).
      Finder inBar() => find.descendant(
        of: find.byType(SoAppBar),
        matching: find.text(title),
      );
      final large = inBar();
      // Vùng cuộn của chính màn này. Đặt vị trí trực tiếp: kéo 20px bằng
      // tester.drag bị ngưỡng nhận kéo nuốt mất.
      final position = tester
          .state<ScrollableState>(
            find.ancestor(of: large, matching: find.byType(Scrollable)),
          )
          .position;
      expect(large, findsOneWidget);
      final titleRect = tester.getRect(large);
      // Tiêu đề lớn nằm dưới thanh 52 (không bị tai thỏ / thanh che).
      expect(titleRect.top, greaterThanOrEqualTo(_top + SoSize.appBar));

      // Cuộn 20: tiêu đề lớn đi lên đúng 20 cùng nội dung.
      position.jumpTo(20);
      await tester.pump();
      expect(tester.getRect(large).top, closeTo(titleRect.top - 20, 0.5));

      // Cuộn tiếp: tiêu đề lớn biến mất, tiêu đề nhỏ hiện giữa thanh 52.
      position.jumpTo(200);
      await tester.pumpAndSettle();
      final small = inBar().hitTestable();
      expect(small, findsOneWidget);
      final center = tester.getCenter(small);
      expect(center.dy, closeTo(_top + SoSize.appBar / 2, 2));
      expect(center.dx, closeTo(_size.width / 2, 2));
    });
  }

  testWidgets('Màn con: nội dung bắt đầu dưới thanh, không bị nút ← đè', (
    tester,
  ) async {
    await _openTab(tester, 'admin@demo.vn', 'nav_more');
    await tapVisible(tester, find.byKey(const Key('menu_ai')));
    // Đóng sheet chọn SKU tự mở để nhìn màn.
    await tester.tapAt(const Offset(195, 100));
    await tester.pumpAndSettle();

    final banner = tester.getRect(find.byType(SoMockBanner));
    expect(banner.top, greaterThanOrEqualTo(_top + SoSize.appBar));
  });
}
