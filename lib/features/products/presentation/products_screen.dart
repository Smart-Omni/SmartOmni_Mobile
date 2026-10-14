import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/models/platform.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/text_fold.dart';
import '../../../core/widgets/state_views.dart';
import '../../inventory/domain/inventory_item.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../inventory/presentation/stock_ui.dart';
import '../domain/product.dart';
import '../domain/product_stock.dart';
import 'products_providers.dart';

/// M-30 Sản phẩm: segmented Đang bán / Đã ẩn, tìm theo tên hoặc mã SKU,
/// nút "+" trên AppBar để thêm (không dùng FAB).
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  bool _showHidden = false;
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matches(Product p) {
    final q = foldVietnamese(_searchCtrl.text.trim());
    if (q.isEmpty) return true;
    return foldVietnamese(p.name).contains(q) ||
        p.skus.any((s) => foldVietnamese(s.skuCode).contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(productsListProvider);
    // Tồn kho chỉ để gắn nhãn hết/sắp hết; chưa tải xong thì không hiện nhãn.
    final stock = ref.watch(inventoryListProvider).value ?? const [];
    final products = async.value ?? const <Product>[];
    final activeCount = products.where((p) => p.active).length;

    return Scaffold(
      appBar: SoAppBar.root(
        title: 'Sản phẩm',
        actions: [
          IconButton(
            key: const Key('products_search'),
            tooltip: _searching ? 'Đóng tìm kiếm' : 'Tìm sản phẩm',
            icon: Icon(_searching ? LucideIcons.x : LucideIcons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _searchCtrl.clear();
            }),
          ),
          IconButton(
            key: const Key('products_add'),
            tooltip: 'Thêm sản phẩm',
            icon: const Icon(LucideIcons.plus),
            onPressed: () => context.push(Routes.merchantProductCreate),
          ),
        ],
      ),
      body: Column(
        children: [
          const SoMockBanner(
            message: 'Danh sách sản phẩm là dữ liệu mẫu, backend chưa có API.',
          ),
          ColoredBox(
            color: context.soColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(SoSpace.screen),
              child: Column(
                children: [
                  if (_searching) ...[
                    TextField(
                      key: const Key('products_search_field'),
                      controller: _searchCtrl,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      style: context.textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'Tên sản phẩm hoặc mã SKU',
                        prefixIcon: Icon(
                          LucideIcons.search,
                          size: SoSize.iconSmall,
                        ),
                        constraints: BoxConstraints(minHeight: SoSize.control),
                      ),
                    ),
                    const SizedBox(height: SoSpace.s12),
                  ],
                  SoSegmented<bool>(
                    key: const Key('products_segmented'),
                    selected: _showHidden,
                    onChanged: (v) => setState(() => _showHidden = v),
                    segments: [
                      SoSegment(value: false, label: 'Đang bán · $activeCount'),
                      SoSegment(
                        value: true,
                        label: 'Đã ẩn · ${products.length - activeCount}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Divider(color: context.soColors.line),
          Expanded(
            child: switch (async) {
              AsyncData(:final value) => RefreshIndicator(
                onRefresh: () async {
                  ref
                    ..invalidate(productsListProvider)
                    ..invalidate(inventoryListProvider);
                  await ref.read(productsListProvider.future);
                },
                child: _ProductList(
                  products: value
                      .where((p) => p.active != _showHidden)
                      .where(_matches)
                      .toList(),
                  stock: stock,
                  searching: _searchCtrl.text.trim().isNotEmpty,
                  showHidden: _showHidden,
                ),
              ),
              AsyncError(:final error) => ListView(
                children: [
                  SoEmptyState.error(
                    title: 'Không tải được sản phẩm',
                    message: AsyncValueView.errorMessage(error),
                    onAction: () => ref.invalidate(productsListProvider),
                  ),
                ],
              ),
              _ => const SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                child: SoSkeletonList(count: 5),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _ProductList extends StatelessWidget {
  const _ProductList({
    required this.products,
    required this.stock,
    required this.searching,
    required this.showHidden,
  });

  final List<Product> products;
  final List<InventoryItem> stock;
  final bool searching;
  final bool showHidden;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return ListView(
        children: [
          if (searching)
            const SoEmptyState(
              icon: LucideIcons.searchX,
              title: 'Không tìm thấy sản phẩm',
              message: 'Thử tên khác hoặc một phần mã SKU.',
            )
          else if (showHidden)
            const SoEmptyState(
              icon: LucideIcons.box,
              title: 'Không có sản phẩm nào đang ẩn',
            )
          else
            SoEmptyState(
              icon: LucideIcons.box,
              title: 'Chưa có sản phẩm',
              message: 'Thêm sản phẩm đầu tiên để bán trên các sàn.',
              actionLabel: 'Thêm sản phẩm',
              onAction: () => context.push(Routes.merchantProductCreate),
            ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: SoSpace.s24),
      itemCount: products.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (_, i) => _ProductRow(
        product: products[i],
        level: productStockLevel(products[i], stock),
      ),
    );
  }
}

/// Hàng sản phẩm: ảnh 56×70, tên, "n SKU · mã-*", kênh | giá "từ", nhãn tồn.
class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.level});

  final Product product;
  final StockLevel? level;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final p = product;
    final channels = [
      for (final platform in Platform.values)
        if (p.marketplaceUrls.containsKey(platform)) platform,
    ];
    return Material(
      color: c.surface,
      child: InkWell(
        key: Key('product_${p.id}'),
        onTap: () => context.push(Routes.merchantProductDetail(p.id)),
        child: Padding(
          padding: SoSpace.card,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 70,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.soText.bodyStrong,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.skus.length} SKU · '
                      '${skuCodePattern([for (final s in p.skus) s.skuCode])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.soText.code.copyWith(color: c.muted),
                    ),
                    if (channels.isNotEmpty) ...[
                      const SizedBox(height: SoSpace.s8),
                      Wrap(
                        spacing: SoSpace.s12,
                        runSpacing: SoSpace.s4,
                        children: [
                          for (final platform in channels)
                            SoChannelTag(platform: platform),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: SoSpace.s12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (p.minPrice != null) ...[
                    Text('từ', style: context.textTheme.bodySmall),
                    Text(
                      Formatters.vnd(p.minPrice),
                      style: context.soText.numeral,
                    ),
                  ],
                  const SizedBox(height: SoSpace.s8),
                  StockLevelTag(level: level),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
