import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';

Widget _wrap(Widget child, {bool enabled = true, bool highContrast = false}) =>
    MaterialApp(
      theme: SoTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(highContrast: highContrast),
        child: SoGlassScope(
          enabled: enabled,
          child: SoAmbientBackground(child: Center(child: child)),
        ),
      ),
    );

const _glass = SoGlass(child: SizedBox(width: 100, height: 40));

void main() {
  testWidgets('SoGlass bật: có làm mờ nền', (tester) async {
    await tester.pumpWidget(_wrap(_glass));
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('SoGlass tắt bằng công tắc: nền surface đặc, không blur', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_glass, enabled: false));
    expect(find.byType(BackdropFilter), findsNothing);
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(ClipRSuperellipse),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((box.decoration as ShapeDecoration).color, SoColors.light.surface);
  });

  testWidgets('SoGlass tắt khi bật tương phản cao', (tester) async {
    await tester.pumpWidget(_wrap(_glass, highContrast: true));
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
