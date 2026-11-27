import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/api_availability.dart';
import '../../../app/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../customer_shop/presentation/customer_shop_providers.dart';
import '../data/loyalty_mock_repository.dart';
import '../data/loyalty_remote_repository.dart';
import '../domain/loyalty_repository.dart';

/// `true`: C-20 (thẻ hạng, lịch sử, voucher) gọi `/api/v1/loyalty/me*`.
/// `false`: dữ liệu mẫu, C-20 hiện `SoMockBanner`.
final loyaltyUseRemoteProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).usesRemote(ApiFeature.loyalty),
);

/// Tạo lại theo từng phiên đăng nhập (như cửa hàng). BE thật: C-20 và C-30
/// (claim đơn) đều gọi `/api/v1/loyalty/*`.
final loyaltyRepositoryProvider = Provider<LoyaltyRepository>((ref) {
  if (ref.watch(loyaltyUseRemoteProvider)) {
    return LoyaltyRemoteRepository(ref.watch(dioProvider));
  }
  final session = ref.watch(currentSessionProvider);
  final registered = ref.read(mockAccountStoreProvider).find(session?.email);
  return LoyaltyMockRepository(demoData: registered == null);
});

/// Điểm và lịch sử của khách tại cửa hàng đang xem.
final loyaltySummaryProvider = FutureProvider.autoDispose<LoyaltySummary>((
  ref,
) async {
  final shop = await ref.watch(currentShopProvider.future);
  if (shop == null) return const LoyaltySummary(totalPoints: 0, history: []);
  return ref.watch(loyaltyRepositoryProvider).getSummary(shop.tenantId);
});

/// Voucher của khách tại cửa hàng đang xem.
final vouchersProvider = FutureProvider.autoDispose<List<CustomerVoucher>>((
  ref,
) async {
  final shop = await ref.watch(currentShopProvider.future);
  if (shop == null) return const [];
  return ref.watch(loyaltyRepositoryProvider).getVouchers(shop.tenantId);
});
