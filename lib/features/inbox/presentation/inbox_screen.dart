import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/clock.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/inbox.dart';
import 'inbox_providers.dart';

/// M-60 Hộp thư CSKH (DESIGN.md mục 8b): màn con từ M-50, lọc theo chip,
/// mỗi hàng một hội thoại. Chạy bằng dữ liệu mẫu.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  InboxFilter _filter = InboxFilter.all;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(conversationsProvider);
    final all = async.value ?? const <Conversation>[];

    return SoScaffold(
      onRefresh: async.hasValue
          ? () async {
              ref.invalidate(conversationsProvider);
              await ref.read(conversationsProvider.future);
            }
          : null,
      scrollable: !async.isLoading || async.hasValue,
      appBar: SoAppBar(
        title: 'Hộp thư CSKH',
        bottom: SoChipBar(
          chips: [
            for (final f in InboxFilter.values)
              SoFilterChip(
                key: Key('inbox_filter_${f.name}'),
                label: f.label,
                count: all.where(f.matches).length,
                selected: _filter == f,
                onSelected: () => setState(() => _filter = f),
              ),
          ],
        ),
      ),
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: switch (async) {
            AsyncData(:final value) => SliverList.list(
              children: [
                const SoMockBanner(
                  message: 'Tin nhắn là dữ liệu mẫu, backend chưa có API.',
                ),
                const SizedBox(height: SoSpace.s16),
                _ConversationList(
                  items: value.where(_filter.matches).toList(),
                  hasAny: value.isNotEmpty,
                  now: ref.watch(clockProvider)(),
                ),
              ],
            ),
            AsyncError(:final error) => SliverToBoxAdapter(
              child: SoEmptyState.error(
                title: 'Không tải được hộp thư',
                message: AsyncValueView.errorMessage(error),
                onAction: () => ref.invalidate(conversationsProvider),
              ),
            ),
            _ => const SliverToBoxAdapter(
              child: SoListGroup(children: [SoSkeletonList(count: 6)]),
            ),
          },
        ),
      ],
    );
  }
}

extension InboxFilterLabel on InboxFilter {
  String get label => switch (this) {
    InboxFilter.all => 'Tất cả',
    InboxFilter.complaint => 'Khiếu nại',
    InboxFilter.awaitingReply => 'Chưa trả lời',
    InboxFilter.shopee => 'Shopee',
    InboxFilter.tiktokShop => 'TikTok Shop',
  };
}

extension InboxTagUi on InboxTag {
  (String, SoStatus) get tag => switch (this) {
    InboxTag.resolved => ('Đã giải quyết', SoStatus.success),
    InboxTag.complaint => ('Khiếu nại', SoStatus.danger),
    InboxTag.needsReview => ('Cần kiểm tra', SoStatus.warning),
    InboxTag.awaitingReply => ('Chưa trả lời', SoStatus.neutral),
  };
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.items,
    required this.hasAny,
    required this.now,
  });

  final List<Conversation> items;
  final bool hasAny;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return hasAny
          ? const SoEmptyState(
              icon: LucideIcons.searchX,
              title: 'Không có hội thoại phù hợp',
              message: 'Thử chọn bộ lọc khác.',
            )
          : const SoEmptyState(
              icon: LucideIcons.messagesSquare,
              title: 'Chưa có tin nhắn nào',
              message:
                  'Tin nhắn của khách trên Shopee và TikTok Shop sẽ hiện '
                  'ở đây.',
            );
    }
    return Container(
      key: const Key('inbox_list'),
      clipBehavior: Clip.antiAlias,
      decoration: SoShape.card(context.soColors),
      child: Column(
        children: [
          for (final (i, c) in items.indexed) ...[
            if (i > 0) const Divider(indent: SoSpace.s16),
            _ConversationRow(
              key: Key('conversation_${c.id}'),
              conversation: c,
              now: now,
              onTap: () => context.push(Routes.merchantConversation(c.id)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hàng hội thoại: [chấm chưa đọc · tên khách | giờ] · tin cuối (đậm nếu
/// chưa đọc) · [kênh | nhãn trạng thái].
class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    super.key,
    required this.conversation,
    required this.now,
    required this.onTap,
  });

  final Conversation conversation;
  final DateTime now;
  final VoidCallback onTap;

  static const double _dot = 8;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final conv = conversation;
    final tag = inboxTagOf(conv)?.tag;
    // Hàng đã đọc vẫn chừa chỗ chấm để tên các hàng thẳng cột.
    const indent = _dot + SoSpace.s8;
    return Material(
      color: c.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: SoSpace.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: indent,
                    child: conv.unread
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: DecoratedBox(
                              key: const Key('unread_dot'),
                              decoration: BoxDecoration(
                                color: c.brand,
                                shape: BoxShape.circle,
                              ),
                              child: const SizedBox.square(dimension: _dot),
                            ),
                          )
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      conv.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: SoSpace.s12),
                  Text(
                    inboxTimeLabel(conv.lastMessageAt, now: now),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: c.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SoSpace.s4),
              Padding(
                padding: const EdgeInsets.only(left: indent),
                child: Text(
                  conv.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: conv.unread ? c.ink : c.ink2,
                    fontWeight: conv.unread ? FontWeight.w600 : null,
                  ),
                ),
              ),
              const SizedBox(height: SoSpace.s8),
              Padding(
                padding: const EdgeInsets.only(left: indent),
                child: Row(
                  children: [
                    Expanded(child: SoChannelTag(platform: conv.platform)),
                    if (tag != null)
                      SoStatusTag(
                        key: Key('conversation_tag_${conv.id}'),
                        label: tag.$1,
                        status: tag.$2,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
