import 'package:flutter/material.dart';

import 'so_text.dart';
import 'so_tokens.dart';

class SoSegment<T> {
  const SoSegment({required this.value, required this.label});

  final T value;
  final String label;
}

/// Nút chuyển đổi: rãnh surfaceSunken, mục đang chọn nền trắng viền line.
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
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: SoRadius.smAll,
      ),
      child: Row(
        children: [
          for (final s in segments)
            Expanded(
              child: Semantics(
                selected: s.value == selected,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(s.value),
                  child: Container(
                    height: SoSize.controlSmall,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: SoSpace.s8),
                    decoration: s.value == selected
                        ? BoxDecoration(
                            color: c.surface,
                            borderRadius: SoRadius.xsAll,
                            border: Border.all(color: c.line),
                          )
                        : null,
                    child: Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelLarge?.copyWith(
                        color: s.value == selected ? c.ink : c.ink2,
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
