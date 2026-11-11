import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/utils/clock.dart';
import '../../orders/data/orders_repositories.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/orders_providers.dart';
import '../data/inbox_mock_repository.dart';
import '../domain/inbox.dart';

/// Chỉ có Mock: backend chưa có API tin nhắn sàn.
final inboxRepositoryProvider = Provider<InboxRepository>(
  (ref) => InboxMockRepository(clock: ref.watch(clockProvider)),
);

/// Đơn cho Hộp thư. Hội thoại mẫu trỏ tới id đơn mẫu, nên khi M-20 đã gọi
/// BE thật thì Hộp thư (còn mock) dùng riêng đơn mẫu. Chế độ mock: dùng chung
/// đơn với M-20 như cũ (đổi trạng thái ở M-21 thì thẻ đơn thấy ngay).
final inboxOrdersProvider = FutureProvider.autoDispose<PageResult<Order>>(
  (ref) => ref.watch(ordersUseRemoteProvider)
      ? OrdersMockRepository(clock: ref.watch(clockProvider)).fetchOrders()
      : ref.watch(ordersPageProvider.future),
);

final conversationsProvider = FutureProvider.autoDispose<List<Conversation>>(
  (ref) => ref.watch(inboxRepositoryProvider).listConversations(),
);

/// Số hội thoại chưa đọc (hàng "Hộp thư CSKH" trên M-50), `null` khi đang
/// tải hoặc lỗi.
final inboxUnreadCountProvider = Provider.autoDispose<int?>(
  (ref) => ref
      .watch(conversationsProvider)
      .whenOrNull(data: (list) => list.where((c) => c.unread).length),
);

final conversationProvider = FutureProvider.autoDispose
    .family<Conversation, int>(
      (ref, id) => ref.watch(inboxRepositoryProvider).getConversation(id),
    );

final messagesProvider = FutureProvider.autoDispose.family<List<Message>, int>(
  (ref, id) => ref.watch(inboxRepositoryProvider).listMessages(id),
);
