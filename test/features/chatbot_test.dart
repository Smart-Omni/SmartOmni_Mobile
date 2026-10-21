import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/features/chatbot/domain/chatbot.dart';
import 'package:smartomni_mobile/features/chatbot/presentation/chatbot_screen.dart';
import 'package:smartomni_mobile/features/storefront/presentation/storefront_screens.dart';

import '../helpers/test_app.dart';

/// Trợ lý luôn lỗi, để thử câu trả lời dự phòng khi gọi lỗi.
class _FailingChatbot implements ChatbotRepository {
  @override
  Future<ChatReply> ask(int tenantId, String question) async =>
      throw Exception('mất mạng');
}

Future<void> _openChat(WidgetTester tester, {bool fail = false}) async {
  await loginAs(
    tester,
    'customer@demo.vn',
    tallView: true,
    overrides: [
      if (fail) chatbotRepositoryProvider.overrideWithValue(_FailingChatbot()),
    ],
  );
  await tester.tap(find.byKey(const Key('ask_ai')));
  await tester.pumpAndSettle();
}

Future<void> _ask(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('composer_input')), text);
  await tester.pump();
  await tester.tap(find.byKey(const Key('composer_send')));
  await tester.pumpAndSettle();
}

SoChatBubble _bubble(WidgetTester tester, String key) =>
    tester.widget<SoChatBubble>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(SoChatBubble),
      ),
    );

void main() {
  test('isOrderIntent: nhận ra muốn đặt / mua, có dấu hay không', () {
    expect(isOrderIntent('Mình muốn đặt hàng'), isTrue);
    expect(isOrderIntent('MUA 2 cái được không'), isTrue);
    expect(isOrderIntent('thanh toan the nao'), isTrue);
    expect(isOrderIntent('Áo thun còn size L không?'), isFalse);
    // "mua" phải là một từ riêng, không phải một phần từ khác.
    expect(isOrderIntent('mùa hè mặc gì'), isFalse);
    expect(isOrderIntent('mua o dau vay shop'), isTrue);
  });

  testWidgets('C-12: AppBar, nhãn AI, câu chào, không có câu hỏi gợi ý', (
    tester,
  ) async {
    await _openChat(tester);

    expect(find.byType(ChatbotScreen), findsOneWidget);
    expect(find.text('Trợ lý Shop Demo'), findsOneWidget);
    expect(find.text('Tư vấn sản phẩm · không đặt hàng'), findsOneWidget);
    expect(find.byType(SoAiLabel), findsOneWidget);
    expect(find.byType(SoMockBanner), findsOneWidget);
    expect(find.byKey(const Key('chat_greeting')), findsOneWidget);
    expect(find.byType(SoFilterChip), findsNothing);
    expect(find.byKey(const Key('composer_photo')), findsNothing);
  });

  testWidgets('hỏi sản phẩm: trả lời kèm thẻ, chạm thẻ mở C-11', (
    tester,
  ) async {
    await _openChat(tester);
    await _ask(tester, 'Áo thun có màu gì?');

    expect(find.text('Áo thun có màu gì?'), findsOneWidget);
    expect(_bubble(tester, 'chat_reply_1').tone, SoChatTone.normal);
    expect(find.byKey(const Key('chat_product_1')), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('chat_product_1')));
    expect(find.byType(StorefrontProductScreen), findsOneWidget);
  });

  testWidgets('không trả lời được / gọi lỗi: câu dự phòng nền warningTint', (
    tester,
  ) async {
    await _openChat(tester);
    await _ask(tester, 'Shop mở cửa mấy giờ?');
    expect(_bubble(tester, 'chat_reply_1').tone, SoChatTone.fallback);
    expect(find.textContaining('Mình chưa trả lời được'), findsOneWidget);
  });

  testWidgets('gọi lỗi: câu dự phòng "Trợ lý đang bận"', (tester) async {
    await _openChat(tester, fail: true);
    await _ask(tester, 'Áo thun còn không?');
    expect(_bubble(tester, 'chat_reply_1').tone, SoChatTone.fallback);
    expect(find.text('Trợ lý đang bận, bạn thử lại sau nhé.'), findsOneWidget);
  });

  testWidgets('hỏi đặt hàng: nhắc mua trên sàn', (tester) async {
    await _openChat(tester);
    await _ask(tester, 'Mình muốn đặt hàng áo thun');
    expect(find.textContaining('Mình không đặt hàng được'), findsOneWidget);
    expect(find.byKey(const Key('chat_product_1')), findsOneWidget);
  });

  testWidgets('C-12 vừa bề rộng 360dp', (tester) async {
    useNarrowPhone(tester);
    await loginAs(tester, 'customer@demo.vn');
    await tester.tap(find.byKey(const Key('ask_ai')));
    await tester.pumpAndSettle();
    await _ask(tester, 'Áo thun có màu gì?');
    expect(tester.takeException(), isNull);
  });
}
