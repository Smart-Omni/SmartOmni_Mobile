import 'package:flutter/material.dart';

import 'so_glass.dart';
import 'so_text.dart';
import 'so_tokens.dart';

/// Ô chỉ số trên màn Tổng quan: nhãn footnote + số metricSm + ghi chú.
/// Thẻ đặc; ô nổi bật ([highlighted], tối đa một ô mỗi màn) là kính regular.
class SoStatTile extends StatelessWidget {
  const SoStatTile({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.attention = false,
    this.onTap,
    this.highlighted = false,
  });

  final String label;

  /// Đã định dạng sẵn, vd. "12", "3,87 tr".
  final String value;
  final String? note;

  /// `true`: ghi chú màu warning (cần chú ý).
  final bool attention;
  final VoidCallback? onTap;

  /// `true`: ô nổi bật bằng SoGlass regular (vd. Doanh thu hôm nay ở M-10).
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    // Material chỉ để có hiệu ứng nhấn; nền + bóng do lớp ngoài vẽ.
    final inner = Material(
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
                    // muted không đặt trên kính regular, dùng ink2.
                    color: attention
                        ? c.warning
                        : highlighted
                        ? c.ink2
                        : c.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return highlighted
        ? SoGlass(borderRadius: SoRadius.lgAll, child: inner)
        : DecoratedBox(decoration: SoShape.card(c), child: inner);
  }
}
