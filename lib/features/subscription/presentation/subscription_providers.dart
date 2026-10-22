import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock.dart';
import '../data/subscription_mock_repository.dart';
import '../domain/subscription.dart';

/// Chỉ có Mock: backend chưa có API gói SaaS.
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => SubscriptionMockRepository(clock: ref.watch(clockProvider)),
);

final subscriptionOverviewProvider =
    FutureProvider.autoDispose<SubscriptionOverview>(
      (ref) => ref.watch(subscriptionRepositoryProvider).overview(),
    );
