import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/api_availability.dart';
import '../../../app/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/subscription_mock_repository.dart';
import '../data/subscription_remote_repository.dart';
import '../domain/subscription.dart';

/// `true`: T-40 gọi `/api/v1/tenants/subscription/*`, chỉ phần hạn mức hiện
/// `SoMockBanner`. `false`: cả màn là dữ liệu mẫu.
final subscriptionUseRemoteProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).usesRemote(ApiFeature.subscription),
);

/// Tạo lại theo từng phiên đăng nhập (mock giữ trạng thái đã thanh toán
/// trong phiên). Hạn mức luôn lấy từ mock (lỗi P3).
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  ref.watch(currentSessionProvider.select((s) => s?.userId));
  final clock = ref.watch(clockProvider);
  final mock = SubscriptionMockRepository(clock: clock);
  return ref.watch(subscriptionUseRemoteProvider)
      ? SubscriptionRemoteRepository(
          ref.watch(dioProvider),
          usage: mock,
          clock: clock,
        )
      : mock;
});

final subscriptionStatusProvider =
    FutureProvider.autoDispose<SubscriptionSummary>(
      (ref) => ref.watch(subscriptionRepositoryProvider).status(),
    );

final subscriptionInvoicesProvider = FutureProvider.autoDispose<List<Invoice>>(
  (ref) => ref.watch(subscriptionRepositoryProvider).invoices(),
);

final subscriptionUsageProvider = FutureProvider.autoDispose<PlanUsage>(
  (ref) => ref.watch(subscriptionRepositoryProvider).usage(),
);
