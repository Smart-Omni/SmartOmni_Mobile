import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/app/config/app_config.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/auth/user_role.dart';
import 'package:smartomni_mobile/core/models/platform.dart';
import 'package:smartomni_mobile/core/network/api_exception.dart';
import 'package:smartomni_mobile/core/network/api_paths.dart';
import 'package:smartomni_mobile/features/marketplace/data/marketplace_repositories.dart';
import 'package:smartomni_mobile/features/marketplace/domain/marketplace_connection.dart';
import 'package:smartomni_mobile/features/auth/presentation/auth_controller.dart';
import 'package:smartomni_mobile/features/marketplace/presentation/marketplace_oauth.dart';
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
///
/// Callback giống BE: chỉ nhận `state` của lần bắt đầu gần nhất (`st-<n>`),
/// mỗi state một lần; có `error` → `*_AUTHORIZATION_DENIED`.
/// [authorizationError]: mã lỗi trả cho `POST …/authorization`.
/// [issuedStates]: state đã cấp từ lần chạy app trước.
FakeBackend _integration({
  Map<String, Object?>? shopee,
  Object? tiktok,
  String? authorizationError,
  Set<String> issuedStates = const {},
}) {
  final state = <Platform, Map<String, Object?>?>{
    Platform.shopee: shopee,
    Platform.tiktokShop: tiktok as Map<String, Object?>?,
  };
  var seq = 0;
  final issued = {...issuedStates};
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
      final prefix = p == Platform.shopee ? 'SHOPEE' : 'TIKTOK';
      if (o.path == ApiPaths.marketplaceAuthorization(p)) {
        if (authorizationError != null) {
          return (
            400,
            {...apiError('Invalid redirect_uri'), 'code': authorizationError},
          );
        }
        final st = 'st-${++seq}';
        issued.add(st);
        return (
          200,
          ok({
            'authorizationUrl':
                'https://shopee-simulator.onrender.com/api/v2/shop/auth_partner'
                '?partner_id=1&state=$st',
            'expiresAt': '2026-11-17T10:10:00Z',
          }),
        );
      }
      if (o.path == ApiPaths.marketplaceCallback(p)) {
        final body = o.data as Map;
        if (!issued.remove(body['state'])) {
          return (
            400,
            {
              ...apiError('Authorization state is missing or invalid'),
              'code': '${prefix}_STATE_INVALID',
            },
          );
        }
        if (body['error'] != null) {
          return (
            400,
            {
              ...apiError('The seller did not authorize SmartOmni'),
              'code': '${prefix}_AUTHORIZATION_DENIED',
            },
          );
        }
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
        await repo.startAuthorization(Platform.shopee); // st-1

        final shopee = await repo.completeAuthorization(
          OAuthCallback.tryParse(
            Uri.parse('smartomni://oauth/shopee?code=c1&state=st-1&shop_id=99'),
          )!,
        );
        var req = backend.requests.last;
        expect(req.path, ApiPaths.marketplaceCallback(Platform.shopee));
        expect(req.data, {
          'code': 'c1',
          'shop_id': '99',
          'state': 'st-1',
          'error': null,
          'error_description': null,
        });
        expect(shopee.platform, Platform.shopee);
        expect(shopee.status, ConnectionStatus.connected);
        expect(shopee.shopName, 'Shop OAuth');

        await expectLater(
          repo.completeAuthorization(
            OAuthCallback.tryParse(
              Uri.parse(
                'smartomni://oauth/tiktok?error=access_denied&state=s2'
                '&error_description=User%20denied',
              ),
            )!,
          ),
          throwsA(isA<ApiException>()),
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

  group('OAuthCallback.tryParse', () {
    test('thành công, từ chối; link lạ trả null', () {
      final ok = OAuthCallback.tryParse(
        Uri.parse('smartomni://oauth/shopee?code=c&state=s&shop_id=7'),
      )!;
      expect(ok.platform, Platform.shopee);
      expect((ok.code, ok.state, ok.shopId, ok.denied), ('c', 's', '7', false));

      final denied = OAuthCallback.tryParse(
        Uri.parse('smartomni://oauth/tiktok?error=access_denied&state=s'),
      )!;
      expect(denied.platform, Platform.tiktokShop);
      expect(denied.denied, isTrue);

      for (final link in [
        'smartomni://oauth/lazada?code=c&state=s',
        'smartomni://other/shopee?code=c',
        'https://smartomni.vn/oauth/shopee?code=c',
        'myapp://oauth/shopee?code=c',
      ]) {
        expect(OAuthCallback.tryParse(Uri.parse(link)), isNull, reason: link);
      }
    });
  });

  group('T-10 BE thật, OAuth', () {
    late List<Uri> opened;
    late FakeDeepLinkSource links;
    late InMemoryOAuthPendingStore pending;
    var openResult = true;

    setUp(() {
      opened = [];
      openResult = true;
      links = FakeDeepLinkSource();
      pending = InMemoryOAuthPendingStore();
    });

    Future<void> pump(
      WidgetTester tester,
      FakeBackend backend, {
      UserRole role = UserRole.tenantAdmin,
      Size size = const Size(428, 1200),
    }) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(testConfig),
            currentRoleProvider.overrideWithValue(role),
            marketplaceUseRemoteProvider.overrideWithValue(true),
            marketplaceRepositoryProvider.overrideWithValue(
              MarketplaceRemoteRepository(fakeDio(backend)),
            ),
            deepLinkSourceProvider.overrideWithValue(links),
            oauthPendingStoreProvider.overrideWithValue(pending),
            urlOpenerProvider.overrideWithValue((url) async {
              opened.add(url);
              return openResult;
            }),
          ],
          child: MaterialApp(
            theme: SoTheme.light(),
            locale: const Locale('vi'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (_, child) => MarketplaceOAuthListener(child: child!),
            home: const MarketplaceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    String status(WidgetTester tester, String p) =>
        tester.widget<SoStatusTag>(find.byKey(Key('platform_status_$p'))).label;

    SoButton button(WidgetTester tester, String key) =>
        tester.widget<SoButton>(find.byKey(Key(key)));

    /// Vài khung hình: khi đang chờ deep link, nút có vòng xoay chạy mãi nên
    /// không dùng được `pumpAndSettle`.
    Future<void> frames(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Map<Object?, Object?> callbackBody(FakeBackend backend, Platform p) =>
        backend.requests
                .lastWhere((r) => r.path == ApiPaths.marketplaceCallback(p))
                .data
            as Map<Object?, Object?>;

    testWidgets('Kết nối mở authorizationUrl ngoài app; deep link thành công '
        '→ callback, tải lại trạng thái, báo đã kết nối', (tester) async {
      final backend = _integration(
        shopee: _dto(1, 'CONNECTED', shopName: 'Shop Demo Official'),
      );
      await pump(tester, backend);

      expect(
        find.text(
          'Công tắc tự nhập của TikTok Shop là dữ liệu mẫu, backend chưa có '
          'API.',
        ),
        findsOneWidget,
      );
      expect(status(tester, 'tiktokShop'), 'Chưa kết nối');

      await tester.tap(find.byKey(const Key('connect_tiktokShop')));
      await frames(tester);
      expect(opened.single.host, 'shopee-simulator.onrender.com');
      expect(
        backend.requests
            .singleWhere(
              (r) =>
                  r.path ==
                  ApiPaths.marketplaceAuthorization(Platform.tiktokShop),
            )
            .data,
        {'redirect_uri': 'smartomni://oauth/tiktok'},
      );
      // Đang chờ deep link: nút đang tải, không bấm lại được.
      expect(button(tester, 'connect_tiktokShop').loading, isTrue);
      expect(pending.value, Platform.tiktokShop);

      links.send(Uri.parse('smartomni://oauth/tiktok?code=c9&state=st-1'));
      await tester.pumpAndSettle();

      expect(callbackBody(backend, Platform.tiktokShop), {
        'code': 'c9',
        'state': 'st-1',
        'error': null,
        'errorDescription': null,
      });
      expect(find.text('Đã kết nối TikTok Shop'), findsOneWidget);
      expect(status(tester, 'tiktokShop'), 'Đã kết nối');
      expect(pending.value, isNull);
    });

    testWidgets('từ chối (error=access_denied) → "Bạn đã từ chối cấp quyền"', (
      tester,
    ) async {
      final backend = _integration();
      await pump(tester, backend);

      await tester.tap(find.byKey(const Key('connect_shopee')));
      await frames(tester);
      links.send(
        Uri.parse('smartomni://oauth/shopee?error=access_denied&state=st-1'),
      );
      await tester.pumpAndSettle();

      expect(callbackBody(backend, Platform.shopee)['error'], 'access_denied');
      expect(find.text('Bạn đã từ chối cấp quyền'), findsOneWidget);
      expect(status(tester, 'shopee'), 'Chưa kết nối');
      expect(button(tester, 'connect_shopee').onPressed, isNotNull);
    });

    testWidgets('sai state → "Phiên kết nối không hợp lệ"', (tester) async {
      final backend = _integration();
      await pump(tester, backend);

      await tester.tap(find.byKey(const Key('connect_shopee')));
      await frames(tester);
      links.send(Uri.parse('smartomni://oauth/shopee?code=c&state=gia-mao'));
      await tester.pumpAndSettle();

      expect(
        find.text('Phiên kết nối không hợp lệ. Bấm Kết nối để thử lại.'),
        findsOneWidget,
      );
      expect(status(tester, 'shopee'), 'Chưa kết nối');
    });

    testWidgets('link lạ, hoặc không có lần Kết nối nào đang chờ → bỏ qua', (
      tester,
    ) async {
      final backend = _integration();
      await pump(tester, backend);

      // Chưa bấm Kết nối.
      links.send(Uri.parse('smartomni://oauth/shopee?code=c&state=st-1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('connect_shopee')));
      await frames(tester);
      // Link lạ và link của sàn khác.
      links
        ..send(Uri.parse('smartomni://other/shopee?code=c&state=st-1'))
        ..send(Uri.parse('smartomni://oauth/tiktok?code=c&state=st-1'));
      await frames(tester);

      expect(
        backend.requests.where((r) => r.path.endsWith('/callback')),
        isEmpty,
      );
      expect(find.byType(SoToast), findsNothing);
      expect(button(tester, 'connect_shopee').loading, isTrue);
    });

    testWidgets('quay lại app không qua deep link → hủy, không báo lỗi; link '
        'đến sau đó bị bỏ qua', (tester) async {
      final backend = _integration();
      await pump(tester, backend);

      await tester.tap(find.byKey(const Key('connect_shopee')));
      await frames(tester);
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(MarketplaceOAuthController.resumeGrace);
      await tester.pumpAndSettle();

      expect(button(tester, 'connect_shopee').loading, isFalse);
      expect(button(tester, 'connect_shopee').onPressed, isNotNull);
      expect(find.byType(SoToast), findsNothing);
      expect(pending.value, isNull);

      links.send(Uri.parse('smartomni://oauth/shopee?code=c&state=st-1'));
      await tester.pumpAndSettle();
      expect(
        backend.requests.where((r) => r.path.endsWith('/callback')),
        isEmpty,
      );
    });

    testWidgets('app bị tắt khi ở trình duyệt: mở lại bằng deep link vẫn xử lý '
        '(sàn chờ lưu trong máy)', (tester) async {
      // Lần chạy trước đã bắt đầu OAuth Shopee (BE cấp st-1) rồi app bị tắt.
      final backend = _integration(issuedStates: {'st-1'});
      pending.value = Platform.shopee;
      links = FakeDeepLinkSource(
        Uri.parse('smartomni://oauth/shopee?code=c&state=st-1&shop_id=55'),
      );
      await pump(tester, backend);

      expect(callbackBody(backend, Platform.shopee)['shop_id'], '55');
      expect(find.text('Đã kết nối Shopee'), findsOneWidget);
      expect(status(tester, 'shopee'), 'Đã kết nối');
      expect(pending.value, isNull);
    });

    testWidgets('mở lại app không kèm deep link → bỏ lần chờ cũ', (
      tester,
    ) async {
      pending.value = Platform.shopee;
      await pump(tester, _integration());
      expect(pending.value, isNull);
      expect(find.byType(SoToast), findsNothing);
    });

    testWidgets('BE từ chối redirect_uri → báo lỗi tiếng Việt, không mở '
        'trình duyệt', (tester) async {
      await pump(
        tester,
        _integration(authorizationError: 'INVALID_REDIRECT_URI'),
      );
      await tester.tap(find.byKey(const Key('connect_tiktokShop')));
      await frames(tester);

      expect(opened, isEmpty);
      expect(
        find.text(
          'Máy chủ chưa cho phép quay về app sau khi ủy quyền. Liên hệ quản '
          'trị SmartOmni.',
        ),
        findsOneWidget,
      );
      expect(button(tester, 'connect_tiktokShop').onPressed, isNotNull);
    });

    testWidgets('không mở được trình duyệt → báo lỗi, bỏ chờ', (tester) async {
      openResult = false;
      await pump(tester, _integration());
      await tester.tap(find.byKey(const Key('connect_shopee')));
      await frames(tester);

      expect(
        find.text('Không mở được trang ủy quyền của sàn.'),
        findsOneWidget,
      );
      expect(pending.value, isNull);
      expect(button(tester, 'connect_shopee').onPressed, isNotNull);
    });

    testWidgets('Staff: không có nút Kết nối / Ngắt kết nối, công tắc tắt', (
      tester,
    ) async {
      await pump(
        tester,
        _integration(shopee: _dto(1, 'CONNECTED'), tiktok: _dto(2, 'REVOKED')),
        role: UserRole.staff,
      );
      for (final key in [
        'connect_shopee',
        'disconnect_shopee',
        'reconnect_tiktokShop',
        'disconnect_tiktokShop',
      ]) {
        expect(find.byKey(Key(key)), findsNothing, reason: key);
      }
      expect(
        tester
            .widget<Switch>(find.byKey(const Key('auto_import_shopee')))
            .onChanged,
        isNull,
      );
      expect(status(tester, 'tiktokShop'), 'Lỗi kết nối');
    });

    testWidgets('ngắt kết nối gọi BE; công tắc tự nhập Shopee gọi PATCH', (
      tester,
    ) async {
      final backend = _integration(shopee: _dto(1, 'CONNECTED'));
      await pump(tester, backend);

      await tester.tap(find.byKey(const Key('auto_import_shopee')));
      await tester.pumpAndSettle();
      expect(backend.calls(ApiPaths.shopeeSettings), 1);
      expect(
        tester
            .widget<Switch>(find.byKey(const Key('auto_import_shopee')))
            .value,
        isTrue,
      );

      await tapVisible(tester, find.byKey(const Key('disconnect_shopee')));
      await tester.tap(find.byKey(const Key('disconnect_confirm')));
      await tester.pumpAndSettle();
      expect(backend.calls(ApiPaths.marketplaceDisconnect(Platform.shopee)), 1);
      expect(status(tester, 'shopee'), 'Chưa kết nối');
    });

    testWidgets('lỗi kết nối có "Kết nối lại", vừa 360dp', (tester) async {
      await pump(
        tester,
        _integration(shopee: _dto(1, 'REVOKED')),
        size: const Size(360, 900),
      );
      expect(tester.takeException(), isNull);
      expect(button(tester, 'reconnect_shopee').onPressed, isNotNull);
      expect(find.text('Đơn và tồn kho đang ngừng đồng bộ.'), findsOneWidget);
    });
  });
}
