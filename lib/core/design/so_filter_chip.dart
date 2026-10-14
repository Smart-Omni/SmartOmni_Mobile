import 'package:flutter/material.dart';

import 'so_text.dart';
import 'so_tokens.dart';

/// Chip lọc cao 36. Đang chọn: nền ink, chữ trắng. Có thể kèm số đếm mono.
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
    final fg = selected ? c.surface : c.ink;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.ink : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: SoRadius.smAll,
          side: BorderSide(color: selected ? c.ink : c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelected,
          child: Container(
            height: SoSize.controlSmall,
            padding: const EdgeInsets.symmetric(horizontal: SoSpace.s12),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: context.textTheme.labelLarge?.copyWith(color: fg),
                ),
                if (count != null) ...[
                  const SizedBox(width: SoSpace.s8),
                  Text(
                    '$count',
                    style: context.soText.code.copyWith(
                      color: selected ? c.line : c.muted,
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
