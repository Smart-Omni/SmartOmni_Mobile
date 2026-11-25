import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/app/bootstrap.dart';
import 'package:smartomni_mobile/app/config/app_config.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/network/api_exception.dart';
import 'package:smartomni_mobile/core/network/api_paths.dart';
import 'package:smartomni_mobile/core/utils/clock.dart';
import 'package:smartomni_mobile/core/utils/mock_delay.dart';
import 'package:smartomni_mobile/features/account/domain/account_repository.dart';
import 'package:smartomni_mobile/features/account/presentation/account_providers.dart';
import 'package:smartomni_mobile/features/subscription/data/subscription_mock_repository.dart';
import 'package:smartomni_mobile/features/subscription/data/subscription_remote_repository.dart';
import 'package:smartomni_mobile/features/subscription/domain/subscription.dart';
import 'package:smartomni_mobile/features/subscription/presentation/checkout_sheet.dart';
import 'package:smartomni_mobile/features/subscription/presentation/subscription_providers.dart';
import 'package:smartomni_mobile/features/subscription/presentation/subscription_screen.dart';

import '../helpers/fake_backend.dart';
import '../helpers/test_app.dart';

final _now = DateTime(2026, 11, 25, 9);
const _code = 'PRO000300012';

/// `SubscriptionSummaryResponse` đúng như Jackson của BE `f9495df` ghi ra:
/// field `boolean isPro` (Lombok `isPro()`) thành khóa `"pro"`.
Map<String, Object?> _summary({
  String status = 'EXPIRING_SOON',
  bool canRenewEarly = true,
  int daysRemaining = 3,
  String periodEnd = '2026-11-28',
}) {
  final free = status == 'FREE';
  return {
    'planName': free || status == 'EXPIRED' ? 'FREE' : 'PRO',
    'pro': !free && status != 'EXPIRED',
    'status': status,
    'periodStart': free ? null : '2026-10-28',
    'periodEnd': free ? null : periodEnd,
    'daysRemaining': daysRemaining,
    'canRenewEarly': canRenewEarly,
    'currentInvoiceId': free ? null : 12,
  };
}

/// `SubscriptionInvoiceDto` như `getTenantInvoices` dựng.
Map<String, Object?> _invoice(int id, {String status = 'PAID'}) => {
  'id': id,
  'invoiceNumber': 'INV-$id',
  'paymentCode': 'PRO00030000$id',
  'gatewayTransactionId': 'SIM-1732500000000',
  'paymentMethod': 'Chuyển khoản SePay (VietQR)',
  'period': '2026-10-28 - 2026-11-28',
  'amount': 499000.00,
  'status': status,
  'dueDate': '2026-10-28',
  'paidAt': '2026-10-28T03:15:00Z',
  'createdAt': '2026-10-28T03:15:00Z',
};

Map<String, Object?> _checkout({String qrUrl = ''}) => {
  'orderCode': _code,
  'amount': 499000.00,
  'qrUrl': qrUrl,
  'accountNumber': '0000000001',
  'bankId': 'MBBank',
  'accountHolder': 'HO KINH DOANH SmartOmni',
  'memo': _code,
  'planName': 'PRO',
  'expiresAt': _now.add(const Duration(minutes: 15)).toUtc().toIso8601String(),
};

/// BE giả: trả [status] / [invoices], `checkout` trả [checkout], trạng thái
/// đơn là [orderStatus]. `simulate-pay` đổi [orderStatus] sang PAID.
class _Be {
  Map<String, Object?> status = _summary();
  List<Object?> invoices = [_invoice(12)];
  (int, Object?) checkout = (200, ok(_checkout()));
  String orderStatus = 'PENDING';

  late final backend = FakeBackend((o) async {
    final path = o.path;
    if (path == ApiPaths.subscriptionStatus) return (200, ok(status));
    if (path == ApiPaths.subscriptionInvoices) return (200, ok(invoices));
    if (path == ApiPaths.subscriptionCheckout) return checkout;
    if (path == ApiPaths.subscriptionOrderStatus(_code)) {
      return (
        200,
        ok({
          'orderCode': _code,
          'status': orderStatus,
          'planName': orderStatus == 'PAID' ? 'PRO' : 'FREE',
        }),
      );
    }
    if (path == ApiPaths.subscriptionSimulatePay(_code)) {
      orderStatus = 'PAID';
      return (200, ok(true));
    }
    return (404, apiError('Không tìm thấy'));
  });

  int get polls => backend.calls(ApiPaths.subscriptionOrderStatus(_code));

  SubscriptionRepository repo({DateTime Function()? clock}) =>
      SubscriptionRemoteRepository(
        fakeDio(backend),
        usage: SubscriptionMockRepository(clock: () => _now),
        clock: clock ?? () => _now,
      );
}

/// Đếm số lần tải `tenants/me` (hồ sơ M-50).
class _CountingAccount implements AccountRepository {
  var calls = 0;

  @override
  Future<AccountProfile> getProfile() async {
    calls++;
    return AccountProfile(
      email: 'admin@demo.vn',
      storeName: 'Shop Demo',
      planType: calls == 1 ? 'FREE' : 'PRO',
    );
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {}
}

Future<void> _openPlan(
  WidgetTester tester, {
  SubscriptionRepository? repo,
  List<Override> overrides = const [],
}) async {
  await loginAs(
    tester,
    'admin@demo.vn',
    tallView: true,
    overrides: [
      clockProvider.overrideWithValue(() => _now),
      if (repo != null) ...[
        subscriptionUseRemoteProvider.overrideWithValue(true),
        subscriptionRepositoryProvider.overrideWithValue(repo),
      ],
      ...overrides,
    ],
  );
  await tester.tap(find.byKey(const Key('nav_more')));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byKey(const Key('menu_subscription')));
}

/// Chỉ dựng sheet trên một trang trống. Trả kết quả `showCheckoutSheet` qua
/// [onResult].
Future<void> _pumpSheet(
  WidgetTester tester, {
  required SubscriptionRepository repo,
  Flavor flavor = Flavor.dev,
  DateTime Function()? clock,
  void Function(bool?)? onResult,
}) async {
  MockDelay.enabled = false;
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: noAutoRetry,
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(
            flavor: flavor,
            apiBaseUrl: 'http://localhost:8080',
            useMock: false,
          ),
        ),
        clockProvider.overrideWithValue(clock ?? () => _now),
        subscriptionRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: SoTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const Key('open'),
              onPressed: () async {
                final result = await showCheckoutSheet(context);
                onResult?.call(result);
              },
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await _settle(tester);
}

/// `pumpAndSettle` dừng khi hết khung hình, có thể trước khi phản hồi của
/// [FakeBackend] về. Pump thêm vài nhịp ngắn (tổng < 1 giây, chưa tới lần
/// hỏi trạng thái 5 giây).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

String _planStatus(WidgetTester tester) =>
    tester.widget<SoStatusTag>(find.byKey(const Key('plan_status'))).label;

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

Color? _barColor(WidgetTester tester, String key) => tester
    .widget<SoProgressBar>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(SoProgressBar),
      ),
    )
    .color;

void main() {
  setUp(() => MockDelay.enabled = false);

  group('JSON BE f9495df', () {
    test('status: đọc "pro" (Jackson) và cả "isPro"', () {
      final s = SubscriptionJson.summary(_summary());
      expect(s.planName, 'PRO');
      expect(s.isPro, isTrue);
      expect(s.status, PlanStatus.expiringSoon);
      expect(s.periodStart, DateTime(2026, 10, 28));
      expect(s.periodEnd, DateTime(2026, 11, 28));
      expect(s.daysRemaining, 3);
      expect(s.canRenewEarly, isTrue);
      expect(s.currentInvoiceId, 12);

      final legacy = {..._summary()}
        ..remove('pro')
        ..['isPro'] = true;
      expect(SubscriptionJson.summary(legacy).isPro, isTrue);
      final noFlag = {..._summary()}..remove('pro');
      expect(SubscriptionJson.summary(noFlag).isPro, isFalse);
    });

    test('status: FREE (ngày null), trạng thái lạ coi là FREE', () {
      final s = SubscriptionJson.summary(_summary(status: 'FREE'));
      expect(s.status, PlanStatus.free);
      expect(s.isPro, isFalse);
      expect(s.periodEnd, isNull);
      expect(PlanStatus.fromBackend('active'), PlanStatus.active);
      expect(PlanStatus.fromBackend('EXPIRED'), PlanStatus.expired);
      expect(PlanStatus.fromBackend('???'), PlanStatus.free);
      expect(PlanStatus.fromBackend(null), PlanStatus.free);
      expect(SubscriptionJson.summary(null).planName, 'FREE');
    });

    test('canPay: FREE, EXPIRED, hoặc canRenewEarly', () {
      SubscriptionSummary s(PlanStatus st, {bool early = false}) =>
          SubscriptionSummary(
            planName: 'PRO',
            isPro: true,
            status: st,
            canRenewEarly: early,
          );
      expect(s(PlanStatus.free).canPay, isTrue);
      expect(s(PlanStatus.expired).canPay, isTrue);
      expect(s(PlanStatus.expiringSoon, early: true).canPay, isTrue);
      expect(s(PlanStatus.active).canPay, isFalse);
    });

    test('invoice: mã, số tiền, kỳ "a - b", ngày trả', () {
      final i = SubscriptionJson.invoices([_invoice(12), 'rác']).single;
      expect(i.code, 'INV-12');
      expect(i.amount, 499000);
      expect(i.paid, isTrue);
      expect(i.periodStart, DateTime(2026, 10, 28));
      expect(i.periodEnd, DateTime(2026, 11, 28));
      expect(i.paidAt, DateTime.utc(2026, 10, 28, 3, 15).toLocal());
      expect(i.paymentMethod, 'Chuyển khoản SePay (VietQR)');

      final odd = SubscriptionJson.invoice({
        'id': 7,
        'period': ' - ',
        'status': 'PENDING',
      });
      expect(odd.code, 'INV-7');
      expect(odd.paid, isFalse);
      expect(odd.periodStart, isNull);
    });

    test('checkout: đủ trường; thiếu orderCode thì lỗi', () {
      final c = SubscriptionJson.checkout(_checkout(), now: _now);
      expect(c.orderCode, _code);
      expect(c.amount, 499000);
      expect(c.accountNumber, '0000000001');
      expect(c.bankId, 'MBBank');
      expect(c.accountHolder, 'HO KINH DOANH SmartOmni');
      expect(c.memo, _code);
      expect(c.expiresAt, _now.add(const Duration(minutes: 15)));
      expect(
        () => SubscriptionJson.checkout({'amount': 1}, now: _now),
        throwsA(isA<ApiException>()),
      );
    });

    test('trạng thái đơn', () {
      expect(
        SubscriptionJson.orderStatus({'status': 'PAID'}),
        PaymentStatus.paid,
      );
      expect(
        SubscriptionJson.orderStatus({'status': 'EXPIRED'}),
        PaymentStatus.expired,
      );
      expect(
        SubscriptionJson.orderStatus({'status': 'FAILED'}),
        PaymentStatus.failed,
      );
      expect(SubscriptionJson.orderStatus(null), PaymentStatus.pending);
    });

    test('lỗi gia hạn sớm: câu tiếng Việt của app', () {
      const e = ApiException(
        type: ApiErrorType.validation,
        message: 'Gói Pro của bạn vẫn còn 20 ngày hiệu lực…',
        statusCode: 400,
        code: earlyRenewalTooEarlyCode,
      );
      expect(
        checkoutErrorMessage(e),
        'Gói PRO còn hơn 5 ngày hiệu lực. Bạn chỉ gia hạn được khi còn từ 5 '
        'ngày trở xuống.',
      );
      expect(
        checkoutErrorMessage(
          const ApiException(type: ApiErrorType.server, message: 'Lỗi máy chủ'),
        ),
        'Lỗi máy chủ',
      );
    });

    test('usageLevel: < 80% bình thường, ≥ 80% sắp chạm, đầy là hết', () {
      expect(usageLevel(const UsageQuota(79, 100)), UsageLevel.normal);
      expect(usageLevel(const UsageQuota(80, 100)), UsageLevel.near);
      expect(usageLevel(const UsageQuota(2, 2)), UsageLevel.full);
      expect(usageLevel(const UsageQuota(999, null)), UsageLevel.normal);
    });
  });

  testWidgets('M-50 Staff: không có mục Gói dịch vụ', (tester) async {
    await loginAs(tester, 'staff@demo.vn', tallView: true);
    await tester.tap(find.byKey(const Key('nav_more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu_subscription')), findsNothing);
  });

  testWidgets('T-40 mock: gói, mức dùng ba màu, hóa đơn, nút Thanh toán', (
    tester,
  ) async {
    await _openPlan(tester);
    final c = tester.element(find.byType(SubscriptionScreen)).soColors;

    expect(find.byType(SoMockBanner), findsOneWidget);
    expect(find.byKey(const Key('usage_mock')), findsNothing);
    expect(_text(tester, 'plan_name'), 'PRO');
    expect(_planStatus(tester), 'Sắp hết hạn');
    expect(_text(tester, 'plan_detail'), 'Hết hạn 28/11/2026 · còn 3 ngày');

    expect(find.text('312 / 500 SKU'), findsOneWidget);
    expect(_barColor(tester, 'usage_skus'), c.brand);
    expect(_barColor(tester, 'usage_connections'), c.danger);
    expect(_barColor(tester, 'usage_storage'), c.warning);

    expect(find.byKey(const Key('invoice_INV-3')), findsOneWidget);
    expect(find.text('Đã thanh toán'), findsNWidgets(3));
    expect(find.byKey(const Key('plan_unpaid')), findsNothing);
    expect(find.text('Thanh toán'), findsOneWidget);
    expect(find.text('Đổi gói'), findsNothing);
  });

  testWidgets('T-40 BE thật: chỉ phần hạn mức có dải mẫu, PRO còn dài '
      'thì không có nút thanh toán', (tester) async {
    final be = _Be()
      ..status = _summary(
        status: 'ACTIVE',
        canRenewEarly: false,
        daysRemaining: 20,
        periodEnd: '2026-12-15',
      );
    await _openPlan(tester, repo: be.repo());

    expect(find.byKey(const Key('usage_mock')), findsOneWidget);
    expect(find.byType(SoMockBanner), findsOneWidget);
    expect(_planStatus(tester), 'Đang dùng');
    expect(_text(tester, 'plan_detail'), 'Hết hạn 15/12/2026 · còn 20 ngày');
    expect(find.byKey(const Key('invoice_INV-12')), findsOneWidget);
    expect(find.text('INV-12'), findsOneWidget);
    expect(find.text('499.000 ₫'), findsOneWidget);
    expect(find.byKey(const Key('plan_pay')), findsNothing);
  });

  testWidgets('T-40 FREE: "Nâng cấp PRO"; hóa đơn chưa thanh toán có banner', (
    tester,
  ) async {
    final be = _Be()
      ..status = _summary(status: 'FREE', canRenewEarly: false)
      ..invoices = [_invoice(5, status: 'PENDING')];
    await _openPlan(tester, repo: be.repo());
    expect(_text(tester, 'plan_name'), 'Free');
    expect(_planStatus(tester), 'Miễn phí');
    expect(find.text('Nâng cấp PRO'), findsOneWidget);
    expect(find.text('Chưa thanh toán'), findsOneWidget);
    expect(find.byKey(const Key('plan_unpaid')), findsOneWidget);
  });

  testWidgets('T-40: hết hạn có nút Thanh toán; chưa có hóa đơn', (
    tester,
  ) async {
    final be = _Be()
      ..status = _summary(
        status: 'EXPIRED',
        canRenewEarly: false,
        daysRemaining: 0,
        periodEnd: '2026-11-20',
      )
      ..invoices = [];
    await _openPlan(tester, repo: be.repo());
    expect(_planStatus(tester), 'Đã hết hạn');
    expect(_text(tester, 'plan_detail'), 'Hết hạn 20/11/2026');
    expect(find.byKey(const Key('plan_pay')), findsOneWidget);
    expect(find.byKey(const Key('invoices_empty')), findsOneWidget);
  });

  testWidgets('T-40: PAID -> đóng sheet, báo thành công, tải lại gói, hóa '
      'đơn và tenants/me', (tester) async {
    final be = _Be();
    final account = _CountingAccount();
    await _openPlan(
      tester,
      repo: be.repo(),
      overrides: [accountRepositoryProvider.overrideWithValue(account)],
    );
    final statusLoads = be.backend.calls(ApiPaths.subscriptionStatus);
    final invoiceLoads = be.backend.calls(ApiPaths.subscriptionInvoices);
    // Giữ hồ sơ (`tenants/me`) sống như khi M-51 đang dùng, để thấy nó được
    // tải lại sau khi thanh toán.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SubscriptionScreen)),
    );
    final sub = container.listen(accountProfileProvider, (_, _) {});
    addTearDown(sub.close);
    await tester.pumpAndSettle();
    final profileLoads = account.calls;

    await tester.tap(find.byKey(const Key('plan_pay')));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutSheet), findsOneWidget);

    be
      ..orderStatus = 'PAID'
      ..status = _summary(
        status: 'ACTIVE',
        canRenewEarly: false,
        daysRemaining: 33,
        periodEnd: '2026-12-28',
      );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.byType(CheckoutSheet), findsNothing);
    expect(
      find.text('Thanh toán thành công. Cửa hàng đã ở gói PRO.'),
      findsOneWidget,
    );
    expect(be.backend.calls(ApiPaths.subscriptionStatus), statusLoads + 1);
    expect(be.backend.calls(ApiPaths.subscriptionInvoices), invoiceLoads + 1);
    expect(account.calls, profileLoads + 1);
    expect(container.read(accountProfileProvider).value?.planType, 'PRO');
    expect(_planStatus(tester), 'Đang dùng');

    final polls = be.polls;
    await tester.pump(const Duration(seconds: 20));
    expect(be.polls, polls, reason: 'PAID rồi thì ngừng hỏi');
  });

  testWidgets('T-40: lỗi tải -> Thử lại', (tester) async {
    var fail = true;
    final be = _Be();
    final backend = FakeBackend((o) async {
      if (fail && o.path == ApiPaths.subscriptionStatus) {
        fail = false;
        offline(o);
      }
      return be.backend.handle(o);
    });
    await _openPlan(
      tester,
      repo: SubscriptionRemoteRepository(
        fakeDio(backend),
        usage: SubscriptionMockRepository(clock: () => _now),
        clock: () => _now,
      ),
    );
    expect(find.byKey(const Key('plan_error')), findsOneWidget);
    await tapVisible(tester, find.text('Thử lại'));
    expect(find.byKey(const Key('plan_card')), findsOneWidget);
  });

  testWidgets('T-40 vừa bề rộng 360dp', (tester) async {
    await _openPlan(tester);
    tester.view.physicalSize = const Size(360, 740);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('sheet thanh toán', () {
    testWidgets('hiện STK, ngân hàng, chủ TK, nội dung, số tiền, đếm ngược; '
        'Sao chép', (tester) async {
      await _pumpSheet(tester, repo: _Be().repo());
      expect(find.text('MBBank'), findsOneWidget);
      expect(find.text('0000000001'), findsOneWidget);
      expect(find.text('HO KINH DOANH SmartOmni'), findsOneWidget);
      expect(find.text(_code), findsOneWidget);
      expect(find.text('499.000 ₫'), findsOneWidget);
      expect(_text(tester, 'checkout_countdown'), 'Mã hết hạn sau 15:00');
      expect(find.byKey(const Key('checkout_qr_error')), findsOneWidget);

      // Giả lập clipboard của nền tảng.
      final copied = <String?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String?);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(find.byKey(const Key('copy_memo')));
      await tester.pumpAndSettle();
      expect(find.text('Đã sao chép nội dung'), findsOneWidget);
      await tester.tap(find.byKey(const Key('copy_account')));
      await tester.pumpAndSettle();
      expect(find.text('Đã sao chép số tài khoản'), findsOneWidget);
      expect(copied, [_code, '0000000001']);
    });

    testWidgets('có qrUrl thì dùng ảnh mạng (lỗi tải -> câu hướng dẫn)', (
      tester,
    ) async {
      final be = _Be()
        ..checkout = (
          200,
          ok(_checkout(qrUrl: 'https://vietqr.app/img?acc=0000000001')),
        );
      await _pumpSheet(tester, repo: be.repo());
      final image = tester.widget<Image>(find.byKey(const Key('checkout_qr')));
      expect(
        (image.image as NetworkImage).url,
        'https://vietqr.app/img?acc=0000000001',
      );
    });

    testWidgets('hỏi trạng thái mỗi 5 giây; đóng sheet thì ngừng', (
      tester,
    ) async {
      final be = _Be();
      bool? result = false;
      await _pumpSheet(tester, repo: be.repo(), onResult: (r) => result = r);
      expect(be.polls, 0);
      await tester.pump(const Duration(seconds: 5));
      expect(be.polls, 1);
      await tester.pump(const Duration(seconds: 5));
      expect(be.polls, 2);

      await tester.tap(find.byKey(const Key('checkout_close')));
      await tester.pumpAndSettle();
      expect(find.byType(CheckoutSheet), findsNothing);
      expect(result, isNull);
      await tester.pump(const Duration(seconds: 30));
      expect(be.polls, 2);
    });

    testWidgets('PAID: sheet đóng với true', (tester) async {
      final be = _Be()..orderStatus = 'PAID';
      bool? result;
      await _pumpSheet(tester, repo: be.repo(), onResult: (r) => result = r);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byType(CheckoutSheet), findsNothing);
      expect(result, isTrue);
    });

    testWidgets('EXPIRED: báo, ngừng hỏi, "Tạo mã mới" gọi lại checkout', (
      tester,
    ) async {
      final be = _Be()..orderStatus = 'EXPIRED';
      await _pumpSheet(tester, repo: be.repo());
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('checkout_expired')), findsOneWidget);
      await tester.pump(const Duration(seconds: 20));
      expect(be.polls, 1);

      be.orderStatus = 'PENDING';
      await tester.tap(find.byKey(const Key('checkout_retry')));
      await tester.pumpAndSettle();
      expect(be.backend.calls(ApiPaths.subscriptionCheckout), 2);
      expect(find.text('0000000001'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(be.polls, 2);
    });

    testWidgets('FAILED: báo không thành công', (tester) async {
      final be = _Be()..orderStatus = 'FAILED';
      await _pumpSheet(tester, repo: be.repo());
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('checkout_failed')), findsOneWidget);
      expect(find.byKey(const Key('checkout_retry')), findsOneWidget);
    });

    testWidgets('quá expiresAt mà BE vẫn PENDING thì coi là hết hạn (P4)', (
      tester,
    ) async {
      var now = _now;
      final be = _Be();
      await _pumpSheet(tester, repo: be.repo(), clock: () => now);
      now = _now.add(const Duration(minutes: 16));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('checkout_expired')), findsOneWidget);
      await tester.pump(const Duration(seconds: 20));
      expect(be.polls, 1);
    });

    testWidgets('SUBSCRIPTION_EARLY_RENEWAL_TOO_EARLY: câu tiếng Việt, không '
        'có Tạo mã mới', (tester) async {
      final be = _Be()
        ..checkout = (
          400,
          {
            'success': false,
            'message':
                'Gói Pro của bạn vẫn còn 20 ngày hiệu lực. Bạn chỉ có thể '
                'gia hạn sớm khi còn từ 5 ngày trở xuống.',
            'code': earlyRenewalTooEarlyCode,
          },
        );
      await _pumpSheet(tester, repo: be.repo());
      expect(find.byKey(const Key('checkout_error')), findsOneWidget);
      expect(
        find.text(
          'Gói PRO còn hơn 5 ngày hiệu lực. Bạn chỉ gia hạn được khi còn từ '
          '5 ngày trở xuống.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('checkout_retry')), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      expect(be.polls, 0);
    });

    testWidgets('bản dev: nút giả lập gọi simulate-pay rồi đóng sheet', (
      tester,
    ) async {
      final be = _Be();
      bool? result;
      await _pumpSheet(tester, repo: be.repo(), onResult: (r) => result = r);
      await tester.tap(find.byKey(const Key('pay_simulate')));
      await tester.pumpAndSettle();
      expect(be.backend.calls(ApiPaths.subscriptionSimulatePay(_code)), 1);
      expect(result, isTrue);
    });

    for (final flavor in [Flavor.prod, Flavor.staging]) {
      testWidgets('bản ${flavor.name}: không có nút giả lập', (tester) async {
        await _pumpSheet(tester, repo: _Be().repo(), flavor: flavor);
        expect(find.text('0000000001'), findsOneWidget);
        expect(find.byKey(const Key('pay_simulate')), findsNothing);
        expect(
          AppConfig(
            flavor: flavor,
            apiBaseUrl: '',
            useMock: false,
          ).allowsPaymentSimulation,
          isFalse,
        );
      });
    }

    testWidgets('mock: giả lập xong thì gói được cộng thêm một kỳ', (
      tester,
    ) async {
      await _openPlan(tester);
      await tester.tap(find.byKey(const Key('plan_pay')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pay_simulate')));
      await tester.pumpAndSettle();
      expect(find.byType(CheckoutSheet), findsNothing);
      expect(_planStatus(tester), 'Đang dùng');
      expect(_text(tester, 'plan_detail'), 'Hết hạn 28/12/2026 · còn 33 ngày');
      expect(find.byKey(const Key('invoice_INV-4')), findsOneWidget);
      expect(find.byKey(const Key('plan_pay')), findsNothing);
    });
  });
}
