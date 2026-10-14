import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'so_text.dart';
import 'so_tokens.dart';

/// Logo SmartOmni từ `assets/brand/`.
///
/// Mặc định là logo ngang: mark + chữ "Smart" (ink) "Omni" (brand).
class SoLogo extends StatelessWidget {
  const SoLogo({super.key, this.height = 32, this.showWordmark = true});

  /// Chỉ hình mark, không chữ.
  const SoLogo.mark({super.key, this.height = 32}) : showWordmark = false;

  final double height;
  final bool showWordmark;

  static const markAsset = 'assets/brand/smartomni-mark.svg';

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    // viewBox của mark là 100×80.
    final mark = SvgPicture.asset(
      markAsset,
      height: height,
      width: height * 100 / 80,
      semanticsLabel: showWordmark ? null : 'SmartOmni',
    );
    if (!showWordmark) return mark;

    final style = context.textTheme.titleLarge;
    return Semantics(
      label: 'SmartOmni',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          const SizedBox(width: SoSpace.s8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Smart',
                  style: style?.copyWith(color: c.ink),
                ),
                TextSpan(
                  text: 'Omni',
                  style: style?.copyWith(color: c.brand),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
