import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/loyalty_mock_repository.dart';
import '../domain/loyalty_repository.dart';

/// Backend chưa có API -> luôn dùng mock, kể cả khi USE_MOCK=false.
/// Khi có API: tạo `LoyaltyRemoteRepository` và chọn theo `appConfigProvider`
/// giống các feature khác.
final loyaltyRepositoryProvider = Provider<LoyaltyRepository>(
  (ref) => LoyaltyMockRepository(),
);

final loyaltySummaryProvider = FutureProvider.autoDispose<LoyaltySummary>(
  (ref) => ref.watch(loyaltyRepositoryProvider).getSummary(),
);

final vouchersProvider = FutureProvider.autoDispose<List<CustomerVoucher>>(
  (ref) => ref.watch(loyaltyRepositoryProvider).getVouchers(),
);
