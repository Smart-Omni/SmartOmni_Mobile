import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/models/platform.dart';
import 'package:smartomni_mobile/core/utils/clock.dart';
import 'package:smartomni_mobile/features/inbox/domain/inbox.dart';
import 'package:smartomni_mobile/features/inbox/presentation/inbox_screen.dart';

import '../helpers/test_app.dart';

final _now = DateTime(2026, 10, 21, 14, 30);

Conversation _conv({
  ConversationKind kind = ConversationKind.normal,
  bool awaitingReply = false,
  bool resolved = false,
  Platform platform = Platform.shopee,
}) => Conversation(
  id: 1,
  platform: platform,
  customerName: 'Khách',
  lastMessage: 'Tin',
  lastMessageAt: _now,
  kind: kind,
  awaitingReply: awaitingReply,
  resolved: resolved,
);

Future<void> _openInbox(WidgetTester tester) async {
  await loginAs(
    tester,
    'staff@demo.vn',
    tallView: true,
    overrides: [clockProvider.overrideWithValue(() => _now)],
  );
  await tester.tap(find.byKey(const Key('nav_more')));
  await tester.pumpAndSettle();
  // M-50: số hội thoại chưa đọc cạnh "Hộp thư CSKH".
  expect(
    tester.widget<Text>(find.byKey(const Key('menu_inbox_unread'))).data,
    '2',
  );
  await tapVisible(tester, find.byKey(const Key('menu_inbox')));
}

void main() {
  group('inboxTagOf: một nhãn theo ưu tiên', () {
    test('Đã giải quyết thắng mọi nhãn', () {
      expect(
        inboxTagOf(
          _conv(
            kind: ConversationKind.complaint,
            awaitingReply: true,
            resolved: true,
          ),
        ),
        InboxTag.resolved,
      );
    });

    test('Khiếu nại chưa trả lời vẫn là Khiếu nại', () {
      expect(
        inboxTagOf(
          _conv(kind: ConversationKind.complaint, awaitingReply: true),
        ),
        InboxTag.complaint,
      );
    });

    test('Cần kiểm tra trước Chưa trả lời', () {
      expect(
        inboxTagOf(
          _conv(kind: ConversationKind.needsReview, awaitingReply: true),
        ),
        InboxTag.needsReview,
      );
      expect(inboxTagOf(_conv(awaitingReply: true)), InboxTag.awaitingReply);
    });

    test('bình thường đã trả lời: không nhãn', () {
      expect(inboxTagOf(_conv()), isNull);
    });
  });

  test('InboxFilter: Chưa trả lời bỏ hội thoại đã giải quyết', () {
    expect(
      InboxFilter.awaitingReply.matches(
        _conv(kind: ConversationKind.complaint, awaitingReply: true),
      ),
      isTrue,
    );
    expect(
      InboxFilter.awaitingReply.matches(
        _conv(awaitingReply: true, resolved: true),
      ),
      isFalse,
    );
    expect(
      InboxFilter.complaint.matches(
        _conv(kind: ConversationKind.complaint, resolved: true),
      ),
      isTrue,
    );
    expect(
      InboxFilter.tiktokShop.matches(_conv(platform: Platform.tiktokShop)),
      isTrue,
    );
    expect(
      InboxFilter.shopee.matches(_conv(platform: Platform.tiktokShop)),
      isFalse,
    );
  });

  test('inboxTimeLabel: hôm nay giờ, hôm qua, cũ hơn ngày/tháng', () {
    expect(inboxTimeLabel(DateTime(2026, 10, 21, 9, 5), now: _now), '09:05');
    expect(
      inboxTimeLabel(DateTime(2026, 10, 20, 23, 59), now: _now),
      'Hôm qua',
    );
    expect(inboxTimeLabel(DateTime(2026, 10, 3, 8), now: _now), '03/10');
  });

  testWidgets('M-50 hiện số chưa đọc, mở M-60 có dữ liệu mẫu', (tester) async {
    await _openInbox(tester);

    expect(find.byType(InboxScreen), findsOneWidget);
    expect(find.byType(SoMockBanner), findsOneWidget);
    expect(find.text('Nguyễn Thị Lan'), findsOneWidget);
    expect(find.byKey(const Key('unread_dot')), findsNWidgets(2));
    expect(
      tester
          .widget<SoStatusTag>(find.byKey(const Key('conversation_tag_1')))
          .label,
      'Khiếu nại',
    );
    expect(find.byKey(const Key('conversation_tag_4')), findsNothing);
  });

  testWidgets('chip lọc Khiếu nại / Chưa trả lời / sàn', (tester) async {
    await _openInbox(tester);
    // Hàng chip cuộn ngang: cuộn chip vào khung rồi mới chạm.
    Future<void> tapChip(String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    await tapChip('inbox_filter_complaint');
    expect(find.byKey(const Key('conversation_1')), findsOneWidget);
    expect(find.byKey(const Key('conversation_2')), findsNothing);

    await tapChip('inbox_filter_awaitingReply');
    expect(find.byKey(const Key('conversation_2')), findsOneWidget);
    expect(find.byKey(const Key('conversation_6')), findsNothing);

    await tapChip('inbox_filter_tiktokShop');
    expect(find.byKey(const Key('conversation_1')), findsNothing);
    expect(find.byKey(const Key('conversation_5')), findsOneWidget);
  });

  testWidgets('M-60 vừa bề rộng 360dp', (tester) async {
    useNarrowPhone(tester);
    await loginAs(tester, 'staff@demo.vn');
    await tester.tap(find.byKey(const Key('nav_more')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('menu_inbox')));
    expect(tester.takeException(), isNull);
  });
}
