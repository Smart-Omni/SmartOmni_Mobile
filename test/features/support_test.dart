import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/utils/clock.dart';
import 'package:smartomni_mobile/core/utils/mock_delay.dart';
import 'package:smartomni_mobile/features/support/domain/support.dart';
import 'package:smartomni_mobile/features/support/presentation/support_providers.dart';
import 'package:smartomni_mobile/features/support/presentation/support_screen.dart';

import '../helpers/test_app.dart';

final _now = DateTime(2026, 10, 22, 9);

/// [failList]: lần `list()` đầu lỗi. [failCreate]: `create()` luôn lỗi.
class _FakeSupport implements SupportRepository {
  _FakeSupport({
    this.tickets = const [],
    this.failList = false,
    this.failCreate = false,
  });

  final List<SupportTicket> tickets;
  final bool failList;
  final bool failCreate;
  var listCalls = 0;

  @override
  Future<List<SupportTicket>> list() async {
    listCalls++;
    if (failList && listCalls == 1) throw Exception('mất mạng');
    return tickets;
  }

  @override
  Future<SupportTicket> create({
    required String title,
    required String description,
  }) async {
    if (failCreate) throw Exception('mất mạng');
    throw UnimplementedError();
  }
}

SupportTicket _t(int id, TicketStatus s, DateTime at) => SupportTicket(
  id: id,
  code: 'SUP-$id',
  title: 'T$id',
  status: s,
  updatedAt: at,
);

Future<void> _openSupport(
  WidgetTester tester, {
  SupportRepository? repo,
}) async {
  await loginAs(
    tester,
    'admin@demo.vn',
    tallView: true,
    overrides: [
      clockProvider.overrideWithValue(() => _now),
      if (repo != null) supportRepositoryProvider.overrideWithValue(repo),
    ],
  );
  await tester.tap(find.byKey(const Key('nav_more')));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byKey(const Key('menu_support')));
}

List<String> _segmentLabels(WidgetTester tester) => [
  for (final s
      in tester
          .widget<SoSegmented<bool>>(find.byKey(const Key('ticket_tabs')))
          .segments)
    s.label,
];

String _replyText(WidgetTester tester, int id) => tester
    .widget<Text>(find.byKey(Key('ticket_reply_$id')))
    .textSpan!
    .toPlainText();

Future<void> _fillTicket(WidgetTester tester, String title, String desc) async {
  await tester.enterText(find.byKey(const Key('ticket_title')), title);
  await tester.enterText(find.byKey(const Key('ticket_description')), desc);
  await tester.tap(find.byKey(const Key('ticket_submit')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => MockDelay.enabled = false);

  group('quy tắc T-50', () {
    test('kiểm tra tiêu đề và mô tả', () {
      expect(validateTicketTitle('  '), 'Tiêu đề không được để trống');
      expect(validateTicketTitle('a' * 121), 'Tiêu đề tối đa 120 ký tự');
      expect(validateTicketTitle('a' * 120), isNull);
      expect(validateTicketDescription(null), 'Mô tả không được để trống');
      expect(validateTicketDescription('a' * 2001), isNotNull);
      expect(validateTicketDescription('Lỗi đồng bộ'), isNull);
    });

    test('splitTickets: tách theo tab, mới cập nhật trước', () {
      final (open, done) = splitTickets([
        _t(1, TicketStatus.open, DateTime(2026, 10, 1)),
        _t(2, TicketStatus.resolved, DateTime(2026, 10, 2)),
        _t(3, TicketStatus.inProgress, DateTime(2026, 10, 3)),
        _t(4, TicketStatus.resolved, DateTime(2026, 10, 4)),
      ]);
      expect([for (final t in open) t.id], [3, 1]);
      expect([for (final t in done) t.id], [4, 2]);
    });
  });

  testWidgets('M-50 Staff: không có mục Yêu cầu hỗ trợ', (tester) async {
    await loginAs(tester, 'staff@demo.vn', tallView: true);
    await tester.tap(find.byKey(const Key('nav_more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu_support')), findsNothing);
  });

  testWidgets('T-50: tab có số đếm, hàng ticket tĩnh, ghi người trả lời', (
    tester,
  ) async {
    await _openSupport(tester);

    expect(find.byType(SupportScreen), findsOneWidget);
    expect(find.byType(SoMockBanner), findsOneWidget);
    expect(_segmentLabels(tester), ['Chưa xong · 3', 'Đã giải quyết · 2']);
    expect(find.text('SUP-1042'), findsOneWidget);
    expect(find.text('Mở'), findsOneWidget);
    expect(find.text('Đang xử lý'), findsNWidgets(2));
    expect(_replyText(tester, 1042), 'Chưa có trả lời');
    expect(_replyText(tester, 1041), startsWith('Hỗ trợ: '));
    expect(_replyText(tester, 1039), startsWith('Bạn: '));
    // Không có màn chi tiết: hàng không bấm được, không mũi tên.
    expect(
      find.descendant(
        of: find.byKey(const Key('ticket_1041')),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );

    await tester.tap(find.text('Đã giải quyết · 2'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ticket_1038')), findsOneWidget);
    expect(find.byKey(const Key('ticket_1042')), findsNothing);
  });

  testWidgets('T-50: tạo yêu cầu từ tab Đã giải quyết -> về Chưa xong, ở đầu', (
    tester,
  ) async {
    await _openSupport(tester);
    await tester.tap(find.text('Đã giải quyết · 2'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ticket_create')));
    await tester.pumpAndSettle();
    await _fillTicket(tester, '', '');
    expect(find.text('Tiêu đề không được để trống'), findsOneWidget);
    expect(find.text('Mô tả không được để trống'), findsOneWidget);

    await _fillTicket(tester, 'Không in được vận đơn', 'Bấm In thì báo lỗi.');
    expect(find.byType(SoBottomSheet), findsNothing);
    expect(find.text('Đã gửi yêu cầu SUP-1043'), findsOneWidget);
    expect(_segmentLabels(tester), ['Chưa xong · 4', 'Đã giải quyết · 2']);
    expect(_replyText(tester, 1043), 'Chưa có trả lời');
    expect(
      tester.getTopLeft(find.byKey(const Key('ticket_1043'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('ticket_1042'))).dy),
    );
  });

  testWidgets('T-50: tiêu đề dừng ở 120 ký tự', (tester) async {
    await _openSupport(tester);
    await tester.tap(find.byKey(const Key('ticket_create')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ticket_title')), 'a' * 150);
    await tester.pump();
    expect(find.text('a' * 120), findsOneWidget);
  });

  testWidgets('T-50: gửi lỗi -> banner trong sheet, giữ chữ đã nhập', (
    tester,
  ) async {
    await _openSupport(tester, repo: _FakeSupport(failCreate: true));
    await tester.tap(find.byKey(const Key('ticket_create')));
    await tester.pumpAndSettle();
    await _fillTicket(tester, 'Tiêu đề', 'Mô tả');

    expect(find.byKey(const Key('ticket_submit_error')), findsOneWidget);
    expect(find.text('Tiêu đề'), findsWidgets);
    expect(find.text('Mô tả'), findsWidgets);
    expect(find.byType(SoBottomSheet), findsOneWidget);
  });

  testWidgets('T-50: lỗi tải -> Thử lại; tab rỗng', (tester) async {
    final repo = _FakeSupport(
      failList: true,
      tickets: [_t(1, TicketStatus.resolved, _now)],
    );
    await _openSupport(tester, repo: repo);
    expect(find.byKey(const Key('ticket_error')), findsOneWidget);

    await tapVisible(tester, find.text('Thử lại'));
    expect(repo.listCalls, 2);
    expect(_segmentLabels(tester), ['Chưa xong · 0', 'Đã giải quyết · 1']);
    expect(find.text('Không có yêu cầu nào đang chờ'), findsOneWidget);
  });

  testWidgets('T-50 vừa bề rộng 360dp', (tester) async {
    await _openSupport(tester);
    tester.view.physicalSize = const Size(360, 740);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
