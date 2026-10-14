import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/order.dart';
import '../domain/order_rules.dart';
import 'order_ui.dart';
import 'orders_providers.dart';

/// M-20 Danh sách đơn đa kênh (Shopee + TikTok Shop).
///
/// Lọc theo trạng thái (chip có số đếm), tìm theo mã đơn / tên khách,
/// nhóm theo ngày. Số đếm và tìm kiếm chạy trên trang đầu đã tải về.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  OrderStatus? _filter;
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(ordersPageProvider);
    final orders = pageAsync.value?.items ?? const <Order>[];
    final counts = countByStatus(orders);

    return Scaffold(
      appBar: SoAppBar.root(
        title: 'Đơn hàng',
        actions: [
          IconButton(
            key: const Key('orders_search'),
            tooltip: _searching ? 'Đóng tìm kiếm' : 'Tìm đơn',
            icon: Icon(_searching ? LucideIcons.x : LucideIcons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            searching: _searching,
            searchCtrl: _searchCtrl,
            onSearchChanged: (_) => setState(() {}),
            chips: [
              SoFilterChip(
                key: const Key('filter_all'),
                label: 'Tất cả',
                count: orders.length,
                selected: _filter == null,
                onSelected: () => setState(() => _filter = null),
              ),
              for (final s in OrderStatus.values)
                SoFilterChip(
                  key: Key('filter_${s.name}'),
                  label: s.label,
                  count: counts[s],
                  selected: _filter == s,
                  onSelected: () => setState(() => _filter = s),
                ),
            ],
          ),
          Expanded(
            child: switch (pageAsync) {
              AsyncData(:final value) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(ordersPageProvider);
                  await ref.read(ordersPageProvider.future);
                },
                child: _OrderList(
                  orders: value.items
                      .where((o) => _filter == null || o.status == _filter)
                      .where((o) => orderMatches(o, _searchCtrl.text))
                      .toList(),
                  hasAnyOrder: value.items.isNotEmpty,
                ),
              ),
              AsyncError(:final error) => ListView(
                children: [
                  SoEmptyState.error(
                    title: 'Không tải được đơn hàng',
                    message: AsyncValueView.errorMessage(error),
                    onAction: () => ref.invalidate(ordersPageProvider),
                  ),
                ],
              ),
              _ => const SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                child: SoSkeletonList(count: 6),
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// Dải lọc nền trắng dưới AppBar: ô tìm (khi bật) + hàng chip cuộn ngang.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searching,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.chips,
  });

  final bool searching;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Column(
        children: [
          if (searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SoSpace.screen,
                SoSpace.s12,
                SoSpace.screen,
                0,
              ),
              child: TextField(
                key: const Key('orders_search_field'),
                controller: searchCtrl,
                autofocus: true,
                onChanged: onSearchChanged,
                textInputAction: TextInputAction.search,
                style: context.textTheme.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Mã đơn hoặc tên khách',
                  prefixIcon: Icon(LucideIcons.search, size: SoSize.iconSmall),
                  constraints: BoxConstraints(minHeight: SoSize.control),
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: SoSpace.screen,
              vertical: SoSpace.s12,
            ),
            child: Row(
              children: [
                for (final (i, chip) in chips.indexed) ...[
                  if (i > 0) const SizedBox(width: SoSpace.s8),
                  chip,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders, required this.hasAnyOrder});

  final List<Order> orders;
  final bool hasAnyOrder;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return ListView(
        children: [
          hasAnyOrder
              ? const SoEmptyState(
                  icon: LucideIcons.searchX,
                  title: 'Không có đơn phù hợp',
                  message: 'Thử chọn trạng thái khác hoặc đổi từ khóa tìm.',
                )
              : const SoEmptyState(
                  icon: LucideIcons.receiptText,
                  title: 'Chưa có đơn nào',
                  message: 'Đơn mới từ Shopee và TikTok Shop sẽ hiện ở đây.',
                ),
        ],
      );
    }

    final groups = groupOrdersByDay(orders);
    return ListView(
      key: const Key('orders_list'),
      padding: const EdgeInsets.only(bottom: SoSpace.s24),
      children: [
        for (final (day, items) in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SoSpace.screen,
              SoSpace.s16,
              SoSpace.screen,
              SoSpace.s8,
            ),
            child: Text(
              '${dayGroupLabel(day).toUpperCase()} · ${items.length}',
              style: context.soText.overline,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: context.soColors.line),
              ),
            ),
            child: Column(
              children: [
                for (final (i, order) in items.indexed) ...[
                  if (i > 0) const Divider(),
                  OrderRow(
                    key: Key('order_${order.id}'),
                    order: order,
                    onTap: () =>
                        context.push(Routes.merchantOrderDetail, extra: order),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
