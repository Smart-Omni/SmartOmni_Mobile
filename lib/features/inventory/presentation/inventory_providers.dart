import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/api_availability.dart';
import '../../../app/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../data/inventory_repositories.dart';
import '../domain/inventory_item.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final mock = InventoryMockRepository();
  return ref.watch(inventoryUseRemoteProvider)
      ? InventoryRemoteRepository(ref.watch(dioProvider), mock)
      : mock;
});

/// `false`: đặt lại tồn là mẫu. Danh sách tồn luôn là mẫu (chưa có API).
final inventoryUseRemoteProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).usesRemote(ApiFeature.inventory),
);

/// ⚠️ Backend chưa có API danh sách tồn kho -> luôn là dữ liệu mẫu.
final inventoryListProvider = FutureProvider.autoDispose<List<InventoryItem>>(
  (ref) => ref.watch(inventoryRepositoryProvider).listInventory(),
);
