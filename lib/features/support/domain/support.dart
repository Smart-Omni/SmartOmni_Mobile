/// Yêu cầu hỗ trợ của cửa hàng gửi đội SmartOmni (T-50). Bảng
/// `support_tickets` đã có, Nginx đã route `/api/support-tickets/`, nhưng
/// chưa có API trong hợp đồng.
library;

enum TicketStatus {
  open('Mở'),
  inProgress('Đang xử lý'),
  resolved('Đã giải quyết');

  const TicketStatus(this.label);

  final String label;

  bool get isDone => this == TicketStatus.resolved;
}

enum ReplyAuthor { support, me }

class TicketReply {
  const TicketReply(this.author, this.text);

  final ReplyAuthor author;
  final String text;
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.code,
    required this.title,
    required this.status,
    required this.updatedAt,
    this.lastReply,
  });

  final int id;

  /// Mã hiển thị, vd. "SUP-1043".
  final String code;
  final String title;
  final TicketStatus status;

  /// Lần cập nhật gần nhất (tạo hoặc trả lời).
  final DateTime updatedAt;

  /// `null` = chưa có trả lời.
  final TicketReply? lastReply;
}

/// ⚠️ Chưa có API trong docs/API_CONTRACT.md -> mock.
abstract interface class SupportRepository {
  Future<List<SupportTicket>> list();

  /// Tạo ticket mới (trạng thái Mở, chưa có trả lời).
  Future<SupportTicket> create({
    required String title,
    required String description,
  });
}

const ticketTitleMax = 120;
const ticketDescriptionMax = 2000;

String? validateTicketTitle(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Tiêu đề không được để trống';
  if (t.length > ticketTitleMax) {
    return 'Tiêu đề tối đa $ticketTitleMax ký tự';
  }
  return null;
}

String? validateTicketDescription(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Mô tả không được để trống';
  if (t.length > ticketDescriptionMax) {
    return 'Mô tả tối đa $ticketDescriptionMax ký tự';
  }
  return null;
}

/// Tách theo tab: (chưa xong, đã giải quyết), mỗi nhóm mới cập nhật trước.
(List<SupportTicket>, List<SupportTicket>) splitTickets(
  Iterable<SupportTicket> tickets,
) {
  final sorted = [...tickets]
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return (
    [
      for (final t in sorted)
        if (!t.status.isDone) t,
    ],
    [
      for (final t in sorted)
        if (t.status.isDone) t,
    ],
  );
}
