import '../../../core/models/platform.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/mock_delay.dart';
import '../../orders/domain/order.dart';
import '../domain/inbox.dart';

/// Hộp thư mẫu: backend chưa có API tin nhắn sàn (docs/API_CONTRACT.md).
/// Hội thoại có đơn liên quan dùng id và tên khách của đơn mẫu
/// (`MockData.ordersAt`).
class InboxMockRepository implements InboxRepository {
  InboxMockRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    final now = _clock();
    DateTime ago(Duration d) => now.subtract(d);

    void add(Conversation c, List<Message> history) {
      _conversations[c.id] = c;
      _messages[c.id] = history;
    }

    Message customer(String text, Duration before) => Message(
      id: _nextId++,
      fromCustomer: true,
      text: text,
      sentAt: ago(before),
    );
    Message shop(
      String text,
      Duration before, {
      String? by = 'Lan',
      MessageStatus status = MessageStatus.sent,
    }) => Message(
      id: _nextId++,
      fromCustomer: false,
      text: text,
      senderName: by,
      sentAt: ago(before),
      status: status,
    );

    add(
      Conversation(
        id: 1,
        platform: Platform.shopee,
        customerName: 'Nguyễn Văn A',
        lastMessage: 'Shop ơi áo bị rách ở tay, mình muốn đổi cái khác.',
        lastMessageAt: ago(const Duration(minutes: 8)),
        kind: ConversationKind.complaint,
        unread: true,
        awaitingReply: true,
        orderId: 1001,
        responseDueAt: now.add(const Duration(hours: 2)),
      ),
      [
        customer('Shop ơi mình nhận được hàng rồi.', const Duration(hours: 1)),
        shop(
          'Dạ shop cảm ơn anh, anh dùng có vừa không ạ?',
          const Duration(minutes: 50),
          status: MessageStatus.unknown,
        ),
        Message(
          id: _nextId++,
          fromCustomer: true,
          sentAt: ago(const Duration(minutes: 10)),
        ),
        customer(
          'Shop ơi áo bị rách ở tay, mình muốn đổi cái khác.',
          const Duration(minutes: 8),
        ),
      ],
    );
    add(
      Conversation(
        id: 2,
        platform: Platform.tiktokShop,
        customerName: 'Trần Minh Khoa',
        lastMessage: 'Size L còn màu đen không shop?',
        lastMessageAt: ago(const Duration(minutes: 25)),
        unread: true,
        awaitingReply: true,
      ),
      [customer('Size L còn màu đen không shop?', const Duration(minutes: 25))],
    );
    add(
      Conversation(
        id: 3,
        platform: Platform.shopee,
        customerName: 'Lê C',
        lastMessage: 'Mình chuyển khoản rồi mà đơn vẫn chưa xác nhận.',
        lastMessageAt: ago(const Duration(hours: 1, minutes: 10)),
        kind: ConversationKind.needsReview,
        awaitingReply: true,
        orderId: 1003,
      ),
      [
        customer(
          'Mình chuyển khoản rồi mà đơn vẫn chưa xác nhận.',
          const Duration(hours: 1, minutes: 10),
        ),
      ],
    );
    add(
      Conversation(
        id: 4,
        platform: Platform.tiktokShop,
        customerName: 'Phạm Quốc Bảo',
        lastMessage: 'Dạ shop đã gửi lại mã vận đơn cho anh rồi ạ.',
        lastMessageAt: ago(const Duration(hours: 3)),
      ),
      [
        customer(
          'Shop gửi mình mã vận đơn với.',
          const Duration(hours: 3, minutes: 20),
        ),
        shop(
          'Dạ shop đã gửi lại mã vận đơn cho anh rồi ạ.',
          const Duration(hours: 3),
          by: 'Minh',
        ),
      ],
    );
    add(
      Conversation(
        id: 5,
        platform: Platform.tiktokShop,
        customerName: 'Võ Thị F',
        lastMessage: 'Giao sai màu, mình đặt màu be mà nhận màu trắng.',
        lastMessageAt: ago(const Duration(days: 1, hours: 2)),
        kind: ConversationKind.complaint,
        awaitingReply: true,
        orderId: 1006,
        responseDueAt: ago(const Duration(hours: 2)),
      ),
      [
        customer(
          'Giao sai màu, mình đặt màu be mà nhận màu trắng.',
          const Duration(days: 1, hours: 2),
        ),
      ],
    );
    add(
      Conversation(
        id: 6,
        platform: Platform.shopee,
        customerName: 'Đặng G',
        lastMessage: 'Cảm ơn shop, mình nhận được hàng rồi.',
        lastMessageAt: ago(const Duration(days: 1, hours: 5)),
        kind: ConversationKind.complaint,
        resolved: true,
        orderId: 1007,
      ),
      [
        customer(
          'Hàng giao chậm quá shop ơi.',
          const Duration(days: 2, hours: 1),
        ),
        shop(
          'Dạ shop xin lỗi, đơn đang được giao lại hôm nay ạ.',
          const Duration(days: 2),
        ),
        customer(
          'Cảm ơn shop, mình nhận được hàng rồi.',
          const Duration(days: 1, hours: 5),
        ),
      ],
    );
    add(
      Conversation(
        id: 7,
        platform: Platform.shopee,
        customerName: 'Bùi Ngọc Mai',
        lastMessage: 'Dạ sản phẩm này giặt máy được ạ.',
        lastMessageAt: ago(const Duration(days: 3)),
        resolved: true,
      ),
      [
        customer(
          'Áo này giặt máy được không shop?',
          const Duration(days: 3, minutes: 30),
        ),
        shop('Dạ sản phẩm này giặt máy được ạ.', const Duration(days: 3)),
      ],
    );
  }

  final DateTime Function() _clock;
  final Map<int, Conversation> _conversations = {};
  final Map<int, List<Message>> _messages = {};
  int _nextId = 1;

  Conversation _find(int id) =>
      _conversations[id] ??
      (throw const ApiException(
        type: ApiErrorType.notFound,
        message: 'Không tìm thấy hội thoại.',
      ));

  @override
  Future<List<Conversation>> listConversations() async {
    await MockDelay.short();
    return _conversations.values.toList()
      ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
  }

  @override
  Future<Conversation> getConversation(int id) async {
    await MockDelay.short();
    return _find(id);
  }

  @override
  Future<List<Message>> listMessages(int conversationId) async {
    await MockDelay.short();
    _find(conversationId);
    return List.unmodifiable(_messages[conversationId]!);
  }

  @override
  Future<void> markRead(int conversationId) async {
    final c = _find(conversationId);
    _conversations[c.id] = c.copyWith(unread: false);
  }

  @override
  Future<Message> sendMessage(int conversationId, String text) async {
    await MockDelay.short();
    final c = _find(conversationId);
    final m = Message(
      id: _nextId++,
      fromCustomer: false,
      text: text,
      sentAt: _clock(),
    );
    _messages[c.id] = [..._messages[c.id]!, m];
    _conversations[c.id] = c.copyWith(
      lastMessage: text,
      lastMessageAt: m.sentAt,
      awaitingReply: false,
    );
    return m;
  }

  @override
  Future<void> resolve(int conversationId) async {
    await MockDelay.short();
    final c = _find(conversationId);
    _conversations[c.id] = c.copyWith(resolved: true);
  }

  @override
  Future<void> attachOrder(int conversationId, Order order) async {
    await MockDelay.short();
    final c = _find(conversationId);
    if (!canAttachOrder(c, order)) {
      throw ApiException(
        type: ApiErrorType.validation,
        message: 'Chỉ gắn được đơn ${c.platform.label}.',
      );
    }
    _conversations[c.id] = c.copyWith(orderId: order.id);
  }
}
