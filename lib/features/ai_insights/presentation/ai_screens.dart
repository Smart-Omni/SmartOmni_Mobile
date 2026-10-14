import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../data/ai_repositories.dart';
import '../domain/demand_forecast.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.useMock
      ? AiMockRepository()
      : AiRemoteRepository(ref.watch(dioProvider));
});

final skuForecastProvider = FutureProvider.autoDispose
    .family<List<DemandForecast>, int>(
      (ref, skuId) => ref.watch(aiRepositoryProvider).forecastForSku(skuId),
    );

/// Dự báo nhu cầu 7 ngày tới của 1 SKU.
class SkuForecastScreen extends ConsumerWidget {
  const SkuForecastScreen({super.key, required this.skuId});

  final int skuId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Dự báo nhu cầu · SKU $skuId')),
      body: AsyncValueView(
        value: ref.watch(skuForecastProvider(skuId)),
        onRetry: () => ref.invalidate(skuForecastProvider(skuId)),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(
              message: 'Chưa có dự báo cho SKU này. Python AI chưa chạy?',
              icon: Icons.auto_graph,
            );
          }
          final total = items.fold<int>(0, (s, e) => s + e.predictedQuantity);
          final reorder = items
              .map((e) => e.recommendedReorderQty)
              .whereType<int>()
              .fold<int>(0, (a, b) => a > b ? a : b);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.auto_graph),
                  title: Text(
                    'Dự kiến bán $total sản phẩm trong ${items.length} ngày',
                  ),
                  subtitle: reorder > 0
                      ? Text('AI gợi ý nhập thêm $reorder sản phẩm')
                      : const Text('Chưa cần nhập thêm hàng'),
                ),
              ),
              const SizedBox(height: 12),
              for (final f in items)
                ListTile(
                  title: Text(Formatters.date(f.forecastDate)),
                  trailing: Text('${f.predictedQuantity} sp'),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Màn nhập SKU để xem dự báo (vào từ menu "Thêm").
class AiInsightsScreen extends StatelessWidget {
  const AiInsightsScreen({super.key, required this.onOpenSku});

  final void Function(int skuId) onOpenSku;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI dự báo & gợi ý')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Chọn SKU để xem dự báo nhu cầu. Cảnh báo AI tổng hợp sẽ có khi '
              'backend bổ sung API (xem docs/API_CONTRACT.md).',
            ),
          ),
          for (final (_, name, _, skus, _, _) in MockData.products)
            for (final (skuId, code, variant, _) in skus)
              ListTile(
                title: Text('$name - $variant'),
                subtitle: Text(code),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpenSku(skuId),
              ),
        ],
      ),
    );
  }
}
