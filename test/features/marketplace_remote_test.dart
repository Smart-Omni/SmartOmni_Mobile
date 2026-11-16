import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/app/config/app_config.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/models/platform.dart';
import 'package:smartomni_mobile/core/network/api_paths.dart';
import 'package:smartomni_mobile/features/marketplace/data/marketplace_repositories.dart';
import 'package:smartomni_mobile/features/marketplace/domain/marketplace_connection.dart';
import 'package:smartomni_mobile/features/marketplace/presentation/marketplace_providers.dart';
import 'package:smartomni_mobile/features/marketplace/presentation/marketplace_screen.dart';
import 'package:smartomni_mobile/l10n/l10n.dart';

import '../helpers/fake_backend.dart';
import '../helpers/test_app.dart';

/// `ShopeeConnectionDto` / `TiktokConnectionDto` như BE trả.
Map<String, Object?> _dto(
  int id,
  String status, {
  String? shopName,
  bool autoImport = false,
}) => {
  'id': id,
  'status': status,
  'needsReconnect': const {
    'MISSING_SCOPE',
    'REFRESH_FAILED',
    'REVOKED',
  }.contains(status),
  'shopId': 'SHOP$id',
  'shopName': shopName,
  'shopRegion': 'VN',
  'autoImportProducts': autoImport,
  'connectedAt': '2026-11-01T08:00:00Z',
  'lastErrorCode': null,
};

/// BE giả: [shopee], [tiktok] là `data` của GET trạng thái (null = chưa
/// từng kết nối). Ngắt kết nối đổi trạng thái thành DISCONNECTED; bắt đầu
/// OAuth trả URL của simulator; callback thành công trả DTO CONNECTED; PATCH
/// settings đổi `autoImportProducts` của Shopee.
FakeBackend _integration({Map<String, Object?>? shopee, Object? tiktok}) {
  final state = <Platform, Map<String, Object?>?>{
    Platform.shopee: shopee,
    Platform.tiktokShop: tiktok as Map<String, Object?>?,
  };
  return FakeBackend((RequestOptions o) async {
    if (o.path == ApiPaths.shopeeSettings) {
      final on = (o.data as Map)['auto_import_products'] == true;
      state[Platform.shopee] = {
        ...?state[Platform.shopee],
        'autoImportProducts': on,
      };
      return (200, ok(state[Platform.shopee]));
    }
    for (final p in Platform.values) {
      if (o.path == ApiPaths.marketplaceAuthorization(p)) {
        return (
          200,
          ok({
            'authorizationUrl':
                'https://shopee-simulator.onrender.com/api/v2/shop/auth_partner'
                '?partner_id=1&state=st-1',
            'expiresAt': '2026-11-17T10:10:00Z',
          }),
        );
      }
      if (o.path == ApiPaths.marketplaceCallback(p)) {
        state[p] = _dto(p.index + 1, 'CONNECTED', shopName: 'Shop OAuth');
        return (200, ok(state[p]));
      }
      if (o.path == ApiPaths.marketplaceDisconnect(p)) {
        state[p] = {...?state[p], 'status': 'DISCONNECTED'};
        return (200, ok(state[p]));
      }
      if (o.path == ApiPaths.marketplaceConnection(p)) {
        return (200, ok(state[p]));
      }
    }
    return (404, apiError('Not found'));
  });
}

void main() {
  test('đường dẫn theo sàn', () {
    expect(
      ApiPaths.marketplaceConnection(Platform.shopee),
      '/api/v1/marketplace-connections/shopee',
    );
    expect(
      ApiPaths.marketplaceAuthorization(Platform.tiktokShop),
      '/api/v1/marketplace-connections/tiktok-shop/authorization',
    );
    expect(
      ApiPaths.marketplaceCallback(Platform.shopee),
      '/api/v1/marketplace-connections/shopee/callback',
    );
    expect(
      ApiPaths.shopeeSettings,
      '/api/v1/marketplace-connections/shopee/settings',
    );
    expect(
      ApiPaths.marketplaceDisconnect(Platform.tiktokShop),
      '/api/v1/marketplace-connections/tiktok-shop/disconnect',
    );
  });

  group('MarketplaceRemoteRepository', () {
    test('đọc 2 DTO: CONNECTED, REVOKED = lỗi kết nối, data null = chưa '
        'kết nối', () async {
      final repo = MarketplaceRemoteRepository(
        fakeDio(_integration(shopee: _dto(1, 'CONNECTED', shopName: 'Shop A'))),
      );
      var list = await repo.listConnections();
      expect(list, hasLength(1));
      expect(list.single.platform, Platform.shopee);
      expect(list.single.status, ConnectionStatus.connected);
      expect(list.single.shopName, 'Shop A');
      expect(connectionFor(list, Platform.tiktokShop), isNull);

      for (final s in ['REVOKED', 'MISSING_SCOPE', 'REFRESH_FAILED', 'ERROR']) {
        list = await MarketplaceRemoteRepository(
          fakeDio(_integration(tiktok: _dto(2, s))),
        ).listConnections();
        expect(list.single.status, ConnectionStatus.error, reason: s);
      }
    });

    test('ngắt kết nối gửi POST …/{sàn}/disconnect', () async {
      final backend = _integration(
        shopee: _dto(1, 'CONNECTED'),
        tiktok: _dto(2, 'CONNECTED'),
      );
      await MarketplaceRemoteRepository(
        fakeDio(backend),
      ).disconnect(Platform.tiktokShop);
      final req = backend.requests.single;
      expect(req.method, 'POST');
      expect(req.path, ApiPaths.marketplaceDisconnect(Platform.tiktokShop));
    });

    test('tự nhập Shopee: PATCH settings { auto_import_products }, đọc lại '
        'từ DTO', () async {
      final backend = _integration(shopee: _dto(1, 'CONNECTED'));
      final repo = MarketplaceRemoteRepository(fakeDio(backend));
      expect((await repo.listConnections()).single.autoImportProducts, isFalse);

      await repo.setAutoImport(Platform.shopee, enabled: true);
      final req = backend.requests.last;
      expect(req.method, 'PATCH');
      expect(req.path, ApiPaths.shopeeSettings);
      expect(req.data, {'auto_import_products': true});
      expect((await repo.listConnections()).single.autoImportProducts, isTrue);
    });

    test('tự nhập TikTok: BE chưa có API, chỉ giữ trong app', () async {
      final backend = _integration(tiktok: _dto(2, 'CONNECTED'));
      final repo = MarketplaceRemoteRepository(fakeDio(backend));
      await repo.setAutoImport(Platform.tiktokShop, enabled: true);
      expect(backend.requests, isEmpty);
      expect((await repo.listConnections()).single.autoImportProducts, isTrue);
    });

    test('bắt đầu OAuth: POST …/authorization { redirect_uri } → '
        'authorizationUrl, expiresAt', () async {
      final backend = _integration();
      final repo = MarketplaceRemoteRepository(fakeDio(backend));
      final start = await repo.startAuthorization(Platform.shopee);
      var req = backend.requests.single;
      expect(req.method, 'POST');
      expect(req.path, ApiPaths.marketplaceAuthorization(Platform.shopee));
      expect(req.data, {'redirect_uri': 'smartomni://oauth/shopee'});
      expect(start.authorizationUrl.host, 'shopee-simulator.onrender.com');
      expect(start.authorizationUrl.queryParameters['state'], 'st-1');
      expect(start.expiresAt?.toUtc(), DateTime.utc(2026, 11, 17, 10, 10));

      await repo.startAuthorization(Platform.tiktokShop);
      req = backend.requests.last;
      expect(req.data, {'redirect_uri': 'smartomni://oauth/tiktok'});
    });

    test(
      'callback: Shopee snake_case, TikTok camelCase → DTO kết nối',
      () async {
        final backend = _integration();
        final repo = MarketplaceRemoteRepository(fakeDio(backend));

        final shopee = await repo.completeAuthorization(
          OAuthCallback.tryParse(
            Uri.parse('smartomni://oauth/shopee?code=c1&state=s1&shop_id=99'),
          )!,
        );
        var req = backend.requests.last;
        expect(req.path, ApiPaths.marketplaceCallback(Platform.shopee));
        expect(req.data, {
          'code': 'c1',
          'shop_id': '99',
          'state': 's1',
          'error': null,
          'error_description': null,
        });
        expect(shopee.platform, Platform.shopee);
        expect(shopee.status, ConnectionStatus.connected);
        expect(shopee.shopName, 'Shop OAuth');

        await repo.completeAuthorization(
          OAuthCallback.tryParse(
            Uri.parse(
              'smartomni://oauth/tiktok?error=access_denied&state=s2'
              '&error_description=User%20denied',
            ),
          )!,
        );
        req = backend.requests.last;
        expect(req.path, ApiPaths.marketplaceCallback(Platform.tiktokShop));
        expect(req.data, {
          'code': null,
          'state': 's2',
          'error': 'access_denied',
          'errorDescription': 'User denied',
        });
      },
    );
  });

  testWidgets('T-10 BE thật: ẩn App Key, nút Kết nối tắt "Sắp có", ngắt kết '
      'nối gọi BE', (tester) async {
    tester.view
      ..physicalSize = const Size(428, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = _integration(
      shopee: _dto(1, 'CONNECTED', shopName: 'Shop Demo Official'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(testConfig),
          marketplaceUseRemoteProvider.overrideWithValue(true),
          marketplaceRepositoryProvider.overrideWithValue(
            MarketplaceRemoteRepository(fakeDio(backend)),
          ),
        ],
        child: MaterialApp(
          theme: SoTheme.light(),
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const MarketplaceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    String status(String p) =>
        tester.widget<SoStatusTag>(find.byKey(Key('platform_status_$p'))).label;

    expect(find.byKey(const Key('marketplace_app_key')), findsNothing);
    expect(
      find.text('Công tắc tự nhập là dữ liệu mẫu, backend chưa có API.'),
      findsOneWidget,
    );
    expect(status('shopee'), 'Đã kết nối');
    expect(find.text('Shop Demo Official'), findsOneWidget);
    expect(status('tiktokShop'), 'Chưa kết nối');
    final connect = tester.widget<SoButton>(
      find.byKey(const Key('connect_tiktokShop')),
    );
    expect(connect.onPressed, isNull);
    expect(find.byKey(const Key('connect_soon_tiktokShop')), findsOneWidget);
    expect(
      find.text('Kết nối qua ủy quyền của sàn sẽ có ở bản sau.'),
      findsOneWidget,
    );

    await tapVisible(tester, find.byKey(const Key('disconnect_shopee')));
    await tester.tap(find.byKey(const Key('disconnect_confirm')));
    await tester.pumpAndSettle();

    expect(backend.calls(ApiPaths.marketplaceDisconnect(Platform.shopee)), 1);
    expect(status('shopee'), 'Chưa kết nối');
    expect(
      tester
          .widget<SoButton>(find.byKey(const Key('connect_shopee')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('T-10 BE thật: lỗi kết nối có "Kết nối lại" tắt, vừa 360dp', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(testConfig),
          marketplaceUseRemoteProvider.overrideWithValue(true),
          marketplaceRepositoryProvider.overrideWithValue(
            MarketplaceRemoteRepository(
              fakeDio(_integration(shopee: _dto(1, 'REVOKED'))),
            ),
          ),
        ],
        child: MaterialApp(
          theme: SoTheme.light(),
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const MarketplaceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<SoButton>(find.byKey(const Key('reconnect_shopee')))
          .onPressed,
      isNull,
    );
    expect(find.text('Đơn và tồn kho đang ngừng đồng bộ.'), findsOneWidget);
  });
}
