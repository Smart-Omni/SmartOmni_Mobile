import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/features/dev_gallery/presentation/design_gallery_screen.dart';
import 'package:smartomni_mobile/l10n/l10n.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: SoTheme.light(),
  locale: const Locale('vi'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: child,
);

void main() {
  test('theme dùng token SmartOmni', () {
    final theme = SoTheme.light();
    expect(theme.scaffoldBackgroundColor, SoColors.light.ground);
    expect(theme.colorScheme.primary, SoColors.light.brand);
    expect(theme.colorScheme.error, SoColors.light.danger);
    expect(theme.extension<SoColors>(), SoColors.light);
    expect(theme.extension<SoText>(), isNotNull);
  });

  testWidgets('SoButton vô hiệu khi onPressed null', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: Column(
            children: [
              SoButton(label: 'Bật', onPressed: () => taps++),
              const SoButton(label: 'Tắt', onPressed: null),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Bật'));
    await tester.tap(find.text('Tắt'));
    expect(taps, 1);
  });

  testWidgets('SoStockMeter: có thể bán = tồn − giữ chỗ', (tester) async {
    await tester.pumpWidget(
      _wrap(const Scaffold(body: SoStockMeter(onHand: 120, reserved: 32))),
    );
    expect(find.text('88'), findsOneWidget);
    expect(find.text('Có thể bán'), findsOneWidget);
  });

  testWidgets('gallery hiện đủ ở bề rộng 360dp, mở được sheet', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const DesignGalleryScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Design system'), findsOneWidget);

    // Cuộn hết màn: lỗi tràn (overflow) sẽ làm test fail.
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Tiến trình'.toUpperCase()),
      400,
      scrollable: list,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const Key('gallery_open_sheet')),
      -300,
      scrollable: list,
    );
    await tester.tap(find.byKey(const Key('gallery_open_sheet')));
    await tester.pumpAndSettle();
    expect(find.text('Lưu số tồn'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.text('Lưu số tồn'), findsNothing);
  });
}
