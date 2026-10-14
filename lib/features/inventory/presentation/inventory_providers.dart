import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../data/inventory_repositories.dart';
import '../domain/inventory_item.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final mock = InventoryMockRepository();
  return config.useMock
      ? mock
      : InventoryRemoteRepository(ref.watch(dioProvider), mock);
});

/// ⚠️ Backend chưa có API danh sách tồn kho -> luôn là dữ liệu mẫu.
final inventoryListProvider = FutureProvider.autoDispose<List<InventoryItem>>(
  (ref) => ref.watch(inventoryRepositoryProvider).listInventory(),
);
