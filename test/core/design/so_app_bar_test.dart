import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';

Widget _app(SoAppBar bar) => MaterialApp(
  theme: SoTheme.light(),
  home: SoScaffold(
    appBar: bar,
    slivers: [
      SliverList.list(
        children: [
          for (var i = 0; i < 40; i++)
            SizedBox(height: 60, child: Text('Hàng $i')),
        ],
      ),
    ],
  ),
);

void main() {
  testWidgets('SoAppBar.root: tiêu đề lớn thu lại, hiện kính khi cuộn', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const SoAppBar.root(title: 'Đơn hàng', subtitle: 'Shop Demo')),
    );

    // Đầu trang: chỉ có tiêu đề lớn, thanh trong suốt.
    expect(find.text('Đơn hàng'), findsOneWidget);
    expect(find.text('Shop Demo'), findsOneWidget);
    AnimatedOpacity glass() => tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byType(SoGlass),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(glass().opacity, 0);
    // Hàng đầu nằm ngay dưới khối tiêu đề lớn (không bị che lúc chưa cuộn).
    final titleBottom = tester.getBottomLeft(find.text('Shop Demo')).dy;
    expect(tester.getTopLeft(find.text('Hàng 0')).dy, greaterThan(titleBottom));

    await tester.drag(find.byType(Scrollable), const Offset(0, -300));
    await tester.pumpAndSettle();

    // Đã thu: tiêu đề nhỏ hiện ở thanh 52, nền kính bật.
    expect(glass().opacity, 1);
    final small = find.text('Đơn hàng').last;
    expect(tester.getCenter(small).dy, lessThan(SoSize.appBar));
  });

  testWidgets('SoAppBar con: nội dung bắt đầu dưới thanh, kính khi cuộn', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const SoAppBar(title: 'Chi tiết')));

    expect(tester.getTopLeft(find.text('Hàng 0')).dy, SoSize.appBar);

    await tester.drag(find.byType(Scrollable), const Offset(0, -200));
    await tester.pumpAndSettle();
    final glass = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byType(SoGlass),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(glass.opacity, 1);
  });

  for (final close in [false, true]) {
    testWidgets('SoAppBar con (close: $close): viên tròn cách mép trái 12–16', (
      tester,
    ) async {
      await tester.pumpWidget(_app(SoAppBar(title: 'Chi tiết', close: close)));

      // Viên tròn 36 đồng tâm với icon.
      final iconCenter = tester.getCenter(
        find.descendant(
          of: find.byKey(const Key('so_app_bar_leading')),
          matching: find.byType(Icon),
        ),
      );
      final left = iconCenter.dx - SoSize.controlSmall / 2;
      expect(left, inInclusiveRange(12, 16));
      // Vùng chạm vẫn đủ 48.
      expect(
        tester.getSize(find.byKey(const Key('so_app_bar_leading'))).width,
        greaterThanOrEqualTo(SoSize.touch),
      );
    });
  }
}
