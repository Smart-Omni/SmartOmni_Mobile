import '../../../core/utils/mock_delay.dart';
import '../domain/support.dart';

/// 5 ticket mẫu: 1 Mở chưa trả lời, 2 Đang xử lý (hỗ trợ / bạn trả lời cuối),
/// 2 Đã giải quyết. Ticket tạo trong phiên chạy app giữ trong bộ nhớ.
class SupportMockRepository implements SupportRepository {
  SupportMockRepository({required DateTime Function() clock}) : _clock = clock {
    final now = _clock();
    _tickets.addAll([
      SupportTicket(
        id: 1042,
        code: 'SUP-1042',
        title: 'Đơn TikTok Shop không về app từ sáng nay',
        status: TicketStatus.open,
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
      SupportTicket(
        id: 1041,
        code: 'SUP-1041',
        title: 'Tồn kho Shopee lệch 3 cái với app',
        status: TicketStatus.inProgress,
        updatedAt: now.subtract(const Duration(hours: 5)),
        lastReply: const TicketReply(
          ReplyAuthor.support,
          'Bên mình đã kiểm tra, đang đồng bộ lại tồn kho cho SKU này.',
        ),
      ),
      SupportTicket(
        id: 1039,
        code: 'SUP-1039',
        title: 'Không nhận được email đặt lại mật khẩu cho nhân viên',
        status: TicketStatus.inProgress,
        updatedAt: now.subtract(const Duration(days: 1, hours: 2)),
        lastReply: const TicketReply(
          ReplyAuthor.me,
          'Mình đã kiểm tra cả hộp thư rác nhưng vẫn chưa thấy.',
        ),
      ),
      SupportTicket(
        id: 1038,
        code: 'SUP-1038',
        title: 'Hỏi cách kết nối shop TikTok Shop thứ hai',
        status: TicketStatus.resolved,
        updatedAt: now.subtract(const Duration(days: 3)),
        lastReply: const TicketReply(
          ReplyAuthor.support,
          'Hiện mỗi cửa hàng kết nối một shop trên mỗi sàn. Bên mình đóng yêu '
          'cầu nhé.',
        ),
      ),
      SupportTicket(
        id: 1035,
        code: 'SUP-1035',
        title: 'Hóa đơn tháng 9 bị tính hai lần',
        status: TicketStatus.resolved,
        updatedAt: now.subtract(const Duration(days: 12)),
        lastReply: const TicketReply(
          ReplyAuthor.support,
          'Đã hoàn lại khoản tính trùng vào tài khoản của bạn.',
        ),
      ),
    ]);
  }

  final DateTime Function() _clock;
  final _tickets = <SupportTicket>[];

  @override
  Future<List<SupportTicket>> list() async {
    await MockDelay.short();
    return List.unmodifiable(_tickets);
  }

  @override
  Future<SupportTicket> create({
    required String title,
    required String description,
  }) async {
    await MockDelay.short();
    final id = _tickets.fold(0, (max, t) => t.id > max ? t.id : max) + 1;
    final ticket = SupportTicket(
      id: id,
      code: 'SUP-$id',
      title: title.trim(),
      status: TicketStatus.open,
      updatedAt: _clock(),
    );
    _tickets.add(ticket);
    return ticket;
  }
}
