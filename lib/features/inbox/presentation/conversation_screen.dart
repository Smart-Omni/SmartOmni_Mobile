import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_ui.dart';
import '../../orders/presentation/orders_providers.dart';
import '../domain/inbox.dart';
import 'attach_order_sheet.dart';
import 'inbox_providers.dart';

/// M-61 Hội thoại (DESIGN.md mục 8b), bản khiếu nại và bản thường: banner
/// hạn phản hồi (khiếu nại), thẻ đơn liên quan, tin nhắn, ô soạn kính.
/// Không có trả lời nhanh; AI không soạn hay gửi thay.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});

  final int conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _scroll = ScrollController();
  final _input = TextEditingController();

  /// Tin vừa gửi chưa được sàn xác nhận: đang gửi, hoặc chưa rõ (lỗi / quá
  /// [sendTimeout]).
  final List<Message> _pending = [];
  int _localId = -1;
  bool _resolving = false;

  int get _id => widget.conversationId;
  bool get _sending => _pending.any((m) => m.status == MessageStatus.sending);

  @override
  void initState() {
    super.initState();
    unawaited(_markRead());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    try {
      await ref.read(inboxRepositoryProvider).markRead(_id);
      ref.invalidate(conversationsProvider);
    } catch (_) {
      // Không đánh dấu được thì để lần mở sau; màn vẫn tự báo lỗi tải.
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final draft = Message(
      id: _localId--,
      fromCustomer: false,
      text: text,
      sentAt: ref.read(clockProvider)(),
      status: MessageStatus.sending,
    );
    setState(() {
      _pending.add(draft);
      _input.clear();
    });
    _scrollToEnd();
    try {
      await ref
          .read(inboxRepositoryProvider)
          .sendMessage(_id, text)
          .timeout(sendTimeout);
      ref
        ..invalidate(conversationsProvider)
        ..invalidate(messagesProvider(_id));
      await ref.read(messagesProvider(_id).future);
      if (!mounted) return;
      setState(() => _pending.remove(draft));
      _scrollToEnd();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final i = _pending.indexOf(draft);
        if (i >= 0) {
          _pending[i] = draft.copyWith(status: MessageStatus.unknown);
        }
      });
    }
  }

  Future<void> _resolve() async {
    setState(() => _resolving = true);
    try {
      await ref.read(inboxRepositoryProvider).resolve(_id);
      ref
        ..invalidate(conversationProvider(_id))
        ..invalidate(conversationsProvider);
      if (mounted) showSoToast(context, 'Đã đánh dấu đã giải quyết');
    } catch (e) {
      if (mounted) showSoToast(context, AsyncValueView.errorMessage(e));
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _attach(Conversation conv) async {
    final order = await showAttachOrderSheet(context, conv);
    if (order == null || !mounted) return;
    ref.invalidate(conversationProvider(_id));
    showSoToast(context, 'Đã gắn đơn ${order.platformOrderId}');
  }

  @override
  Widget build(BuildContext context) {
    final convAsync = ref.watch(conversationProvider(_id));
    final msgAsync = ref.watch(messagesProvider(_id));
    final conv = convAsync.value;
    final now = ref.watch(clockProvider)();

    ref.listen(messagesProvider(_id), (prev, next) {
      if (prev?.hasValue != true && next.hasValue) _scrollToEnd();
    });

    return SoScaffold(
      controller: _scroll,
      scrollable: convAsync.hasValue || convAsync.hasError,
      appBar: SoAppBar(
        title: conv?.customerName ?? 'Hội thoại',
        channel: conv?.platform,
        actions: [
          if (conv != null && !conv.resolved)
            TextButton(
              key: const Key('conversation_resolve'),
              onPressed: _resolving ? null : _resolve,
              child: const Text('Đã giải quyết'),
            ),
          const SizedBox(width: SoSpace.s8),
        ],
      ),
      bottomBar: conv == null
          ? null
          : _Composer(
              controller: _input,
              sending: _sending,
              onSend: _send,
              onPhoto: () => showSoToast(context, 'Gửi ảnh sắp có'),
            ),
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: switch (convAsync) {
            AsyncData(value: final conv) => SliverList.list(
              children: [
                const SoMockBanner(
                  message: 'Tin nhắn là dữ liệu mẫu, backend chưa có API.',
                ),
                const SizedBox(height: SoSpace.s16),
                if (conv.showsDeadline) ...[
                  SoBanner(
                    key: const Key('conversation_deadline'),
                    tone: SoBannerTone.danger,
                    title: responseDueLabel(conv.responseDueAt!, now: now),
                    message:
                        'Nhãn khiếu nại đã khóa, chỉ bỏ khi đánh dấu Đã '
                        'giải quyết.',
                  ),
                  const SizedBox(height: SoSpace.cardGap),
                ],
                _RelatedOrder(
                  orderId: conv.orderId,
                  onAttach: () => _attach(conv),
                ),
                const SizedBox(height: SoSpace.group),
                switch (msgAsync) {
                  AsyncData(:final value) => _MessageList(
                    messages: [...value, ..._pending],
                    now: now,
                  ),
                  AsyncError(:final error) => SoEmptyState.error(
                    title: 'Không tải được tin nhắn',
                    message: AsyncValueView.errorMessage(error),
                    onAction: () => ref.invalidate(messagesProvider(_id)),
                  ),
                  _ => const _MessagesSkeleton(),
                },
              ],
            ),
            AsyncError(:final error) => SliverToBoxAdapter(
              child: SoEmptyState.error(
                title: 'Không tải được hội thoại',
                message: AsyncValueView.errorMessage(error),
                onAction: () => ref.invalidate(conversationProvider(_id)),
              ),
            ),
            _ => const SliverToBoxAdapter(child: _MessagesSkeleton()),
          },
        ),
      ],
    );
  }
}

/// Thẻ đơn liên quan (mã, trạng thái, sản phẩm) + "Đổi"; chưa gắn đơn thì
/// thẻ viền nét đứt + "Tìm đơn".
class _RelatedOrder extends ConsumerWidget {
  const _RelatedOrder({required this.orderId, required this.onAttach});

  final int? orderId;

  /// Mở sheet gắn đơn ("Đổi" / "Tìm đơn").
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orderId == null) return _NoOrderCard(onAttach: onAttach);
    final async = ref.watch(ordersPageProvider);
    return switch (async) {
      AsyncData(:final value) => switch (value.items.where(
        (o) => o.id == orderId,
      )) {
        final found when found.isNotEmpty => _OrderCard(
          order: found.first,
          onAttach: onAttach,
        ),
        _ => _NoOrderCard(onAttach: onAttach),
      },
      AsyncError() => _NoOrderCard(onAttach: onAttach),
      _ => const SoListGroup(children: [SoSkeletonList(count: 1)]),
    };
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onAttach});

  final Order order;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Container(
      key: const Key('conversation_order'),
      clipBehavior: Clip.antiAlias,
      decoration: SoShape.card(c),
      child: Material(
        color: c.surface,
        child: InkWell(
          onTap: () => context.push(Routes.merchantOrderDetail, extra: order),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SoSpace.s16,
              SoSpace.s12,
              SoSpace.s4,
              SoSpace.s12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Đơn liên quan', style: context.textTheme.bodySmall),
                      const SizedBox(height: SoSpace.s4),
                      Row(
                        children: [
                          Flexible(child: SoCodeTag(order.platformOrderId)),
                          const SizedBox(width: SoSpace.s8),
                          SoStatusTag(
                            label: order.status.label,
                            status: order.status.soStatus,
                          ),
                        ],
                      ),
                      const SizedBox(height: SoSpace.s8),
                      Text(
                        order.productSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: const Key('conversation_change_order'),
                  onPressed: onAttach,
                  child: const Text('Đổi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoOrderCard extends StatelessWidget {
  const _NoOrderCard({required this.onAttach});

  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return CustomPaint(
      key: const Key('conversation_no_order'),
      painter: _DashedBorderPainter(color: c.fillStrong),
      child: Padding(
        padding: SoSpace.card,
        child: Row(
          children: [
            Icon(LucideIcons.receiptText, color: c.ink2),
            const SizedBox(width: SoSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chưa gắn đơn', style: context.textTheme.titleMedium),
                  Text(
                    'Gắn đơn để xem trạng thái khi trả lời khách.',
                    style: context.textTheme.bodySmall?.copyWith(color: c.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SoSpace.s12),
            SoButton.secondary(
              key: const Key('conversation_find_order'),
              label: 'Tìm đơn',
              size: SoButtonSize.small,
              onPressed: onAttach,
            ),
          ],
        ),
      ),
    );
  }
}

/// Viền nét đứt 1.5px bo `lg` cho thẻ "Chưa gắn đơn".
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.75),
          const Radius.circular(SoRadius.lg),
        ),
      );
    for (final ui.PathMetric metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages, required this.now});

  final List<Message> messages;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('conversation_messages'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, m) in messages.indexed) ...[
          if (i > 0) const SizedBox(height: SoSpace.s12),
          _Bubble(key: Key('message_${m.id}'), message: m, now: now),
        ],
      ],
    );
  }
}

/// Bong bóng tin: khách bên trái (thẻ trắng), shop bên phải (brand). Dưới
/// bong bóng: người gửi · giờ · trạng thái.
class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.message, required this.now});

  final Message message;
  final DateTime now;

  String _time(DateTime at) {
    final day = inboxTimeLabel(at, now: now);
    final hm = Formatters.time(at);
    return day == hm ? hm : '$day $hm';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final m = message;
    final mine = !m.fromCustomer;
    final unsupported = m.text == null;
    final (bg, fg) = mine && !unsupported
        ? (c.brand, c.onBrand)
        : (c.surface, unsupported ? c.ink2 : c.ink);

    final meta = mine
        ? [
            m.senderName ?? 'Bạn',
            if (m.status != MessageStatus.sending) _time(m.sentAt),
            switch (m.status) {
              MessageStatus.sending => 'Đang gửi…',
              MessageStatus.sent => 'Đã gửi',
              MessageStatus.unknown => null,
            },
          ].nonNulls.join(' · ')
        : _time(m.sentAt);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.78,
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SoSpace.s16,
                vertical: SoSpace.s12,
              ),
              decoration: mine && !unsupported
                  ? ShapeDecoration(
                      color: bg,
                      shape: SoShape.squircle(SoRadius.lgAll),
                    )
                  : SoShape.card(c),
              child: unsupported
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.fileX,
                          size: SoSize.iconSmall,
                          color: fg,
                        ),
                        const SizedBox(width: SoSpace.s8),
                        Flexible(
                          child: Text(
                            'Không xem được nội dung này',
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: fg,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      m.text!,
                      style: context.textTheme.bodyLarge?.copyWith(color: fg),
                    ),
            ),
            const SizedBox(height: SoSpace.s4),
            Text(
              meta,
              key: Key('message_meta_${m.id}'),
              style: context.textTheme.bodySmall?.copyWith(color: c.muted),
            ),
            if (m.status == MessageStatus.unknown)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.triangleAlert, size: 14, color: c.warning),
                    const SizedBox(width: SoSpace.s4),
                    Flexible(
                      child: Text(
                        'Chưa rõ đã gửi chưa · đối soát trước khi gửi lại',
                        key: Key('message_unknown_${m.id}'),
                        textAlign: TextAlign.end,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: c.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessagesSkeleton extends StatelessWidget {
  const _MessagesSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SoSkeleton(width: 220, height: 48, radius: SoRadius.lg),
        ),
        SizedBox(height: SoSpace.s12),
        Align(
          alignment: Alignment.centerRight,
          child: SoSkeleton(width: 180, height: 48, radius: SoRadius.lg),
        ),
        SizedBox(height: SoSpace.s12),
        Align(
          alignment: Alignment.centerLeft,
          child: SoSkeleton(width: 240, height: 48, radius: SoRadius.lg),
        ),
      ],
    );
  }
}

/// Ô soạn kính dưới đáy: nút ảnh + ô nhập (nền trắng, tối đa 4 dòng) + nút
/// gửi. Nâng lên theo bàn phím.
class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onPhoto,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPhoto;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final canSend = widget.controller.text.trim().isNotEmpty && !widget.sending;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SoGlass(
        borderRadius: BorderRadius.zero,
        shadow: false,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SoSpace.s4,
              SoSpace.s8,
              SoSpace.s4,
              SoSpace.s8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  key: const Key('composer_photo'),
                  tooltip: 'Gửi ảnh',
                  icon: Icon(LucideIcons.imagePlus, color: c.ink2),
                  onPressed: widget.onPhoto,
                ),
                Expanded(
                  child: TextField(
                    key: const Key('composer_input'),
                    controller: widget.controller,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: context.textTheme.bodyLarge,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: SoSpace.s16,
                        vertical: SoSpace.s12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: SoSpace.s4),
                IconButton(
                  key: const Key('composer_send'),
                  tooltip: 'Gửi',
                  onPressed: canSend ? widget.onSend : null,
                  style: IconButton.styleFrom(
                    backgroundColor: c.brand,
                    foregroundColor: c.onBrand,
                    disabledBackgroundColor: c.fillStrong,
                    disabledForegroundColor: c.muted,
                  ),
                  icon: const Icon(LucideIcons.sendHorizontal),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
