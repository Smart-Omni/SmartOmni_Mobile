import '../../../core/models/platform.dart';

/// Nhãn AI gắn cho hội thoại (USER_FLOWS F-S6). AI chỉ gắn nhãn, không soạn
/// hay gửi tin thay.
enum ConversationKind { normal, complaint, needsReview }

/// Hội thoại CSKH với một khách trên một sàn (M-60, M-61).
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
    this.orderId,
    this.responseDueAt,
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

  /// Đơn liên quan (cùng sàn + shop), `null` khi chưa gắn.
  final int? orderId;

  /// Hạn phản hồi khiếu nại do sàn đặt.
  final DateTime? responseDueAt;

  /// Đang hiện banner hạn phản hồi (M-61 bản khiếu nại).
  bool get showsDeadline =>
      kind == ConversationKind.complaint && !resolved && responseDueAt != null;

  Conversation copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    bool? unread,
    bool? awaitingReply,
    bool? resolved,
  }) => Conversation(
    id: id,
    platform: platform,
    customerName: customerName,
    lastMessage: lastMessage ?? this.lastMessage,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    kind: kind,
    unread: unread ?? this.unread,
    awaitingReply: awaitingReply ?? this.awaitingReply,
    resolved: resolved ?? this.resolved,
    orderId: orderId,
    responseDueAt: responseDueAt,
  );
}

/// Trạng thái tin shop gửi (F-S6): đang gửi → đã gửi, hoặc lỗi / quá 15 giây
/// → chưa rõ (đối soát trước khi gửi lại).
enum MessageStatus { sending, sent, unknown }

/// Một tin trong hội thoại.
class Message {
  const Message({
    required this.id,
    required this.fromCustomer,
    required this.sentAt,
    this.text,
    this.senderName,
    this.status = MessageStatus.sent,
  });

  final int id;
  final bool fromCustomer;
  final DateTime sentAt;

  /// `null`: loại nội dung sàn không hỗ trợ (video, sticker…).
  final String? text;

  /// Tin của shop: người gửi; `null` là người đang dùng app ("Bạn").
  final String? senderName;
  final MessageStatus status;

  Message copyWith({MessageStatus? status}) => Message(
    id: id,
    fromCustomer: fromCustomer,
    sentAt: sentAt,
    text: text,
    senderName: senderName,
    status: status ?? this.status,
  );
}

abstract interface class InboxRepository {
  /// Mới nhất lên đầu.
  Future<List<Conversation>> listConversations();

  Future<Conversation> getConversation(int id);

  /// Cũ nhất lên đầu.
  Future<List<Message>> listMessages(int conversationId);

  Future<void> markRead(int conversationId);

  /// Gửi tin của người đang dùng app. Trả về tin đã được sàn xác nhận.
  Future<Message> sendMessage(int conversationId, String text);

  /// Đánh dấu "Đã giải quyết" (đóng phiên).
  Future<void> resolve(int conversationId);
}

/// Quá thời gian này mà sàn chưa xác nhận thì coi là "chưa rõ".
const sendTimeout = Duration(seconds: 15);

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

String _two(int v) => v.toString().padLeft(2, '0');

int _daysBetween(DateTime from, DateTime to) => DateTime(
  to.year,
  to.month,
  to.day,
).difference(DateTime(from.year, from.month, from.day)).inDays;

/// Giờ trên hàng: hôm nay "HH:mm", hôm qua "Hôm qua", cũ hơn "dd/MM".
String inboxTimeLabel(DateTime at, {required DateTime now}) {
  final diff = _daysBetween(at, now);
  if (diff == 0) return '${_two(at.hour)}:${_two(at.minute)}';
  if (diff == 1) return 'Hôm qua';
  return '${_two(at.day)}/${_two(at.month)}';
}

/// Tiêu đề banner hạn phản hồi khiếu nại (M-61).
String responseDueLabel(DateTime due, {required DateTime now}) {
  final hm = '${_two(due.hour)}:${_two(due.minute)}';
  if (!due.isAfter(now)) return 'Khiếu nại · đã quá hạn phản hồi ($hm)';
  final when = _daysBetween(now, due) == 0
      ? hm
      : '$hm ${_two(due.day)}/${_two(due.month)}';
  return 'Khiếu nại · phản hồi trước $when';
}
