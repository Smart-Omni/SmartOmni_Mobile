import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/api_availability.dart';
import '../../../app/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../data/marketplace_repositories.dart';
import '../domain/marketplace_connection.dart';

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return ref.watch(marketplaceUseRemoteProvider)
      ? MarketplaceRemoteRepository(ref.watch(dioProvider))
      : MarketplaceMockRepository();
});

/// `false`: T-10 là dữ liệu mẫu (có form App Key). `true`: trạng thái và ngắt
/// kết nối gọi BE thật; kết nối qua OAuth chưa làm; công tắc tự nhập vẫn mẫu.
final marketplaceUseRemoteProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).usesRemote(ApiFeature.marketplace),
);

final connectionsProvider =
    FutureProvider.autoDispose<List<MarketplaceConnection>>(
      (ref) => ref.watch(marketplaceRepositoryProvider).listConnections(),
    );
