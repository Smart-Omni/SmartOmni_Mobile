import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock.dart';
import '../data/support_mock_repository.dart';
import '../domain/support.dart';

/// Chỉ có Mock: chưa có API yêu cầu hỗ trợ trong hợp đồng.
final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => SupportMockRepository(clock: ref.watch(clockProvider)),
);

final supportTicketsProvider = FutureProvider.autoDispose<List<SupportTicket>>(
  (ref) => ref.watch(supportRepositoryProvider).list(),
);
