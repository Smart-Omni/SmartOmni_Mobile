import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/order.dart';
import '../domain/order_rules.dart';
import 'order_ui.dart';
import 'orders_providers.dart';
import 'return_sheet.dart';

/// M-21 Chi tiết đơn.
///
/// Backend chưa có `GET /api/orders/{id}` nên đơn được truyền từ màn danh sách.
/// Nhân viên chỉ được chuyển PENDING -> TO_SHIP ("Chuẩn bị hàng"); các trạng
/// thái sau do sàn tự cập nhật nên không có nút.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.order});

  final Order order;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  late Order _order = widget.order;
  bool _busy = false;

  Future<void> _prepare(OrderStatus next) async {
    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(ordersRepositoryProvider)
          .updateStatus(_order.id, next);
      ref.invalidate(ordersPageProvider);
      if (!mounted) return;
      setState(() => _order = updated);
      showSoToast(context, 'Đã chuyển sang ${next.label}');
    } catch (e) {
      if (mounted) showSoToast(context, AsyncValueView.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordReturn() async {
    final ok = await showReturnSheet(context, _order);
    if (ok && mounted) showSoToast(context, 'Đã ghi nhận hoàn/trả');
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final next = o.status.manualTransitions.firstOrNull;
    final canReturn = canRecordReturn(o.status);

    return Scaffold(
      appBar: SoAppBar(title: 'Chi tiết đơn', subtitle: o.platformOrderId),
      bottomNavigationBar: next == null && !canReturn
          ? null
          : SoActionBar(
              secondary: canReturn
                  ? SoButton.secondary(
                      key: const Key('order_return'),
                      label: 'Hoàn/trả',
                      onPressed: _busy ? null : _recordReturn,
                    )
                  : null,
              primary: next == null
                  ? null
                  : SoButton(
                      key: const Key('order_prepare'),
                      label: 'Chuẩn bị hàng',
                      loading: _busy,
                      onPressed: () => _prepare(next),
                    ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SoSpace.screen,
          SoSpace.s16,
          SoSpace.screen,
          SoSpace.s32,
        ),
        children: [
          if (o.status == OrderStatus.pending) ...[
            const SoBanner(
              key: Key('order_pending_banner'),
              tone: SoBannerTone.warning,
              title: 'Đơn đang chờ xử lý',
              message:
                  'Soạn hàng xong, bấm "Chuẩn bị hàng" để chuyển sang Chờ giao.',
            ),
            const SizedBox(height: SoSpace.s16),
          ],
          _HeaderCard(order: o),
          const _GroupTitle('Sản phẩm'),
          _ItemsCard(order: o),
          const _GroupTitle('Khách hàng'),
          _CustomerCard(order: o),
          const _GroupTitle('Tiến trình'),
          _Card(
            child: SoTimeline(
              steps: [
                for (final step in orderProgress(o.status)) step.toTimeline(o),
              ],
            ),
          ),
          const SizedBox(height: SoSpace.s16),
          const _ShippingLabelRow(),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: SoSpace.group, bottom: SoSpace.s8),
    child: Text(title.toUpperCase(), style: context.soText.overline),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = SoSpace.card});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: SoRadius.mdAll,
        border: Border.all(color: c.line),
      ),
      child: child,
    );
  }
}

/// Thẻ đầu: kênh, mã đơn, trạng thái, thời gian, tổng tiền.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: SoSpace.s8,
            runSpacing: SoSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SoChannelTag(platform: o.platform),
              SoCodeTag(o.platformOrderId),
              SoStatusTag(
                key: const Key('order_status'),
                label: o.status.label,
                status: o.status.soStatus,
              ),
            ],
          ),
          const SizedBox(height: SoSpace.s12),
          Text(
            'Đặt lúc ${Formatters.dateTime(o.createdAt)}',
            style: context.textTheme.bodySmall,
          ),
          const SizedBox(height: SoSpace.s12),
          Text('TỔNG TIỀN', style: context.soText.overline),
          const SizedBox(height: SoSpace.s4),
          Text(
            Formatters.vnd(o.totalAmount),
            style: context.textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    if (order.items.isEmpty) {
      return _Card(
        child: Text(
          'Chưa có thông tin sản phẩm cho đơn này.',
          style: context.textTheme.bodyMedium?.copyWith(color: c.ink2),
        ),
      );
    }
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, item) in order.items.indexed) ...[
            if (i > 0) const Divider(),
            Padding(
              padding: SoSpace.card,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.surfaceSunken,
                      borderRadius: SoRadius.smAll,
                    ),
                    child: Icon(
                      LucideIcons.image,
                      size: SoSize.iconSmall,
                      color: c.muted,
                    ),
                  ),
                  const SizedBox(width: SoSpace.s12),
                  Expanded(child: _ItemText(item: item)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemText extends StatelessWidget {
  const _ItemText({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final (name, variant) = item.nameAndVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: context.soText.bodyStrong),
        if (variant != null) Text(variant, style: context.textTheme.bodySmall),
        const SizedBox(height: SoSpace.s8),
        Row(
          children: [
            Flexible(child: SoCodeTag(item.skuCode)),
            const SizedBox(width: SoSpace.s12),
            const Spacer(),
            Text(
              '${item.quantity} × ${Formatters.vnd(item.unitPrice)}',
              style: context.soText.numeral,
            ),
          ],
        ),
      ],
    );
  }
}

/// Khách hàng: lưới 2 cột (nhãn trên, giá trị dưới); địa chỉ chiếm cả hàng.
class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    Widget field(String label, String? value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(value ?? '—', style: context.textTheme.bodyMedium),
      ],
    );
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field('Tên', order.customerName)),
              const SizedBox(width: SoSpace.s16),
              Expanded(child: field('Điện thoại', order.customerPhone)),
            ],
          ),
          const SizedBox(height: SoSpace.s12),
          field('Địa chỉ', order.shippingAddress),
        ],
      ),
    );
  }
}

/// In vận đơn PDF: backend chưa có API (M-22) -> hiện "Sắp có", không bấm được.
class _ShippingLabelRow extends StatelessWidget {
  const _ShippingLabelRow();

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return _Card(
      child: Row(
        children: [
          Icon(LucideIcons.printer, color: c.muted),
          const SizedBox(width: SoSpace.s12),
          Expanded(
            child: Text(
              'In vận đơn PDF',
              style: context.soText.bodyStrong.copyWith(color: c.muted),
            ),
          ),
          const SoStatusTag(label: 'Sắp có', status: SoStatus.neutral),
        ],
      ),
    );
  }
}
