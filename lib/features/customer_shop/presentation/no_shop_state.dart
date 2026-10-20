import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';

/// Khách chưa tham gia cửa hàng nào (C-10, C-20, C-30): mời mở C-00 để thêm.
class NoShopState extends StatelessWidget {
  const NoShopState({super.key});

  @override
  Widget build(BuildContext context) {
    return SoEmptyState(
      key: const Key('no_shop'),
      icon: LucideIcons.store,
      title: 'Bạn chưa tham gia cửa hàng nào',
      message: 'Nhập mã cửa hàng để xem sản phẩm và tích điểm.',
      actionLabel: 'Thêm cửa hàng',
      onAction: () => context.push(Routes.customerShops),
    );
  }
}
