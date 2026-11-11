import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/api_availability.dart';
import '../../../app/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../data/marketplace_repositories.dart';
import '../domain/marketplace_connection.dart';

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  final mock = MarketplaceMockRepository();
  return ref.watch(marketplaceUseRemoteProvider)
      ? MarketplaceRemoteRepository(ref.watch(dioProvider), mock)
      : mock;
});

/// `false`: kết nối bằng App Key là mẫu. Danh sách, ngắt kết nối, tự nhập
/// luôn là mẫu (chưa có API).
final marketplaceUseRemoteProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).usesRemote(ApiFeature.marketplace),
);

final connectionsProvider =
    FutureProvider.autoDispose<List<MarketplaceConnection>>(
      (ref) => ref.watch(marketplaceRepositoryProvider).listConnections(),
    );
