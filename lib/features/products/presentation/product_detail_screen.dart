import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/config/app_config.dart';
import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/models/platform.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../account/presentation/account_widgets.dart';
import '../../inventory/domain/inventory_item.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../inventory/presentation/stock_ui.dart';
import '../domain/product.dart';
import 'products_providers.dart';

/// M-31 Chi tiết sản phẩm (Merchant), bố cục theo M-21: thẻ đầu, nhóm SKU
/// (chạm để xem dự báo AI), nhóm liên kết sàn.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productDetailProvider(productId));
    // Tồn kho chỉ để gắn nhãn hết/sắp hết: đang tải hoặc lỗi thì ẩn nhãn,
    // không kéo cả màn sang trạng thái lỗi.
    final stock = ref.watch(inventoryListProvider).value ?? const [];
    final useMock = ref.watch(appConfigProvider).useMock;
    final product = productAsync.value;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SoAppBar(
        title: 'Chi tiết sản phẩm',
        subtitle: product == null || product.skus.isEmpty
            ? null
            : skuCodePattern([for (final s in product.skus) s.skuCode]),
      ),
      body: SoAmbientBackground(
        child: switch (productAsync) {
          AsyncData(:final value) => _Body(
            product: value,
            stock: stock,
            // Chi tiết sản phẩm có API thật; nhãn tồn kho thì luôn là mẫu
            // (backend chưa có GET /api/inventory).
            mockNote: useMock
                ? 'Sản phẩm và tồn kho đang là dữ liệu mẫu.'
                : 'Nhãn tồn kho là dữ liệu mẫu, backend chưa có API.',
          ),
          AsyncError(:final error) => ListView(
            padding: SoSpace.scrollable(context),
            children: [
              SoEmptyState.error(
                title: 'Không tải được sản phẩm',
                // Chỉ hiện lỗi đã dịch từ API, không in exception thô.
                message: error is ApiException ? error.message : null,
                onAction: () =>
                    ref.invalidate(productDetailProvider(productId)),
              ),
            ],
          ),
          _ => const _Skeleton(),
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.product,
    required this.stock,
    required this.mockNote,
  });

  final Product product;
  final List<InventoryItem> stock;
  final String mockNote;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final levels = {for (final item in stock) item.skuId: item.level};
    return ListView(
      padding: SoSpace.scrollable(context, _listPadding),
      children: [
        SoMockBanner(message: mockNote),
        const SizedBox(height: SoSpace.s16),
        _HeaderCard(product: p),
        GroupTitle('SKU · ${p.skus.length}'),
        if (p.skus.isNotEmpty) ...[
          Text(
            'Chạm vào SKU để xem dự báo nhu cầu (AI).',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.soColors.ink2,
            ),
          ),
          const SizedBox(height: SoSpace.sectionTitle),
        ],
        _SkuCard(skus: p.skus, levels: levels),
        const GroupTitle('Liên kết sàn'),
        _LinksCard(urls: p.marketplaceUrls),
      ],
    );
  }
}

const _listPadding = EdgeInsets.fromLTRB(
  SoSpace.screen,
  SoSpace.s8,
  SoSpace.screen,
  SoSpace.s8,
);

/// Thẻ đầu: tên, mô tả, trạng thái + kênh, giá "từ".
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final p = product;
    return Container(
      padding: SoSpace.card,
      decoration: SoShape.card(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name, style: context.textTheme.titleLarge),
          if (p.description != null) ...[
            const SizedBox(height: SoSpace.s4),
            Text(
              p.description!,
              style: context.textTheme.bodyMedium?.copyWith(color: c.ink2),
            ),
          ],
          const SizedBox(height: SoSpace.s12),
          Wrap(
            spacing: SoSpace.s12,
            runSpacing: SoSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SoStatusTag(
                key: const Key('product_status'),
                label: p.active ? 'Đang bán' : 'Đã ẩn',
                status: p.active ? SoStatus.success : SoStatus.neutral,
              ),
              for (final platform in Platform.values)
                if (p.marketplaceUrls.containsKey(platform))
                  SoChannelTag(platform: platform),
            ],
          ),
          if (p.minPrice != null) ...[
            const SizedBox(height: SoSpace.s12),
            Text(
              'Giá từ',
              style: context.textTheme.bodySmall?.copyWith(color: c.ink2),
            ),
            const SizedBox(height: SoSpace.s4),
            Text(Formatters.vnd(p.minPrice), style: context.soText.metric),
          ],
        ],
      ),
    );
  }
}

/// Nhóm SKU: mỗi hàng mở dự báo nhu cầu (M-51).
class _SkuCard extends StatelessWidget {
  const _SkuCard({required this.skus, required this.levels});

  final List<Sku> skus;
  final Map<int, StockLevel> levels;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    if (skus.isEmpty) {
      return Container(
        padding: SoSpace.card,
        decoration: SoShape.card(c),
        child: Text(
          'Sản phẩm chưa có SKU.',
          style: context.textTheme.bodyMedium?.copyWith(color: c.ink2),
        ),
      );
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: SoShape.card(c),
      child: Column(
        children: [
          for (final (i, sku) in skus.indexed) ...[
            if (i > 0) const Divider(indent: SoSpace.s16),
            _SkuRow(sku: sku, level: levels[sku.id]),
          ],
        ],
      ),
    );
  }
}

class _SkuRow extends StatelessWidget {
  const _SkuRow({required this.sku, required this.level});

  final Sku sku;
  final StockLevel? level;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Material(
      color: c.surface,
      child: InkWell(
        key: Key('sku_${sku.id}'),
        onTap: () => context.push(Routes.merchantAiForecast(sku.id)),
        child: Semantics(
          hint: 'Mở dự báo nhu cầu',
          child: Padding(
            padding: SoSpace.card,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Không có tên biến thể thì chỉ hiện mã ở SoCodeTag,
                      // tránh lặp mã hai lần.
                      if (sku.variantName != null) ...[
                        Text(
                          sku.variantName!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.titleMedium,
                        ),
                        const SizedBox(height: SoSpace.s4),
                      ],
                      Wrap(
                        spacing: SoSpace.s8,
                        runSpacing: SoSpace.s4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SoCodeTag(sku.skuCode),
                          StockLevelTag(level: level),
                        ],
                      ),
                      const SizedBox(height: SoSpace.s8),
                      // Đủ chỗ: giá nằm mép phải; chật (chữ phóng to, giá
                      // dài): giá xuống dòng thay vì làm tràn hàng.
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: SoSpace.s12,
                          runSpacing: SoSpace.s4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SoAiLabel(),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Dự báo nhu cầu',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textTheme.bodySmall
                                        ?.copyWith(color: c.ink2),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              Formatters.vnd(sku.basePrice),
                              style: context.soText.money,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SoSpace.s4),
                Icon(
                  LucideIcons.chevronRight,
                  size: SoSize.iconSmall,
                  color: c.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nhóm liên kết sàn: mỗi sàn một hàng, URL cắt "…" + nút chép.
class _LinksCard extends StatelessWidget {
  const _LinksCard({required this.urls});

  final Map<Platform, String> urls;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Container(
      decoration: SoShape.card(c),
      child: Column(
        children: [
          for (final (i, platform) in Platform.values.indexed) ...[
            if (i > 0) const Divider(indent: SoSpace.s16),
            _LinkRow(platform: platform, url: urls[platform]),
          ],
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.platform, required this.url});

  final Platform platform;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final url = this.url;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SoSpace.s16,
        SoSpace.s12,
        url == null ? SoSpace.s16 : SoSpace.s4,
        SoSpace.s12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SoChannelTag(platform: platform),
                const SizedBox(height: 2),
                Text(
                  url ?? 'Chưa có dữ liệu liên kết',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: url == null ? c.muted : c.ink2,
                  ),
                ),
              ],
            ),
          ),
          if (url != null)
            IconButton(
              key: Key('copy_link_${platform.name}'),
              tooltip: 'Chép liên kết ${platform.label}',
              icon: const Icon(LucideIcons.copy, size: SoSize.iconSmall),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) {
                  showSoToast(context, 'Đã chép liên kết ${platform.label}');
                }
              },
            ),
        ],
      ),
    );
  }
}

/// Skeleton cùng hình thẻ đầu + nhóm SKU.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: SoSpace.scrollable(context, _listPadding),
      children: [
        Container(
          padding: SoSpace.card,
          decoration: SoShape.card(context.soColors),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SoSkeleton(width: 200, height: 28),
              SizedBox(height: SoSpace.s8),
              SoSkeleton(height: 16),
              SizedBox(height: SoSpace.s12),
              SoSkeleton(width: 96, height: 24),
              SizedBox(height: SoSpace.s12),
              SoSkeleton(width: 140, height: 40),
            ],
          ),
        ),
        const SizedBox(height: SoSpace.group + 26 + SoSpace.s8),
        const SoListGroup(children: [SoSkeletonList(count: 3)]),
      ],
    );
  }
}
