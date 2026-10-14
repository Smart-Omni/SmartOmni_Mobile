import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/order.dart';
import 'orders_providers.dart';

/// Danh sách đơn hàng đa kênh (Shopee + TikTok Shop).
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  OrderStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(ordersPageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Đơn hàng')),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _chip(null, 'Tất cả'),
                for (final s in OrderStatus.values) _chip(s, s.label),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: pageAsync,
              onRetry: () => ref.invalidate(ordersPageProvider),
              data: (page) {
                final orders = _filter == null
                    ? page.items
                    : page.items.where((o) => o.status == _filter).toList();
                if (orders.isEmpty) {
                  return const EmptyView(
                    message: 'Chưa có đơn hàng',
                    icon: Icons.receipt_long,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(ordersPageProvider.future),
                  child: ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => _OrderTile(order: orders[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(OrderStatus? status, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == status,
      onSelected: (_) => setState(() => _filter = status),
    ),
  );
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(order.platform.label.substring(0, 1))),
      title: Text('#${order.platformOrderId}'),
      subtitle: Text(
        '${order.customerName ?? 'Khách'} · ${Formatters.dateTime(order.createdAt)}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(Formatters.vnd(order.totalAmount)),
          Text(
            order.status.label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      onTap: () => context.push(Routes.merchantOrderDetail, extra: order),
    );
  }
}
