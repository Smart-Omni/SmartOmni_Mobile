import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/app/config/app_config.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/models/platform.dart';
import 'package:smartomni_mobile/core/network/api_exception.dart';
import 'package:smartomni_mobile/core/utils/mock_delay.dart';
import 'package:smartomni_mobile/features/marketplace/data/marketplace_repositories.dart';
import 'package:smartomni_mobile/features/marketplace/domain/marketplace_connection.dart';
import 'package:smartomni_mobile/features/marketplace/presentation/marketplace_oauth.dart';
import 'package:smartomni_mobile/features/marketplace/presentation/marketplace_providers.dart';
import 'package:smartomni_mobile/features/marketplace/presentation/marketplace_screen.dart';
import 'package:smartomni_mobile/l10n/l10n.dart';

import '../helpers/test_app.dart';

DateTime _now() => DateTime(2026, 10, 20, 14, 30);

MarketplaceConnection _conn(Platform p, ConnectionStatus s) =>
    MarketplaceConnection(id: 1, platform: p, status: s);

Future<MarketplaceMockRepository> _pump(
  WidgetTester tester, {
  Size size = const Size(428, 1200),
}) async {
  MockDelay.enabled = false;
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = MarketplaceMockRepository(clock: _now);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(testConfig),
        marketplaceRepositoryProvider.overrideWithValue(repo),
        deepLinkSourceProvider.overrideWithValue(FakeDeepLinkSource()),
        oauthPendingStoreProvider.overrideWithValue(
          InMemoryOAuthPendingStore(),
        ),
        urlOpenerProvider.overrideWithValue(
          (_) => throw StateError('mock không được mở trình duyệt'),
        ),
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
  return repo;
}

Finder _inCard(String platform, Finder finder) => find.descendant(
  of: find.byKey(Key('platform_card_$platform')),
  matching: finder,
);

String _status(WidgetTester tester, String platform) => tester
    .widget<SoStatusTag>(find.byKey(Key('platform_status_$platform')))
    .label;

/// OAuth giả của mock: bắt đầu rồi gửi lại đúng deep link mock trả về.
Future<MarketplaceConnection> _oauth(
  MarketplaceMockRepository repo,
  Platform platform,
) async {
  final start = await repo.startAuthorization(platform);
  return repo.completeAuthorization(
    OAuthCallback.tryParse(start.authorizationUrl)!,
  );
}

void main() {
  group('canConnect: mỗi sàn 1 shop', () {
    test('chưa có, lỗi, đã ngắt thì được; đang kết nối thì không', () {
      expect(canConnect(const [], Platform.shopee), isTrue);
      for (final (status, expected) in [
        (ConnectionStatus.error, true),
        (ConnectionStatus.disconnected, true),
        (ConnectionStatus.connected, false),
      ]) {
        expect(
          canConnect([_conn(Platform.shopee, status)], Platform.shopee),
          expected,
        );
      }
      // Sàn khác không ảnh hưởng.
      expect(
        canConnect([
          _conn(Platform.shopee, ConnectionStatus.connected),
        ], Platform.tiktokShop),
        isTrue,
      );
    });
  });

  group('MarketplaceMockRepository', () {
    setUp(() => MockDelay.enabled = false);

    test('kết nối lại sàn đang lỗi thì thay bản ghi cũ', () async {
      final repo = MarketplaceMockRepository(clock: _now);
      final start = await repo.startAuthorization(Platform.tiktokShop);
      expect(start.authorizationUrl.scheme, 'smartomni');
      expect(start.authorizationUrl.path, '/tiktok');
      await _oauth(repo, Platform.tiktokShop);
      final list = await repo.listConnections();
      expect(
        list.where((c) => c.platform == Platform.tiktokShop),
        hasLength(1),
      );
      expect(
        connectionFor(list, Platform.tiktokShop)!.status,
        ConnectionStatus.connected,
      );
    });

    test('kết nối sàn đang chạy thì báo "Mỗi sàn chỉ 1 shop"', () async {
      final repo = MarketplaceMockRepository(clock: _now);
      expect(
        () => _oauth(repo, Platform.shopee),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Mỗi sàn chỉ 1 shop'),
          ),
        ),
      );
    });

    test('ngắt kết nối rồi kết nối lại được; đổi tự nhập', () async {
      final repo = MarketplaceMockRepository(clock: _now);
      await repo.setAutoImport(Platform.shopee, enabled: false);
      var shopee = connectionFor(await repo.listConnections(), Platform.shopee);
      expect(shopee!.autoImportProducts, isFalse);

      await repo.disconnect(Platform.shopee);
      shopee = connectionFor(await repo.listConnections(), Platform.shopee);
      expect(shopee!.status, ConnectionStatus.disconnected);

      await _oauth(repo, Platform.shopee);
      shopee = connectionFor(await repo.listConnections(), Platform.shopee);
      expect(shopee!.status, ConnectionStatus.connected);
    });

    test('state sai hoặc dùng lại → *_STATE_INVALID; từ chối → '
        '*_AUTHORIZATION_DENIED', () async {
      final repo = MarketplaceMockRepository(clock: _now);
      await repo.disconnect(Platform.shopee);
      Matcher code(String c) =>
          throwsA(isA<ApiException>().having((e) => e.code, 'code', c));

      await repo.startAuthorization(Platform.shopee);
      expect(
        () => repo.completeAuthorization(
          const OAuthCallback(platform: Platform.shopee, state: 'lạ'),
        ),
        code('SHOPEE_STATE_INVALID'),
      );

      final start = await repo.startAuthorization(Platform.tiktokShop);
      final state = start.authorizationUrl.queryParameters['state'];
      await expectLater(
        repo.completeAuthorization(
          OAuthCallback(
            platform: Platform.tiktokShop,
            state: state,
            error: 'access_denied',
          ),
        ),
        code('TIKTOK_AUTHORIZATION_DENIED'),
      );
      // state đã dùng.
      await expectLater(
        repo.completeAuthorization(
          OAuthCallback(platform: Platform.tiktokShop, state: state),
        ),
        code('TIKTOK_STATE_INVALID'),
      );
    });
  });

  testWidgets('T-10: thẻ đã kết nối đủ thông tin; thẻ lỗi có banner, không có '
      'công tắc', (tester) async {
    await _pump(tester);

    expect(find.text('Kết nối sàn'), findsOneWidget);
    expect(find.byType(SoMockBanner), findsOneWidget);

    expect(_status(tester, 'shopee'), 'Đã kết nối');
    expect(_inCard('shopee', find.text('Shop Demo Official')), findsOneWidget);
    expect(_inCard('shopee', find.text('123456789')), findsOneWidget);
    expect(_inCard('shopee', find.text('Đồng bộ lần cuối')), findsOneWidget);
    expect(_inCard('shopee', find.text('20/10/2026 14:25')), findsOneWidget);
    expect(find.byKey(const Key('auto_import_shopee')), findsOneWidget);
    expect(find.byKey(const Key('disconnect_shopee')), findsOneWidget);
    expect(find.byKey(const Key('platform_error_shopee')), findsNothing);

    expect(_status(tester, 'tiktokShop'), 'Lỗi kết nối');
    expect(find.byKey(const Key('platform_error_tiktokShop')), findsOneWidget);
    expect(find.byKey(const Key('reconnect_tiktokShop')), findsOneWidget);
    expect(find.byKey(const Key('disconnect_tiktokShop')), findsOneWidget);
    expect(find.byKey(const Key('auto_import_tiktokShop')), findsNothing);
  });

  testWidgets('T-10: tắt tự nhập', (tester) async {
    final repo = await _pump(tester);

    await tester.tap(find.byKey(const Key('auto_import_shopee')));
    await tester.pumpAndSettle();

    expect(find.text('Đã tắt tự nhập sản phẩm & đơn'), findsOneWidget);
    final shopee = connectionFor(await repo.listConnections(), Platform.shopee);
    expect(shopee!.autoImportProducts, isFalse);
    expect(
      tester.widget<Switch>(find.byKey(const Key('auto_import_shopee'))).value,
      isFalse,
    );
  });

  testWidgets('T-10: ngắt kết nối hỏi trước, xong thẻ thành "Chưa kết nối"', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('disconnect_shopee')));
    await tester.pumpAndSettle();
    expect(find.text('Ngắt kết nối Shopee?'), findsOneWidget);
    expect(
      find.text('Đơn, sản phẩm và tồn kho sẽ ngừng đồng bộ với shop này.'),
      findsOneWidget,
    );

    // Hủy: không đổi gì.
    await tester.tap(find.byKey(const Key('disconnect_cancel')));
    await tester.pumpAndSettle();
    expect(_status(tester, 'shopee'), 'Đã kết nối');

    await tester.tap(find.byKey(const Key('disconnect_shopee')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('disconnect_confirm')));
    await tester.pumpAndSettle();

    expect(_status(tester, 'shopee'), 'Chưa kết nối');
    expect(
      _inCard(
        'shopee',
        find.text('Kết nối để nhập đơn và sản phẩm từ Shopee.'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('connect_shopee')), findsOneWidget);
    expect(_inCard('shopee', find.text('123456789')), findsNothing);
  });

  testWidgets('T-10 mock: Kết nối lại chạy OAuth giả (không mở trình duyệt), '
      'xong thẻ hết lỗi', (tester) async {
    await _pump(tester);

    await tapVisible(tester, find.byKey(const Key('reconnect_tiktokShop')));
    expect(find.text('Kết nối TikTok Shop'), findsOneWidget);
    await tester.tap(find.byKey(const Key('oauth_open')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('oauth_sheet')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('oauth_done')),
        matching: find.text('Đã kết nối TikTok Shop'),
      ),
      findsOneWidget,
    );
    expect(_status(tester, 'tiktokShop'), 'Đã kết nối');
    expect(find.byKey(const Key('platform_error_tiktokShop')), findsNothing);
    expect(find.byKey(const Key('auto_import_tiktokShop')), findsOneWidget);
  });

  testWidgets('T-10 và sheet "Kết nối …" vừa bề rộng 360dp', (tester) async {
    await _pump(tester, size: const Size(360, 1200));
    expect(tester.takeException(), isNull);

    await tapVisible(tester, find.byKey(const Key('reconnect_tiktokShop')));
    expect(find.byKey(const Key('oauth_sheet')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
