import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../customer_shop/presentation/customer_shop_providers.dart';
import '../data/loyalty_mock_repository.dart';
import '../domain/loyalty_repository.dart';

/// Backend chưa có API -> luôn dùng mock, kể cả khi USE_MOCK=false.
/// Khi có API: tạo `LoyaltyRemoteRepository` và chọn theo `appConfigProvider`
/// giống các feature khác. Tạo lại theo từng phiên đăng nhập (như cửa hàng).
final loyaltyRepositoryProvider = Provider<LoyaltyRepository>((ref) {
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
