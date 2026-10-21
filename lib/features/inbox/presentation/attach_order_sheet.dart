import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_ui.dart';
import '../../orders/presentation/orders_providers.dart';
import '../domain/inbox.dart';
import 'inbox_providers.dart';

/// Mở sheet "Gắn đơn vào hội thoại" (M-61). Trả về đơn vừa gắn, `null` nếu
/// hủy.
Future<Order?> showAttachOrderSheet(
  BuildContext context,
  Conversation conversation,
) => showSoBottomSheet<Order>(
  context: context,
  builder: (_) => AttachOrderSheet(conversation: conversation),
);

/// Ô mã đơn (mono) lọc danh sách `SoOrderRow` cùng sàn, chọn một → Gắn đơn.
///
/// Danh sách lấy từ trang đơn đầu đã tải. Khi có API tin nhắn thật, ô mã đơn
/// nên gọi tìm kiếm trên server.
class AttachOrderSheet extends ConsumerStatefulWidget {
  const AttachOrderSheet({super.key, required this.conversation});

  final Conversation conversation;

  @override
  ConsumerState<AttachOrderSheet> createState() => _AttachOrderSheetState();
}

class _AttachOrderSheetState extends ConsumerState<AttachOrderSheet> {
  final _code = TextEditingController();
  late int? _selected = widget.conversation.orderId;
  bool _busy = false;

  /// Lỗi khi gắn: hiện ngay trong sheet (toast sẽ nằm sau sheet).
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit(Order order) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(inboxRepositoryProvider)
          .attachOrder(widget.conversation.id, order);
      if (mounted) Navigator.of(context).pop(order);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is ApiException
            ? e.message
            : 'Kiểm tra kết nối mạng rồi thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ordersPageProvider);
    final candidates =
        [
          for (final o in async.value?.items ?? const <Order>[])
            if (canAttachOrder(widget.conversation, o)) o,
        ]..sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
    final shown = candidates
        .where((o) => orderCodeMatches(o, _code.text))
        .toList();
    // Chỉ gắn đơn đang hiện: đơn đã chọn mà bị ô mã lọc khuất thì không gắn.
    final picked = shown.where((o) => o.id == _selected).firstOrNull;
    final changed = picked != null && picked.id != widget.conversation.orderId;

    return SoBottomSheet(
      title: 'Gắn đơn vào hội thoại',
      secondary: SoButton.secondary(
        label: context.l10n.cancel,
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
      ),
      primary: SoButton(
        key: const Key('attach_submit'),
        label: 'Gắn đơn',
        loading: _busy,
        onPressed: changed ? () => _submit(picked) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            SoBanner(
              key: const Key('attach_error'),
              tone: SoBannerTone.danger,
              title: 'Chưa gắn được đơn',
              message: _error,
            ),
            const SizedBox(height: SoSpace.s16),
          ],
          SoTextField(
            key: const Key('attach_code'),
            label: 'Mã đơn',
            hint: 'Nhập mã đơn ${widget.conversation.platform.label}',
            controller: _code,
            mono: true,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: SoSpace.s16),
          // Kính không làm nền cho danh sách: đặt trong thẻ trắng đặc, cuộn
          // bên trong sheet.
          SoListGroup(
            children: [
              ConstrainedBox(
                // Giãn hết bề rộng thẻ để chữ báo rỗng / lỗi căn trái.
                constraints: BoxConstraints(
                  minWidth: double.infinity,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                ),
                child: switch (async) {
                  AsyncData() when shown.isEmpty => Padding(
                    padding: SoSpace.card,
                    child: Text(
                      candidates.isEmpty
                          ? 'Chưa có đơn ${widget.conversation.platform.label} nào.'
                          : 'Không có đơn khớp mã này.',
                      key: const Key('attach_empty'),
                      style: context.textTheme.bodyMedium,
                    ),
                  ),
                  AsyncData() => SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final (i, o) in shown.indexed) ...[
                          if (i > 0) const Divider(indent: SoSpace.s16),
                          SoOrderRow(
                            key: Key('attach_order_${o.id}'),
                            platform: o.platform,
                            orderCode: o.platformOrderId,
                            amount: o.totalAmount,
                            productSummary: o.productSummary,
                            statusLabel: o.status.label,
                            status: o.status.soStatus,
                            meta: o.rowMeta.isEmpty ? null : o.rowMeta,
                            selected: o.id == _selected,
                            onTap: _busy
                                ? null
                                : () => setState(() {
                                    _selected = o.id;
                                    _error = null;
                                  }),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AsyncError(:final error) => SoEmptyState.error(
                    title: 'Không tải được danh sách đơn',
                    message: AsyncValueView.errorMessage(error),
                    onAction: () => ref.invalidate(ordersPageProvider),
                  ),
                  _ => const SoSkeletonList(count: 3),
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
