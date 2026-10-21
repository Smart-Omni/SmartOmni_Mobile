import '../../../core/models/platform.dart';

/// Nhãn AI gắn cho hội thoại (USER_FLOWS F-S6). AI chỉ gắn nhãn, không soạn
/// hay gửi tin thay.
enum ConversationKind { normal, complaint, needsReview }

/// Hội thoại CSKH với một khách trên một sàn (M-60).
class Conversation {
  const Conversation({
    required this.id,
    required this.platform,
    required this.customerName,
    required this.lastMessage,
    required this.lastMessageAt,
    this.kind = ConversationKind.normal,
    this.unread = false,
    this.awaitingReply = false,
    this.resolved = false,
  });

  final int id;
  final Platform platform;
  final String customerName;
  final String lastMessage;
  final DateTime lastMessageAt;
  final ConversationKind kind;

  /// Shop chưa mở tin mới nhất.
  final bool unread;

  /// Tin cuối là của khách, shop chưa trả lời.
  final bool awaitingReply;

  /// Đã đánh dấu "Đã giải quyết" (đóng phiên).
  final bool resolved;
}

abstract interface class InboxRepository {
  /// Mới nhất lên đầu.
  Future<List<Conversation>> listConversations();
}

/// Nhãn trạng thái trên hàng M-60. Mỗi hàng chỉ một nhãn.
enum InboxTag { resolved, complaint, needsReview, awaitingReply }

/// Ưu tiên: Đã giải quyết > Khiếu nại > Cần kiểm tra > Chưa trả lời.
/// Hội thoại bình thường đã trả lời: không nhãn.
InboxTag? inboxTagOf(Conversation c) {
  if (c.resolved) return InboxTag.resolved;
  if (c.kind == ConversationKind.complaint) return InboxTag.complaint;
  if (c.kind == ConversationKind.needsReview) return InboxTag.needsReview;
  if (c.awaitingReply) return InboxTag.awaitingReply;
  return null;
}

/// Chip lọc M-60: Tất cả / Khiếu nại / Chưa trả lời / theo sàn.
enum InboxFilter {
  all,
  complaint,
  awaitingReply,
  shopee,
  tiktokShop;

  bool matches(Conversation c) => switch (this) {
    all => true,
    complaint => c.kind == ConversationKind.complaint,
    awaitingReply => c.awaitingReply && !c.resolved,
    shopee => c.platform == Platform.shopee,
    tiktokShop => c.platform == Platform.tiktokShop,
  };
}

/// Giờ trên hàng: hôm nay "HH:mm", hôm qua "Hôm qua", cũ hơn "dd/MM".
String inboxTimeLabel(DateTime at, {required DateTime now}) {
  final day = DateTime(at.year, at.month, at.day);
  final diff = DateTime(now.year, now.month, now.day).difference(day).inDays;
  String two(int v) => v.toString().padLeft(2, '0');
  if (diff == 0) return '${two(at.hour)}:${two(at.minute)}';
  if (diff == 1) return 'Hôm qua';
  return '${two(at.day)}/${two(at.month)}';
}
