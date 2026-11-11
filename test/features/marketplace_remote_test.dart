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
Map<String, Object?> _dto(int id, String status, {String? shopName}) => {
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
  'connectedAt': '2026-11-01T08:00:00Z',
  'lastErrorCode': null,
};

/// BE giả: [shopee], [tiktok] là `data` của GET trạng thái (null = chưa
/// từng kết nối). Ngắt kết nối đổi trạng thái thành DISCONNECTED.
FakeBackend _integration({Map<String, Object?>? shopee, Object? tiktok}) {
  final state = <Platform, Map<String, Object?>?>{
    Platform.shopee: shopee,
    Platform.tiktokShop: tiktok as Map<String, Object?>?,
  };
  return FakeBackend((RequestOptions o) async {
    for (final p in Platform.values) {
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

    test('công tắc tự nhập chỉ giữ trong app, không gửi request', () async {
      final backend = _integration(shopee: _dto(1, 'CONNECTED'));
      final repo = MarketplaceRemoteRepository(fakeDio(backend));
      await repo.setAutoImport(Platform.shopee, enabled: true);
      expect(backend.requests, isEmpty);
      final list = await repo.listConnections();
      expect(list.single.autoImportProducts, isTrue);
    });
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
