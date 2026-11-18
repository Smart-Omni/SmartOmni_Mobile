import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/api_availability.dart';
import '../../../app/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/account_repositories.dart';
import '../domain/account_repository.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return ref.watch(appConfigProvider).usesRemote(ApiFeature.account)
      ? AccountRemoteRepository(ref.watch(dioProvider))
      : AccountMockRepository(
          session: ref.watch(currentSessionProvider),
          store: ref.watch(mockAccountStoreProvider),
        );
});

/// Hồ sơ cho thẻ M-50 / C-40. Đổi tài khoản thì tải lại.
final accountProfileProvider = FutureProvider.autoDispose<AccountProfile>((
  ref,
) {
  ref.watch(currentSessionProvider.select((s) => s?.userId));
  return ref.watch(accountRepositoryProvider).getProfile();
});
