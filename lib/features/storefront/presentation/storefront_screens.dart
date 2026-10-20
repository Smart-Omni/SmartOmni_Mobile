import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/models/platform.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../customer_shop/presentation/customer_shop_providers.dart';
import '../../products/domain/product.dart';
import '../data/storefront_mock_repository.dart';
import '../domain/storefront_repository.dart';

/// Backend chưa có API storefront cho khách -> luôn dùng mock (không dùng API
/// merchant `/api/products`).
final storefrontRepositoryProvider = Provider<StorefrontRepository>(
  (ref) => StorefrontMockRepository(),
);

/// Sản phẩm của cửa hàng đang xem; chưa tham gia cửa hàng nào thì rỗng.
final storefrontProductsProvider = FutureProvider.autoDispose<List<Product>>((
  ref,
) async {
  final shop = await ref.watch(currentShopProvider.future);
  if (shop == null) return const [];
  return ref.watch(storefrontRepositoryProvider).listProducts(shop.tenantId);
});

final storefrontProductProvider = FutureProvider.autoDispose
    .family<Product, int>((ref, id) async {
      final shop = await ref.watch(currentShopProvider.future);
      if (shop == null) {
        throw const ApiException(
          type: ApiErrorType.notFound,
          message: 'Bạn chưa tham gia cửa hàng nào.',
        );
      }
      return ref
          .watch(storefrontRepositoryProvider)
          .getProduct(shop.tenantId, id);
    });

/// C-10 Sản phẩm (DESIGN.md mục 8b): SoShopSwitcher + "Hỏi AI" trên thanh,
/// tiêu đề lớn "Sản phẩm", lưới 2 cột, kéo để làm mới. Khách KHÔNG mua trên
/// SmartOmni mà được chuyển sang Shopee / TikTok Shop (C-11).
class StorefrontScreen extends ConsumerWidget {
  const StorefrontScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(myShopsProvider)
      ..invalidate(storefrontProductsProvider);
    await ref.read(storefrontProductsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(currentShopProvider);
    final shop = shopAsync.value;
    final productsAsync = ref.watch(storefrontProductsProvider);
    final products = productsAsync.value;
    final noShop = shopAsync.hasValue && shop == null;

    return SoScaffold(
      appBar: SoAppBar.root(
        title: 'Sản phẩm',
        leading: shop == null
            ? null
            : SoShopSwitcher(
                key: const Key('shop_switcher'),
                name: shop.name,
                onTap: () => context.push(Routes.customerShops),
              ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: SoSpace.s12),
            child: SoButton.secondary(
              key: const Key('ask_ai'),
              label: 'Hỏi AI',
              icon: LucideIcons.messageCircle,
              size: SoButtonSize.small,
              // C-12 Chatbot chưa làm.
              onPressed: () => showSoToast(context, 'Sắp có'),
            ),
          ),
        ],
      ),
      onRefresh: products != null ? () => _refresh(ref) : null,
      scrollable: products != null || productsAsync.hasError,
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: noShop
              ? SliverToBoxAdapter(
                  child: SoEmptyState(
                    key: const Key('storefront_no_shop'),
                    icon: LucideIcons.store,
                    title: 'Bạn chưa tham gia cửa hàng nào',
                    message: 'Nhập mã cửa hàng để xem sản phẩm và tích điểm.',
                    actionLabel: 'Thêm cửa hàng',
                    onAction: () => context.push(Routes.customerShops),
                  ),
                )
              : products != null
              ? SliverMainAxisGroup(
                  slivers: [
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: SoSpace.s16),
                        child: SoMockBanner(
                          message:
                              'Sản phẩm của cửa hàng là dữ liệu mẫu, backend '
                              'chưa có API.',
                        ),
                      ),
                    ),
                    if (products.isEmpty)
                      const SliverToBoxAdapter(
                        child: SoEmptyState(
                          key: Key('storefront_empty'),
                          icon: LucideIcons.box,
                          title: 'Cửa hàng chưa có sản phẩm',
                        ),
                      )
                    else
                      _ProductGrid(products: products),
                  ],
                )
              : productsAsync.hasError || shopAsync.hasError
              ? SliverToBoxAdapter(
                  child: SoEmptyState.error(
                    title: 'Không tải được sản phẩm',
                    message: switch (productsAsync.error ?? shopAsync.error) {
                      final ApiException e => e.message,
                      _ => null,
                    },
                    onAction: () => ref
                      ..invalidate(myShopsProvider)
                      ..invalidate(storefrontProductsProvider),
                  ),
                )
              : const _GridSkeleton(),
        ),
      ],
    );
  }
}

/// Lưới 2 cột; hai thẻ cùng hàng cao bằng nhau (tên dài, chữ phóng to,
/// nhãn kênh xuống dòng đều không tràn).
class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final rows = (products.length / 2).ceil();
    return SliverList.separated(
      itemCount: rows,
      separatorBuilder: (_, _) => const SizedBox(height: SoSpace.cardGap),
      itemBuilder: (_, row) {
        final i = row * 2;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _ProductCard(product: products[i])),
              const SizedBox(width: SoSpace.cardGap),
              Expanded(
                child: i + 1 < products.length
                    ? _ProductCard(product: products[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Thẻ sản phẩm: ảnh 4:5, tên, giá "từ", kênh đang bán.
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final p = product;
    final price = 'Từ ${Formatters.vnd(p.minPrice)}';
    final channels = [
      for (final platform in Platform.values)
        if (p.marketplaceUrls.containsKey(platform)) platform,
    ];
    return DecoratedBox(
      decoration: SoShape.card(c),
      child: Material(
        type: MaterialType.transparency,
        shape: SoShape.squircle(SoRadius.lgAll),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('storefront_product_${p.id}'),
          onTap: () => context.push(Routes.customerProduct(p.id)),
          child: Semantics(
            button: true,
            label: '${p.name}, $price',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Chưa có ảnh sản phẩm thật: ô fill + icon.
                AspectRatio(
                  aspectRatio: 4 / 5,
                  child: ColoredBox(
                    color: c.fill,
                    child: Icon(LucideIcons.image, color: c.muted),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(SoSpace.s12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleMedium,
                      ),
                      const SizedBox(height: SoSpace.s4),
                      Text(price, style: context.soText.money),
                      const SizedBox(height: SoSpace.s8),
                      if (channels.isEmpty)
                        Text(
                          'Chưa mở bán trên sàn',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: c.ink2,
                          ),
                        )
                      else
                        Wrap(
                          spacing: SoSpace.s8,
                          runSpacing: SoSpace.s4,
                          children: [
                            for (final platform in channels)
                              SoChannelTag(platform: platform),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton cùng hình lưới 2 cột (2 hàng).
class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget card() => Container(
      clipBehavior: Clip.antiAlias,
      decoration: SoShape.card(context.soColors),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: SoSkeleton(height: double.infinity, radius: 0),
          ),
          Padding(
            padding: EdgeInsets.all(SoSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SoSkeleton(height: 16),
                SizedBox(height: SoSpace.s8),
                SoSkeleton(width: 96, height: 16),
              ],
            ),
          ),
        ],
      ),
    );
    Widget row() => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: card()),
        const SizedBox(width: SoSpace.cardGap),
        Expanded(child: card()),
      ],
    );
    return SliverList.list(
      children: [
        const SoSkeleton(height: 36, radius: SoRadius.capsule),
        const SizedBox(height: SoSpace.s16),
        row(),
        const SizedBox(height: SoSpace.cardGap),
        row(),
      ],
    );
  }
}

class StorefrontProductScreen extends ConsumerWidget {
  const StorefrontProductScreen({super.key, required this.productId});

  final int productId;

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      showInfoSnackBar(context, 'Không mở được liên kết');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(),
      body: AsyncValueView(
        value: ref.watch(storefrontProductProvider(productId)),
        onRetry: () => ref.invalidate(storefrontProductProvider(productId)),
        data: (p) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AspectRatio(
              aspectRatio: 1.4,
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Icon(Icons.image_outlined, size: 64),
              ),
            ),
            const SizedBox(height: 16),
            Text(p.name, style: Theme.of(context).textTheme.titleLarge),
            Text('Từ ${Formatters.vnd(p.minPrice)}'),
            if (p.description != null) ...[
              const SizedBox(height: 12),
              Text(p.description!),
            ],
            const SizedBox(height: 16),
            Text('Phân loại', style: Theme.of(context).textTheme.titleMedium),
            Wrap(
              spacing: 8,
              children: [
                for (final s in p.skus)
                  Chip(label: Text(s.variantName ?? s.skuCode)),
              ],
            ),
            const SizedBox(height: 24),
            if (p.marketplaceUrls.isEmpty)
              const Text('Sản phẩm chưa mở bán trên sàn.'),
            for (final platform in Platform.values)
              if (p.marketplaceUrls[platform] case final url?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton.icon(
                    onPressed: () => _open(context, url),
                    icon: const Icon(Icons.open_in_new),
                    label: Text('Mua trên ${platform.label}'),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
