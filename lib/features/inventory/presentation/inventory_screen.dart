import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/inventory_item.dart';
import 'inventory_providers.dart';
import 'stock_sheet.dart';
import 'stock_ui.dart';

/// M-40 Tồn kho theo SKU. Chạm một SKU để đặt lại số tồn (sheet).
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  InventoryFilter _filter = InventoryFilter.all;

  Future<void> _adjust(InventoryItem item) async {
    final saved = await showStockSheet(context, item);
    if (saved == null || !mounted) return;
    ref.invalidate(inventoryListProvider);
    showSoToast(context, 'Đã lưu số tồn ${item.skuCode}: $saved');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(inventoryListProvider);
    return Scaffold(
      appBar: const SoAppBar.root(title: 'Tồn kho'),
      body: Column(
        children: [
          const SoMockBanner(
            message:
                'Danh sách tồn kho là dữ liệu mẫu. Lưu số tồn gọi API thật '
                'khi tắt chế độ mock.',
          ),
          Expanded(
            child: switch (async) {
              AsyncData(:final value) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(inventoryListProvider);
                  await ref.read(inventoryListProvider.future);
                },
                child: _InventoryBody(
                  items: value,
                  filter: _filter,
                  onFilter: (f) => setState(() => _filter = f),
                  onTap: _adjust,
                ),
              ),
              AsyncError(:final error) => ListView(
                children: [
                  SoEmptyState.error(
                    title: 'Không tải được tồn kho',
                    message: AsyncValueView.errorMessage(error),
                    onAction: () => ref.invalidate(inventoryListProvider),
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

class _InventoryBody extends StatelessWidget {
  const _InventoryBody({
    required this.items,
    required this.filter,
    required this.onFilter,
    required this.onTap,
  });

  final List<InventoryItem> items;
  final InventoryFilter filter;
  final ValueChanged<InventoryFilter> onFilter;
  final ValueChanged<InventoryItem> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final totals = inventoryTotals(items);
    final visible = items.where(filter.matches).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: SoSpace.s24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SoSpace.screen,
            SoSpace.s16,
            SoSpace.screen,
            0,
          ),
          child: Container(
            padding: const EdgeInsets.all(SoSpace.s16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: SoRadius.mdAll,
              border: Border.all(color: c.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'TOÀN KHO · ${items.length} SKU',
                  style: context.soText.overline,
                ),
                const SizedBox(height: SoSpace.s12),
                SoStockMeter(
                  key: const Key('inventory_total_meter'),
                  onHand: totals.onHand,
                  reserved: totals.reserved,
                ),
              ],
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            SoSpace.screen,
            SoSpace.s16,
            SoSpace.screen,
            SoSpace.s12,
          ),
          child: Row(
            children: [
              for (final (i, f) in InventoryFilter.values.indexed) ...[
                if (i > 0) const SizedBox(width: SoSpace.s8),
                SoFilterChip(
                  key: Key('stock_filter_${f.name}'),
                  label: f.label,
                  count: items.where(f.matches).length,
                  selected: filter == f,
                  onSelected: () => onFilter(f),
                ),
              ],
            ],
          ),
        ),
        if (visible.isEmpty)
          SoEmptyState(
            icon: LucideIcons.packageCheck,
            title: filter == InventoryFilter.all
                ? 'Chưa có SKU nào'
                : 'Không có SKU nào cần chú ý',
            message: filter == InventoryFilter.all
                ? 'Thêm sản phẩm để bắt đầu theo dõi tồn kho.'
                : 'Mọi SKU đều còn đủ hàng.',
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.symmetric(horizontal: BorderSide(color: c.line)),
            ),
            child: Column(
              children: [
                for (final (i, item) in visible.indexed) ...[
                  if (i > 0) const Divider(),
                  _StockRow(item: item, onTap: () => onTap(item)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Hàng SKU: tên · biến thể, CodeTag, thanh mini | số có thể bán + nhãn mức.
class _StockRow extends StatelessWidget {
  const _StockRow({required this.item, required this.onTap});

  final InventoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final title = [item.productName, ?item.variantName].join(' · ');
    return Material(
      color: c.surface,
      child: InkWell(
        key: Key('stock_${item.skuId}'),
        onTap: onTap,
        child: Padding(
          padding: SoSpace.card,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.soText.bodyStrong,
                    ),
                    const SizedBox(height: SoSpace.s4),
                    SoCodeTag(item.skuCode),
                    const SizedBox(height: SoSpace.s8),
                    SoStockMeter.mini(
                      onHand: item.quantityOnHand,
                      reserved: item.reservedQuantity,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SoSpace.s16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.number(item.available),
                    style: context.soText.numeral.copyWith(
                      color: item.level.numberColor(c),
                    ),
                  ),
                  Text('có thể bán', style: context.textTheme.bodySmall),
                  const SizedBox(height: SoSpace.s4),
                  StockLevelTag(level: item.level),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
