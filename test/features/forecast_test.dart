import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/app/config/app_config.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/utils/formatters.dart';
import 'package:smartomni_mobile/features/ai_insights/domain/demand_forecast.dart';
import 'package:smartomni_mobile/features/ai_insights/presentation/ai_screens.dart';
import 'package:smartomni_mobile/features/inventory/domain/inventory_item.dart';
import 'package:smartomni_mobile/features/inventory/presentation/inventory_providers.dart';
import 'package:smartomni_mobile/l10n/l10n.dart';

import '../helpers/test_app.dart';

const _stock = [
  InventoryItem(
    skuId: 71,
    skuCode: 'AT-001-M',
    productName: 'Áo thun cổ tròn',
    variantName: 'Size M',
    quantityOnHand: 12,
    reservedQuantity: 2,
  ),
  InventoryItem(
    skuId: 72,
    skuCode: 'AT-001-L',
    productName: 'Áo thun cổ tròn',
    variantName: 'Size L',
    quantityOnHand: 3,
  ),
];

/// SKU 71: 7 ngày, mỗi ngày 4 cái, ngày đầu gợi ý nhập 30. SKU khác: rỗng.
List<DemandForecast> _forecast(int skuId) => [
  if (skuId == 71)
    for (var d = 1; d <= 7; d++)
      DemandForecast(
        forecastDate: DateTime(2026, 10, 20 + d),
        predictedQuantity: 4,
        recommendedReorderQty: d == 1 ? 30 : null,
      ),
];

Future<void> _pump(
  WidgetTester tester, {
  int? skuId,
  Size size = const Size(428, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(testConfig),
        inventoryListProvider.overrideWith((ref) async => _stock),
        skuForecastProvider.overrideWith((ref, id) async => _forecast(id)),
      ],
      child: MaterialApp(
        theme: SoTheme.light(),
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SkuForecastScreen(skuId: skuId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) {
  final widget = tester.widget(find.byKey(Key(key)));
  return switch (widget) {
    Text(:final data?) => data,
    _ =>
      tester
          .widgetList<RichText>(
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(RichText),
            ),
          )
          .map((r) => r.text.toPlainText())
          .join('\n'),
  };
}

void main() {
  test('summarizeForecast: cộng dự kiến bán, lấy số nhập thêm lớn nhất', () {
    final s = summarizeForecast(_forecast(71));
    expect(s.predicted, 28);
    expect(s.reorder, 30);
    expect(summarizeForecast(const []), (predicted: 0, reorder: 0));
  });

  test('weekdayDate: thứ + ngày/tháng', () {
    expect(Formatters.weekdayDate(DateTime(2026, 10, 21)), 'T4, 21/10');
    expect(Formatters.weekdayDate(DateTime(2026, 10, 25)), 'CN, 25/10');
  });

  testWidgets('M-51 từ M-31: thẻ SKU có tên + mã, thẻ số liệu, 7 ngày', (
    tester,
  ) async {
    await _pump(tester, skuId: 71);

    expect(find.text('Dự báo nhu cầu'), findsOneWidget);
    expect(find.byType(SoAiLabel), findsOneWidget);
    expect(find.byType(SoMockBanner), findsOneWidget);
    expect(find.text('Áo thun cổ tròn'), findsOneWidget);
    expect(find.text('Size M'), findsOneWidget);
    expect(find.text('AT-001-M'), findsOneWidget);

    expect(_text(tester, 'forecast_predicted'), contains('Dự kiến bán 7 ngày'));
    expect(_text(tester, 'forecast_predicted'), contains('28 cái'));
    expect(_text(tester, 'forecast_reorder'), contains('30 cái'));
    expect(_text(tester, 'forecast_available'), '10 cái');

    expect(find.text('Theo ngày'), findsOneWidget);
    expect(find.text('T4, 21/10'), findsOneWidget);
    expect(find.text('T3, 27/10'), findsOneWidget);
    expect(find.text('Dự báo chỉ để tham khảo.'), findsOneWidget);
  });

  testWidgets('M-51 từ M-50: tự mở sheet chọn SKU, chọn xong hiện dự báo', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Chưa chọn SKU'), findsOneWidget);
    expect(find.byType(SoBottomSheet), findsOneWidget);
    expect(find.byKey(const Key('forecast_summary')), findsNothing);

    await tester.tap(find.byKey(const Key('pick_sku_71')));
    await tester.pumpAndSettle();

    expect(find.byType(SoBottomSheet), findsNothing);
    expect(find.text('AT-001-M'), findsOneWidget);
    expect(find.byKey(const Key('forecast_summary')), findsOneWidget);
  });

  testWidgets(
    'M-51: Đổi SKU sang SKU chưa có dự báo thì hiện trạng thái rỗng',
    (tester) async {
      await _pump(tester, skuId: 71);

      await tester.tap(find.byKey(const Key('forecast_change_sku')));
      await tester.pumpAndSettle();
      expect(find.text('Chọn SKU'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pick_sku_72')));
      await tester.pumpAndSettle();

      expect(find.text('Size L'), findsOneWidget);
      expect(find.text('Sắp hết'), findsOneWidget);
      expect(find.byKey(const Key('forecast_empty')), findsOneWidget);
      expect(find.text('Chưa có dự báo cho SKU này'), findsOneWidget);
      expect(find.byKey(const Key('forecast_summary')), findsNothing);
    },
  );

  testWidgets('M-51 và sheet vừa bề rộng 360dp', (tester) async {
    await _pump(tester, skuId: 71, size: const Size(360, 1400));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('forecast_change_sku')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
