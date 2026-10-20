import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/routes.dart';
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

/// Danh sách sản phẩm cho khách. Khách KHÔNG mua trên SmartOmni mà được
/// chuyển sang Shopee / TikTok Shop.
class StorefrontScreen extends ConsumerWidget {
  const StorefrontScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sản phẩm')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Hỏi trợ lý AI',
        onPressed: () => showInfoSnackBar(
          context,
          'Chatbot AI tư vấn sản phẩm: sẽ bổ sung khi có API.',
        ),
        child: const Icon(Icons.chat_bubble_outline),
      ),
      body: Column(
        children: [
          const MockDataBanner(),
          Expanded(
            child: AsyncValueView(
              value: ref.watch(storefrontProductsProvider),
              onRetry: () => ref.invalidate(storefrontProductsProvider),
              data: (products) => GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: products.length,
                itemBuilder: (_, i) {
                  final p = products[i];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => context.push(Routes.customerProduct(p.id)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              alignment: Alignment.center,
                              child: const Icon(Icons.image_outlined, size: 40),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Từ ${Formatters.vnd(p.minPrice)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
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
