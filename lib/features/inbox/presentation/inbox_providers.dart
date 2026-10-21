import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock.dart';
import '../data/inbox_mock_repository.dart';
import '../domain/inbox.dart';

/// Chỉ có Mock: backend chưa có API tin nhắn sàn.
final inboxRepositoryProvider = Provider<InboxRepository>(
  (ref) => InboxMockRepository(clock: ref.watch(clockProvider)),
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
