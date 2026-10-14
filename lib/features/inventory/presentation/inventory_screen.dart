import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/state_views.dart';
import '../data/inventory_repositories.dart';
import '../domain/inventory_item.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final mock = InventoryMockRepository();
  return config.useMock
      ? mock
      : InventoryRemoteRepository(ref.watch(dioProvider), mock);
});

final inventoryListProvider = FutureProvider.autoDispose<List<InventoryItem>>(
  (ref) => ref.watch(inventoryRepositoryProvider).listInventory(),
);

/// Tồn kho theo SKU + đặt lại số lượng tồn.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  bool _onlyLow = false;

  Future<void> _adjust(InventoryItem item) async {
    final newQty = await showDialog<int>(
      context: context,
      builder: (_) => _AdjustDialog(item: item),
    );
    if (newQty == null || !mounted) return;
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .setStock(skuId: item.skuId, newQuantity: newQty);
      ref.invalidate(inventoryListProvider);
      if (mounted) {
        showInfoSnackBar(
          context,
          'Đã cập nhật tồn ${item.skuCode} = $newQty. Hệ thống sẽ đồng bộ lên sàn.',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tồn kho'),
        actions: [
          FilterChip(
            label: const Text('Sắp hết'),
            selected: _onlyLow,
            onSelected: (v) => setState(() => _onlyLow = v),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          const MockDataBanner(
            note:
                'Danh sách tồn kho dùng dữ liệu mẫu; thao tác cập nhật gọi API thật khi USE_MOCK=false.',
          ),
          Expanded(
            child: AsyncValueView(
              value: ref.watch(inventoryListProvider),
              onRetry: () => ref.invalidate(inventoryListProvider),
              data: (items) {
                final list = _onlyLow
                    ? items.where((e) => e.isLow || e.isOutOfStock).toList()
                    : items;
                if (list.isEmpty) {
                  return const EmptyView(message: 'Không có SKU nào');
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = list[i];
                    final color = item.isOutOfStock
                        ? scheme.error
                        : item.isLow
                        ? scheme.tertiary
                        : null;
                    return ListTile(
                      title: Text(item.productName),
                      subtitle: Text(
                        '${item.variantName ?? ''} · ${item.skuCode}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Có thể bán: ${item.available}',
                            style: TextStyle(color: color),
                          ),
                          Text(
                            'Tồn ${item.quantityOnHand} · giữ ${item.reservedQuantity}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      onTap: () => _adjust(item),
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

class _AdjustDialog extends StatefulWidget {
  const _AdjustDialog({required this.item});

  final InventoryItem item;

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _ctrl = TextEditingController(
    text: '${widget.item.quantityOnHand}',
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Đặt lại tồn: ${widget.item.skuCode}'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Số lượng tồn mới'),
          validator: Validators.nonNegativeInt,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, int.parse(_ctrl.text.trim()));
            }
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
