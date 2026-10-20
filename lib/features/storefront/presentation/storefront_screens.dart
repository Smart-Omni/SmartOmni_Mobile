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
import '../../customer_shop/presentation/customer_shop_providers.dart';
import '../../customer_shop/presentation/no_shop_state.dart';
import '../../loyalty/domain/loyalty_rules.dart';
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
              ? const SliverToBoxAdapter(child: NoShopState())
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

/// C-11 Chi tiết sản phẩm cho khách (DESIGN.md mục 8b): ảnh lớn tràn trên +
/// nút back kính; thẻ trắng bo trên 28 (tên, khoảng giá, ghi chú giá sàn,
/// phân loại, mô tả, banner điểm dự kiến); thanh dưới chỉ có nút của sàn có
/// URL (Shopee chính, TikTok Shop phụ).
class StorefrontProductScreen extends ConsumerWidget {
  const StorefrontProductScreen({super.key, required this.productId});

  final int productId;

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      showSoToast(context, 'Không mở được liên kết');
    }
  }

  /// Nút mua: Shopee là nút chính, TikTok Shop là nút phụ; chỉ sàn có URL.
  Widget? _buyBar(BuildContext context, Product p) {
    final shopee = p.marketplaceUrls[Platform.shopee];
    final tiktok = p.marketplaceUrls[Platform.tiktokShop];
    if (shopee == null && tiktok == null) return null;
    Widget button(Platform platform, String url, {required bool primary}) {
      final label = 'Mua trên ${platform.label}';
      final key = Key('buy_${platform.name}');
      void onPressed() => _open(context, url);
      return primary
          ? SoButton(key: key, label: label, onPressed: onPressed)
          : SoButton.secondary(key: key, label: label, onPressed: onPressed);
    }

    return SoActionBar(
      stacked: true,
      primary: shopee != null
          ? button(Platform.shopee, shopee, primary: true)
          : button(Platform.tiktokShop, tiktok!, primary: true),
      secondary: shopee != null && tiktok != null
          ? button(Platform.tiktokShop, tiktok, primary: false)
          : null,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(storefrontProductProvider(productId));
    final product = async.value;
    final shopName = ref.watch(currentShopProvider).value?.name;

    return SoAmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: product == null ? null : _buyBar(context, product),
        body: Stack(
          children: [
            CustomScrollView(
              physics: product != null || async.hasError
                  ? const AlwaysScrollableScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              slivers: [
                if (product != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ImageAndSheet(
                      child: _Details(product: product, shopName: shopName),
                    ),
                  )
                else if (async.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ImageAndSheet(
                      child: SoEmptyState.error(
                        title: 'Không tải được sản phẩm',
                        message: switch (async.error) {
                          final ApiException e => e.message,
                          _ => null,
                        },
                        onAction: () => ref.invalidate(
                          storefrontProductProvider(productId),
                        ),
                      ),
                    ),
                  )
                else
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ImageAndSheet(skeleton: true, child: _Skeleton()),
                  ),
              ],
            ),
            const _GlassBackButton(),
          ],
        ),
      ),
    );
  }
}

/// Ảnh 4:5 tràn hết bề ngang phía trên (cả dưới thanh trạng thái) và thẻ
/// trắng bo trên 28 trồi lên đè đáy ảnh 28, kéo dài tới cuối màn.
class _ImageAndSheet extends StatelessWidget {
  const _ImageAndSheet({required this.child, this.skeleton = false});

  final Widget child;
  final bool skeleton;

  static const _overlap = 28.0;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    // Ảnh tràn hết bề ngang màn. Không dùng LayoutBuilder: SliverFillRemaining
    // cần đo chiều cao tự nhiên, LayoutBuilder không hỗ trợ.
    final imageHeight = MediaQuery.sizeOf(context).width * 5 / 4;
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: imageHeight,
          // Chưa có ảnh sản phẩm thật: ô fill + icon.
          child: ColoredBox(
            color: c.fill,
            child: skeleton
                ? null
                : Icon(
                    LucideIcons.image,
                    size: 48,
                    color: c.muted,
                    semanticLabel: 'Chưa có ảnh sản phẩm',
                  ),
          ),
        ),
        Positioned(
          top: imageHeight - _overlap,
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: c.surface,
              shape: const RoundedSuperellipseBorder(
                borderRadius: SoRadius.sheetTop,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            SoSpace.screen,
            imageHeight - _overlap + SoSpace.s24,
            SoSpace.screen,
            SoSpace.s24,
          ),
          child: child,
        ),
      ],
    );
  }
}

/// Nội dung thẻ trắng.
class _Details extends StatelessWidget {
  const _Details({required this.product, required this.shopName});

  final Product product;
  final String? shopName;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final p = product;
    final min = p.minPrice;
    final max = p.maxPrice;
    final variants = [for (final s in p.skus) ?s.variantName];
    final points = min == null ? null : LoyaltyRules.pointsForAmount(min);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(p.name, style: context.textTheme.titleLarge),
        if (min != null && max != null) ...[
          const SizedBox(height: SoSpace.s8),
          Text(
            min == max
                ? Formatters.vnd(min)
                : '${Formatters.number(min)} – ${Formatters.vnd(max)}',
            key: const Key('product_price'),
            style: context.soText.metricSm,
          ),
          const SizedBox(height: SoSpace.s4),
          Text(
            'Giá tham khảo, giá trên sàn có thể khác.',
            style: context.textTheme.bodySmall?.copyWith(color: c.ink2),
          ),
        ],
        if (variants.isNotEmpty) ...[
          const SizedBox(height: SoSpace.s20),
          Text(
            'Phân loại',
            style: context.textTheme.labelLarge?.copyWith(color: c.ink2),
          ),
          const SizedBox(height: SoSpace.s8),
          Wrap(
            spacing: SoSpace.s8,
            runSpacing: SoSpace.s8,
            children: [for (final v in variants) _VariantChip(v)],
          ),
        ],
        if (p.description case final description?) ...[
          const SizedBox(height: SoSpace.s20),
          Text(description, style: context.textTheme.bodyLarge),
        ],
        if (points != null && shopName != null) ...[
          const SizedBox(height: SoSpace.s20),
          SoBanner(
            key: const Key('product_points'),
            tone: SoBannerTone.info,
            title: 'Tích khoảng $points điểm tại $shopName',
            message:
                'Mua trên sàn, sau khi đơn hoàn tất 15 ngày thì claim đơn để '
                'nhận điểm.',
          ),
        ],
        if (p.marketplaceUrls.isEmpty) ...[
          const SizedBox(height: SoSpace.s20),
          Text(
            'Sản phẩm chưa mở bán trên sàn.',
            key: const Key('product_not_on_sale'),
            style: context.textTheme.bodyMedium?.copyWith(color: c.ink2),
          ),
        ],
      ],
    );
  }
}

/// Chip phân loại chỉ để xem: capsule nền fill, chữ subhead ink2.
class _VariantChip extends StatelessWidget {
  const _VariantChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Container(
      constraints: const BoxConstraints(minHeight: SoSize.chip),
      padding: const EdgeInsets.symmetric(horizontal: SoSpace.s12),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: c.fill,
        shape: SoShape.squircle(SoRadius.capsuleAll),
      ),
      child: Text(
        label,
        style: context.textTheme.labelLarge?.copyWith(color: c.ink2),
      ),
    );
  }
}

/// Nút back tròn kính mỏng 36 nổi trên ảnh, dưới vùng an toàn, cách mép 16;
/// vùng chạm 48 (IconButton tự đệm 6 mỗi bên).
class _GlassBackButton extends StatelessWidget {
  const _GlassBackButton();

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final insets = MediaQuery.paddingOf(context);
    return Positioned(
      top: insets.top + SoSpace.s8 - 6,
      left: insets.left + SoSpace.s16 - 6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SoGlass(
            level: SoGlassLevel.thin,
            borderRadius: SoRadius.capsuleAll,
            child: SizedBox.square(dimension: SoSize.controlSmall),
          ),
          IconButton(
            key: const Key('product_back'),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            style: IconButton.styleFrom(
              foregroundColor: c.ink,
              fixedSize: const Size.square(SoSize.controlSmall),
              minimumSize: const Size.square(SoSize.controlSmall),
            ),
            icon: const Icon(LucideIcons.chevronLeft, size: SoSize.iconSmall),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

/// Skeleton nội dung thẻ trắng.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoSkeleton(width: 220, height: 24),
        SizedBox(height: SoSpace.s12),
        SoSkeleton(width: 160, height: 24),
        SizedBox(height: SoSpace.s20),
        SoSkeleton(height: 14),
        SizedBox(height: SoSpace.s8),
        SoSkeleton(height: 14),
      ],
    );
  }
}
