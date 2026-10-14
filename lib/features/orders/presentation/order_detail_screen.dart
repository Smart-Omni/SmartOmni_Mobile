import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/order.dart';
import 'orders_providers.dart';

/// Chi tiết đơn hàng.
///
/// Backend chưa có `GET /api/orders/{id}` nên đơn được truyền từ màn danh sách.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.order});

  final Order order;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  late Order _order = widget.order;
  bool _busy = false;

  Future<void> _changeStatus(OrderStatus status) async {
    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(ordersRepositoryProvider)
          .updateStatus(_order.id, status);
      ref.invalidate(ordersPageProvider);
      if (!mounted) return;
      setState(() => _order = updated);
      showInfoSnackBar(context, 'Đã chuyển sang "${status.label}"');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createReturn() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReasonDialog(),
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(ordersRepositoryProvider)
          .createReturn(orderId: _order.id, reason: reason);
      if (mounted) showInfoSnackBar(context, 'Đã ghi nhận yêu cầu hoàn/trả');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('#${o.platformOrderId}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row('Sàn', o.platform.label),
          _row('Trạng thái', o.status.label),
          _row('Tổng tiền', Formatters.vnd(o.totalAmount)),
          _row('Thời gian', Formatters.dateTime(o.createdAt)),
          _row('Khách hàng', o.customerName ?? '—'),
          _row('Điện thoại', o.customerPhone ?? '—'),
          _row('Địa chỉ', o.shippingAddress ?? '—'),
          const SizedBox(height: 16),
          Text('Sản phẩm', style: text.titleMedium),
          if (o.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Backend chưa trả danh sách sản phẩm của đơn.'),
            ),
          for (final item in o.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.name),
              subtitle: Text(item.skuCode),
              trailing: Text(
                '${item.quantity} × ${Formatters.vnd(item.unitPrice)}',
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Trạng thái hoàn tất / trả hàng / hủy được đồng bộ từ sàn, '
            'không chỉnh tay.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final next in o.status.manualTransitions)
            FilledButton(
              onPressed: _busy ? null : () => _changeStatus(next),
              child: Text('Chuyển sang "${next.label}"'),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => showInfoSnackBar(
              context,
              'In vận đơn PDF: backend chưa có API (sẽ bổ sung).',
            ),
            icon: const Icon(Icons.print_outlined),
            label: const Text('In vận đơn'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _createReturn,
            icon: const Icon(Icons.assignment_return_outlined),
            label: const Text('Ghi nhận hoàn/trả'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 110, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lý do hoàn/trả'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(hintText: 'Nhập lý do'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }
}
