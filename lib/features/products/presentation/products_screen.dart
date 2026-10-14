import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import 'products_providers.dart';

/// Danh sách sản phẩm của cửa hàng (Merchant).
class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sản phẩm')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.merchantProductCreate),
        icon: const Icon(Icons.add),
        label: const Text('Thêm sản phẩm'),
      ),
      body: Column(
        children: [
          const MockDataBanner(
            note:
                'Danh sách sản phẩm đang dùng dữ liệu mẫu (chưa có GET /api/products).',
          ),
          Expanded(
            child: AsyncValueView(
              value: ref.watch(productsListProvider),
              onRetry: () => ref.invalidate(productsListProvider),
              data: (products) {
                if (products.isEmpty) {
                  return const EmptyView(message: 'Chưa có sản phẩm');
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = products[i];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.inventory_2_outlined),
                      ),
                      title: Text(p.name),
                      subtitle: Text(
                        '${p.skus.length} SKU · từ ${Formatters.vnd(p.minPrice)}',
                      ),
                      trailing: p.active ? null : const Chip(label: Text('Ẩn')),
                      onTap: () =>
                          context.push(Routes.merchantProductDetail(p.id)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
