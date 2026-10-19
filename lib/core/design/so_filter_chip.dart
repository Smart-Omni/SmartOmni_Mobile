import 'package:flutter/material.dart';

import 'so_text.dart';
import 'so_tokens.dart';

/// Chip lọc: capsule cao 34. Chưa chọn: nền `fill`, chữ ink2. Đang chọn:
/// nền ink, chữ trắng. Số đếm cùng dòng, độ đậm 400.
class SoFilterChip extends StatelessWidget {
  const SoFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback? onSelected;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final fg = selected ? c.surface : c.ink2;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.ink : c.fill,
        shape: SoShape.squircle(SoRadius.capsuleAll),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelected,
          child: Container(
            height: SoSize.chip,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: context.textTheme.labelLarge?.copyWith(color: fg),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: context.textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w400,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
