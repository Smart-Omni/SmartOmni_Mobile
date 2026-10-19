import 'package:flutter/material.dart';

import 'so_text.dart';
import 'so_tokens.dart';

/// Ô chỉ số trên màn Tổng quan: nhãn footnote + số metricSm + ghi chú.
class SoStatTile extends StatelessWidget {
  const SoStatTile({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.attention = false,
    this.onTap,
  });

  final String label;

  /// Đã định dạng sẵn, vd. "12", "3,87 tr".
  final String value;
  final String? note;

  /// `true`: ghi chú màu warning (cần chú ý).
  final bool attention;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    // Bóng thẻ vẽ ở DecoratedBox ngoài; Material chỉ để có hiệu ứng nhấn.
    return DecoratedBox(
      decoration: SoShape.card(c),
      child: Material(
        type: MaterialType.transparency,
        shape: SoShape.squircle(SoRadius.lgAll),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: SoSpace.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.soColors.ink2,
                  ),
                ),
                const SizedBox(height: SoSpace.s8),
                Text(value, maxLines: 1, style: context.soText.metricSm),
                if (note != null) ...[
                  const SizedBox(height: SoSpace.s4),
                  Text(
                    note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: attention ? c.warning : c.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
