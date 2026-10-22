import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock.dart';
import '../data/voucher_mock_repository.dart';
import '../domain/voucher.dart';

/// Chỉ có Mock: backend chưa có API phát voucher.
final voucherRepositoryProvider = Provider<VoucherRepository>(
  (ref) => VoucherMockRepository(clock: ref.watch(clockProvider)),
);

final voucherSetupProvider = FutureProvider.autoDispose<VoucherSetup>(
  (ref) => ref.watch(voucherRepositoryProvider).setup(),
);

final voucherBatchesProvider = FutureProvider.autoDispose<List<VoucherBatch>>(
  (ref) => ref.watch(voucherRepositoryProvider).recentBatches(),
);
