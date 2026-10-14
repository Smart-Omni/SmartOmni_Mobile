import 'package:flutter/widgets.dart';

import '../../../core/design/design.dart';
import '../domain/inventory_item.dart';

extension StockLevelUi on StockLevel {
  /// Nhãn trạng thái, `null` khi còn hàng (không cần nhãn).
  String? get label => switch (this) {
    StockLevel.out => 'Hết hàng',
    StockLevel.low => 'Sắp hết',
    StockLevel.ok => null,
  };

  SoStatus get soStatus => switch (this) {
    StockLevel.out => SoStatus.danger,
    StockLevel.low => SoStatus.warning,
    StockLevel.ok => SoStatus.neutral,
  };

  /// Màu số "có thể bán" theo mức.
  Color numberColor(SoColors c) => switch (this) {
    StockLevel.out => c.danger,
    StockLevel.low => c.warning,
    StockLevel.ok => c.ink,
  };
}

/// Nhãn mức tồn, không vẽ gì khi còn hàng.
class StockLevelTag extends StatelessWidget {
  const StockLevelTag({super.key, required this.level});

  final StockLevel? level;

  @override
  Widget build(BuildContext context) {
    final label = level?.label;
    if (label == null) return const SizedBox.shrink();
    return SoStatusTag(label: label, status: level!.soStatus);
  }
}
