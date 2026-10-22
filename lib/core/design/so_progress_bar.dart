import 'package:flutter/material.dart';

import 'so_text.dart';
import 'so_tokens.dart';

/// Thanh capsule cao 8: rãnh + phần đã đạt (vd. tiến tới hạng ở C-20, mức đã
/// dùng hạn mức ở T-40).
///
/// - [value]: 0…1 (ngoài khoảng thì kẹp lại).
/// - [color]: màu phần đã đạt, mặc định brand.
/// - [onGlass]: rãnh `fillStrong` thay vì `fill` để còn thấy trên nền kính.
/// - [semanticsLabel]: đọc cho trình đọc màn hình (đừng để màu tự nói).
class SoProgressBar extends StatelessWidget {
  const SoProgressBar({
    super.key,
    required this.value,
    this.color,
    this.onGlass = false,
    this.semanticsLabel,
  });

  final double value;
  final Color? color;
  final bool onGlass;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final shape = SoShape.squircle(SoRadius.capsuleAll);
    return Semantics(
      label: semanticsLabel,
      child: Container(
        height: 8,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: onGlass ? c.fillStrong : c.fill,
          shape: shape,
        ),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          heightFactor: 1,
          child: DecoratedBox(
            decoration: ShapeDecoration(color: color ?? c.brand, shape: shape),
          ),
        ),
      ),
    );
  }
}
