import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/app/bootstrap.dart';
import 'package:smartomni_mobile/app/config/app_config.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/network/api_paths.dart';
import 'package:smartomni_mobile/core/utils/clock.dart';
import 'package:smartomni_mobile/core/utils/mock_delay.dart';
import 'package:smartomni_mobile/features/account/data/account_repositories.dart';
import 'package:smartomni_mobile/features/account/domain/account_repository.dart';
import 'package:smartomni_mobile/features/account/presentation/account_providers.dart';
import 'package:smartomni_mobile/features/ai_insights/data/ai_repositories.dart';
import 'package:smartomni_mobile/features/ai_insights/domain/demand_forecast.dart';
import 'package:smartomni_mobile/features/ai_insights/presentation/ai_screens.dart';
import 'package:smartomni_mobile/features/inventory/domain/inventory_item.dart';
import 'package:smartomni_mobile/features/inventory/presentation/inventory_providers.dart';
import 'package:smartomni_mobile/l10n/l10n.dart';

import '../helpers/fake_backend.dart';
import '../helpers/test_app.dart';

final _today = DateTime(2026, 11, 11, 15, 30);

/// Entity `DemandForecast` như BE trả (camelCase, ngày "yyyy-MM-dd").
Map<String, Object?> _row(String date, int qty, {int? reorder}) => {
  'id': 1,
  'tenantId': 3,
  'skuId': 11,
  'modelVersionId': 2,
  'forecastDate': date,
  'predictedQuantity': qty,
  'recommendedReorderQty': reorder,
};

DemandForecast _day(int y, int m, int d) =>
    DemandForecast(forecastDate: DateTime(y, m, d), predictedQuantity: 1);

void main() {
  setUp(() => MockDelay.enabled = false);

  group('upcomingForecast', () {
    test('bỏ ngày đã qua, giữ hôm nay, sắp xếp, tối đa 7 ngày', () {
      final days = [
        for (var d = 20; d >= 5; d--) _day(2026, 11, d), // lộn xộn, có ngày cũ
      ];
      final out = upcomingForecast(days, _today);
      expect(
        [for (final d in out) d.forecastDate.day],
        [11, 12, 13, 14, 15, 16, 17],
      );
    });

    test('ít hơn 7 ngày tới; toàn ngày cũ thì rỗng', () {
      expect(
        upcomingForecast([_day(2026, 11, 13), _day(2026, 11, 12)], _today),
        hasLength(2),
      );
      expect(upcomingForecast([_day(2026, 11, 10)], _today), isEmpty);
      expect(upcomingForecast(const [], _today), isEmpty);
    });
  });

  test('tryFromJson: đọc entity thật; thiếu hoặc sai ngày thì bỏ', () {
    final ok = DemandForecast.tryFromJson(_row('2026-11-12', 5, reorder: 30));
    expect(ok!.forecastDate, DateTime(2026, 11, 12));
    expect(ok.predictedQuantity, 5);
    expect(ok.recommendedReorderQty, 30);
    expect(DemandForecast.tryFromJson(_row('không phải ngày', 5)), isNull);
    expect(DemandForecast.tryFromJson({'predictedQuantity': 5}), isNull);
  });

  test('AiRemoteRepository gọi GET /api/v1/ai/forecast/{skuId}', () async {
    final backend = FakeBackend(
      (o) async => (
        200,
        ok([
          _row('2026-11-12', 5),
          {'forecastDate': null, 'predictedQuantity': 9},
        ]),
      ),
    );
    final days = await AiRemoteRepository(fakeDio(backend)).forecastForSku(11);
    expect(backend.requests.single.path, ApiPaths.forecast(11));
    expect(days, hasLength(1));
  });

  testWidgets('M-51 BE thật: không banner, chỉ hiện các ngày từ hôm nay', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(428, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend(
      (o) async => o.path == ApiPaths.forecast(11)
          ? (
              200,
              ok([
                _row('2026-11-13', 4),
                _row('2026-11-09', 99), // đã qua: không hiện
                _row('2026-11-12', 6, reorder: 20),
              ]),
            )
          : (200, ok(const [])),
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutoRetry,
        overrides: [
          appConfigProvider.overrideWithValue(testConfig),
          clockProvider.overrideWithValue(() => _today),
          inventoryUseRemoteProvider.overrideWithValue(true),
          forecastUseRemoteProvider.overrideWithValue(true),
          aiRepositoryProvider.overrideWithValue(
            AiRemoteRepository(fakeDio(backend)),
          ),
          inventoryListProvider.overrideWith(
            (ref) async => const [
              InventoryItem(
                skuId: 11,
                skuCode: 'AT-TRANG-M',
                productName: 'Áo thun',
                quantityOnHand: 8,
              ),
              InventoryItem(
                skuId: 21,
                skuCode: 'ML-01',
                productName: 'Mũ len',
                quantityOnHand: 0,
              ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: SoTheme.light(),
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const SkuForecastScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SoMockBanner), findsNothing);
    // Vào từ M-50: tự mở sheet chọn SKU (danh sách thật).
    await tester.tap(find.byKey(const Key('pick_sku_11')));
    await tester.pumpAndSettle();

    expect(find.text('T5, 12/11'), findsOneWidget);
    expect(find.text('T6, 13/11'), findsOneWidget);
    expect(find.text('CN, 09/11'), findsNothing);
    expect(find.text('Dự kiến bán 2 ngày'), findsOneWidget);

    // SKU không có dự báo: trạng thái trống.
    await tester.tap(find.byKey(const Key('forecast_change_sku')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick_sku_21')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forecast_empty')), findsOneWidget);
  });

  group('M-51 gói Pro (BE thật)', () {
    const proOnly = 'Dự báo AI chỉ có ở gói Pro';
    const beMessage = 'Tính năng AI chỉ khả dụng cho gói Pro.';

    /// BE giả: `users/me`, `tenants/me` ([tenant] null = lỗi 500) và dự báo
    /// trả [forecast].
    Future<FakeBackend> openM51(
      WidgetTester tester, {
      required Map<String, Object?>? tenant,
      required (int, Object?) forecast,
    }) async {
      tester.view.physicalSize = const Size(428, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final backend = FakeBackend((o) async {
        if (o.path == ApiPaths.usersMe) {
          return (200, ok({'id': 7, 'email': 'a@b.vn', 'tenant_id': 3}));
        }
        if (o.path == ApiPaths.tenantsMe) {
          return tenant == null
              ? (500, apiError('Không thể xử lý yêu cầu. Vui lòng thử lại.'))
              : (200, ok(tenant));
        }
        return forecast;
      });
      await tester.pumpWidget(
        ProviderScope(
          retry: noAutoRetry,
          overrides: [
            appConfigProvider.overrideWithValue(testConfig),
            clockProvider.overrideWithValue(() => _today),
            inventoryUseRemoteProvider.overrideWithValue(true),
            forecastUseRemoteProvider.overrideWithValue(true),
            accountRepositoryProvider.overrideWithValue(
              AccountRemoteRepository(fakeDio(backend)),
            ),
            aiRepositoryProvider.overrideWithValue(
              AiRemoteRepository(fakeDio(backend)),
            ),
            inventoryListProvider.overrideWith(
              (ref) async => const [
                InventoryItem(
                  skuId: 11,
                  skuCode: 'AT-TRANG-M',
                  productName: 'Áo thun',
                  quantityOnHand: 8,
                ),
              ],
            ),
          ],
          child: MaterialApp(
            theme: SoTheme.light(),
            locale: const Locale('vi'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const SkuForecastScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return backend;
    }

    testWidgets('tenants/me planType FREE → hiện ngay, không mở sheet, không '
        'gọi dự báo', (tester) async {
      final backend = await openM51(
        tester,
        tenant: {'id': 3, 'companyName': 'Shop', 'planType': 'FREE'},
        forecast: (200, ok(const [])),
      );
      expect(find.byKey(const Key('forecast_pro_only')), findsOneWidget);
      expect(find.text(proOnly), findsOneWidget);
      expect(find.byKey(const Key('pick_sku_11')), findsNothing);
      expect(find.text('Thử lại'), findsNothing);
      expect(backend.calls(ApiPaths.forecast(11)), 0);
    });

    testWidgets('planType PRO → mở sheet chọn SKU như thường', (tester) async {
      await openM51(
        tester,
        tenant: {'id': 3, 'planType': 'PRO'},
        forecast: (200, ok(const [])),
      );
      expect(find.byKey(const Key('pick_sku_11')), findsOneWidget);
      expect(find.byKey(const Key('forecast_pro_only')), findsNothing);
    });

    testWidgets('chưa biết gói (tenants/me lỗi) + 403 FEATURE_NOT_AVAILABLE → '
        'message BE, không Thử lại', (tester) async {
      final backend = await openM51(
        tester,
        tenant: null,
        forecast: (
          403,
          {...apiError(beMessage), 'code': 'FEATURE_NOT_AVAILABLE'},
        ),
      );
      await tester.tap(find.byKey(const Key('pick_sku_11')));
      await tester.pumpAndSettle();

      expect(find.text(proOnly), findsOneWidget);
      expect(find.text(beMessage), findsOneWidget);
      expect(find.text('Thử lại'), findsNothing);
      expect(backend.calls(ApiPaths.forecast(11)), 1);
    });

    testWidgets('thiếu planType + 403 không có mã → lỗi cũ có Thử lại', (
      tester,
    ) async {
      await openM51(
        tester,
        tenant: {'id': 3, 'companyName': 'Shop'},
        forecast: (403, apiError('Bạn không có quyền thực hiện thao tác này.')),
      );
      await tester.tap(find.byKey(const Key('pick_sku_11')));
      await tester.pumpAndSettle();

      expect(find.text('Không tải được dự báo'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text(proOnly), findsNothing);
    });
  });

  test('isKnownNonPro: chỉ true khi biết chắc gói khác PRO', () {
    for (final (plan, expected) in [
      ('FREE', true),
      ('Free', true),
      ('PRO', false),
      ('pro', false),
      (null, false),
      ('  ', false),
    ]) {
      expect(
        AccountProfile(email: '', planType: plan).isKnownNonPro,
        expected,
        reason: '$plan',
      );
    }
  });
}
