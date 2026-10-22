import 'package:flutter/material.dart';

import 'so_text.dart';
import 'so_tokens.dart';

class SoSegment<T> {
  const SoSegment({
    required this.value,
    required this.label,
    this.enabled = true,
  });

  final T value;
  final String label;

  /// `false`: chữ mờ, không chọn được (lý do ghi ở dòng help bên dưới).
  final bool enabled;
}

/// Nút chuyển đổi: rãnh capsule nền fill; mục đang chọn là viên trắng có
/// bóng thẻ, chuyển mượt.
class SoSegmented<T> extends StatelessWidget {
  const SoSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<SoSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Container(
      padding: const EdgeInsets.all(SoSpace.s4),
      decoration: ShapeDecoration(
        color: c.fill,
        shape: SoShape.squircle(SoRadius.capsuleAll),
      ),
      child: Row(
        children: [
          for (final s in segments)
            Expanded(
              child: Semantics(
                selected: s.value == selected,
                button: true,
                enabled: s.enabled,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: s.enabled ? () => onChanged(s.value) : null,
                  child: AnimatedContainer(
                    duration: SoMotion.normal,
                    curve: SoMotion.curve,
                    height: SoSize.controlSmall,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: SoSpace.s8),
                    decoration: ShapeDecoration(
                      color: s.value == selected
                          ? c.surface
                          : c.surface.withValues(alpha: 0),
                      shape: SoShape.squircle(SoRadius.capsuleAll),
                      shadows: s.value == selected
                          ? SoShadow.card(c.shadowTint)
                          : const [],
                    ),
                    child: Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelLarge?.copyWith(
                        color: !s.enabled
                            ? c.muted
                            : s.value == selected
                            ? c.ink
                            : c.ink2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
