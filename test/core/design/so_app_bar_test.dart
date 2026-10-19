import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';

void main() {
  testWidgets('SoAppBar.root: tiêu đề lớn thu lại, hiện kính khi cuộn', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SoTheme.light(),
        home: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: const SoAppBar.root(title: 'Đơn hàng', subtitle: 'Shop Demo'),
          body: Builder(
            builder: (context) => ListView(
              padding: SoSpace.scrollable(context),
              children: [
                for (var i = 0; i < 40; i++)
                  SizedBox(height: 60, child: Text('Hàng $i')),
              ],
            ),
          ),
        ),
      ),
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
    // Hàng đầu nằm dưới thanh (không bị che lúc chưa cuộn).
    final barBottom = tester.getBottomLeft(find.byType(SoAppBar)).dy;
    expect(tester.getTopLeft(find.text('Hàng 0')).dy, barBottom);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // Đã thu: tiêu đề nhỏ hiện ở thanh 52, nền kính bật.
    expect(glass().opacity, 1);
    final small = find.text('Đơn hàng').last;
    expect(tester.getCenter(small).dy, lessThan(SoSize.appBar));
  });
}
