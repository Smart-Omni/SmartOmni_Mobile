import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import 'products_providers.dart';

/// Chi tiết sản phẩm + danh sách SKU (Merchant).
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productDetailProvider(productId));
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết sản phẩm')),
      body: AsyncValueView(
        value: productAsync,
        onRetry: () => ref.invalidate(productDetailProvider(productId)),
        data: (p) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(p.name, style: Theme.of(context).textTheme.titleLarge),
            if (p.description != null) ...[
              const SizedBox(height: 8),
              Text(p.description!),
            ],
            const SizedBox(height: 16),
            Text('SKU', style: Theme.of(context).textTheme.titleMedium),
            for (final sku in p.skus)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(sku.variantName ?? sku.skuCode),
                subtitle: Text(sku.skuCode),
                trailing: Text(Formatters.vnd(sku.basePrice)),
                onTap: () => context.push(Routes.merchantAiForecast(sku.id)),
              ),
            const SizedBox(height: 16),
            Text(
              'Liên kết sàn',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (p.marketplaceUrls.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Chưa dán URL sản phẩm trên sàn.'),
              ),
            for (final e in p.marketplaceUrls.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link),
                title: Text(e.key.label),
                subtitle: Text(e.value),
              ),
            const SizedBox(height: 8),
            Text(
              'Chạm vào SKU để xem dự báo nhu cầu (AI).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
