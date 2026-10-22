import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../data/marketplace_repositories.dart';
import '../domain/marketplace_connection.dart';

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final mock = MarketplaceMockRepository();
  return config.useMock
      ? mock
      : MarketplaceRemoteRepository(ref.watch(dioProvider), mock);
});

final connectionsProvider =
    FutureProvider.autoDispose<List<MarketplaceConnection>>(
      (ref) => ref.watch(marketplaceRepositoryProvider).listConnections(),
    );
