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
  return repo;
}

Finder _inCard(String platform, Finder finder) => find.descendant(
  of: find.byKey(Key('platform_card_$platform')),
  matching: finder,
);

String _status(WidgetTester tester, String platform) => tester
    .widget<SoStatusTag>(find.byKey(Key('platform_status_$platform')))
    .label;

Finder _field(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(EditableText),
);

Future<void> _fillAppKey(WidgetTester tester) async {
  await tester.enterText(_field('app_key_field'), 'KEY-123');
  await tester.enterText(_field('app_secret_field'), 's3cret');
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
      await repo.connect(
        platform: Platform.tiktokShop,
        appKey: 'k',
        appSecret: 's',
      );
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
        () => repo.connect(
          platform: Platform.shopee,
          appKey: 'k',
          appSecret: 's',
        ),
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

      await repo.connect(
        platform: Platform.shopee,
        appKey: 'k',
        appSecret: 's',
      );
      shopee = connectionFor(await repo.listConnections(), Platform.shopee);
      expect(shopee!.status, ConnectionStatus.connected);
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

    expect(find.byKey(const Key('marketplace_app_key')), findsOneWidget);
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

  testWidgets('T-10: Kết nối lại mở sheet chọn sẵn sàn, kết nối xong thẻ hết '
      'lỗi', (tester) async {
    await _pump(tester);

    await tapVisible(tester, find.byKey(const Key('reconnect_tiktokShop')));
    expect(find.text('Kết nối bằng App Key'), findsOneWidget);
    expect(
      tester
          .widget<SoSegmented<Platform>>(
            find.byKey(const Key('app_key_platform')),
          )
          .selected,
      Platform.tiktokShop,
    );

    // Bỏ trống: báo lỗi bắt buộc, sheet vẫn mở.
    await tester.tap(find.byKey(const Key('app_key_submit')));
    await tester.pumpAndSettle();
    expect(find.text('App Key không được để trống'), findsOneWidget);

    await _fillAppKey(tester);
    await tester.tap(find.byKey(const Key('app_key_submit')));
    await tester.pumpAndSettle();

    expect(find.byType(SoBottomSheet), findsNothing);
    expect(find.text('Đã kết nối TikTok Shop'), findsOneWidget);
    expect(_status(tester, 'tiktokShop'), 'Đã kết nối');
    expect(find.byKey(const Key('platform_error_tiktokShop')), findsNothing);
    expect(find.byKey(const Key('auto_import_tiktokShop')), findsOneWidget);
  });

  testWidgets('Sheet App Key: lỗi server hiện trong sheet; ẩn/hiện secret; '
      'Hủy', (tester) async {
    await _pump(tester);

    await tapVisible(tester, find.byKey(const Key('marketplace_app_key')));
    // Shopee đang chạy nên sheet chọn sẵn sàn còn kết nối được.
    expect(
      tester
          .widget<SoSegmented<Platform>>(
            find.byKey(const Key('app_key_platform')),
          )
          .selected,
      Platform.tiktokShop,
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('app_key_platform')),
        matching: find.text('Shopee'),
      ),
    );
    await tester.pumpAndSettle();
    await _fillAppKey(tester);

    bool obscured() =>
        tester.widget<EditableText>(_field('app_secret_field')).obscureText;
    expect(obscured(), isTrue);
    await tester.tap(find.byKey(const Key('app_secret_toggle')));
    await tester.pump();
    expect(obscured(), isFalse);

    await tester.tap(find.byKey(const Key('app_key_submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app_key_error')), findsOneWidget);
    expect(find.textContaining('Mỗi sàn chỉ 1 shop'), findsOneWidget);
    expect(find.byType(SoBottomSheet), findsOneWidget);

    await tester.tap(find.byKey(const Key('app_key_cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(SoBottomSheet), findsNothing);
  });

  testWidgets('T-10 và sheet vừa bề rộng 360dp', (tester) async {
    await _pump(tester, size: const Size(360, 1200));
    expect(tester.takeException(), isNull);

    await tapVisible(tester, find.byKey(const Key('reconnect_tiktokShop')));
    expect(tester.takeException(), isNull);
  });
}
