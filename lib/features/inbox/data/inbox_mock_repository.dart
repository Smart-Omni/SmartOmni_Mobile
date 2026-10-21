import '../../../core/models/platform.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/inbox.dart';

/// Hộp thư mẫu: backend chưa có API tin nhắn sàn (docs/API_CONTRACT.md).
class InboxMockRepository implements InboxRepository {
  InboxMockRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    final now = _clock();
    DateTime ago(Duration d) => now.subtract(d);
    _conversations.addAll([
      Conversation(
        id: 1,
        platform: Platform.shopee,
        customerName: 'Nguyễn Thị Lan',
        lastMessage: 'Shop ơi áo bị rách ở tay, mình muốn đổi cái khác.',
        lastMessageAt: ago(const Duration(minutes: 8)),
        kind: ConversationKind.complaint,
        unread: true,
        awaitingReply: true,
      ),
      Conversation(
        id: 2,
        platform: Platform.tiktokShop,
        customerName: 'Trần Minh Khoa',
        lastMessage: 'Size L còn màu đen không shop?',
        lastMessageAt: ago(const Duration(minutes: 25)),
        unread: true,
        awaitingReply: true,
      ),
      Conversation(
        id: 3,
        platform: Platform.shopee,
        customerName: 'Lê Hoàng Yến',
        lastMessage: 'Mình chuyển khoản rồi mà đơn vẫn chưa xác nhận.',
        lastMessageAt: ago(const Duration(hours: 1, minutes: 10)),
        kind: ConversationKind.needsReview,
        awaitingReply: true,
      ),
      Conversation(
        id: 4,
        platform: Platform.tiktokShop,
        customerName: 'Phạm Quốc Bảo',
        lastMessage: 'Dạ shop đã gửi lại mã vận đơn cho anh rồi ạ.',
        lastMessageAt: ago(const Duration(hours: 3)),
      ),
      Conversation(
        id: 5,
        platform: Platform.tiktokShop,
        customerName: 'Võ Thanh Hà',
        lastMessage: 'Giao sai màu, mình đặt màu be mà nhận màu trắng.',
        lastMessageAt: ago(const Duration(days: 1, hours: 2)),
        kind: ConversationKind.complaint,
        awaitingReply: true,
      ),
      Conversation(
        id: 6,
        platform: Platform.shopee,
        customerName: 'Đặng Gia Huy',
        lastMessage: 'Cảm ơn shop, mình nhận được hàng rồi.',
        lastMessageAt: ago(const Duration(days: 1, hours: 5)),
        kind: ConversationKind.complaint,
        resolved: true,
      ),
      Conversation(
        id: 7,
        platform: Platform.shopee,
        customerName: 'Bùi Ngọc Mai',
        lastMessage: 'Dạ sản phẩm này giặt máy được ạ.',
        lastMessageAt: ago(const Duration(days: 3)),
        resolved: true,
      ),
    ]);
  }

  final DateTime Function() _clock;
  final List<Conversation> _conversations = [];

  @override
  Future<List<Conversation>> listConversations() async {
    await MockDelay.short();
    return [..._conversations]
      ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
  }
}
