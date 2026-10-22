import 'package:flutter/material.dart';

import 'so_glass.dart';
import 'so_tokens.dart';

/// Thanh hành động kính dưới đáy màn con (đặt ở
/// `Scaffold.bottomNavigationBar`).
///
/// Tối đa 2 nút: nút phụ chiếm 1 phần, nút chính 2 phần.
///
/// [stacked]: hai nút xếp chồng (chính ở trên), mỗi nút rộng hết thanh;
/// dùng khi nhãn dài không vừa 1 phần (vd. "Mua trên TikTok Shop" ở C-11).
class SoActionBar extends StatelessWidget {
  const SoActionBar({
    super.key,
    this.primary,
    this.secondary,
    this.stacked = false,
  });

  /// Thường là `SoButton`.
  final Widget? primary;

  /// Thường là `SoButton.secondary`.
  final Widget? secondary;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    return SoGlass(
      borderRadius: BorderRadius.zero,
      shadow: false,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SoSpace.screen,
            vertical: SoSpace.s12,
          ),
          child: stacked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ?primary,
                    if (secondary != null && primary != null)
                      const SizedBox(height: SoSpace.s8),
                    ?secondary,
                  ],
                )
              : Row(
                  children: [
                    if (secondary != null) Expanded(child: secondary!),
                    if (secondary != null && primary != null)
                      const SizedBox(width: SoSpace.s12),
                    if (primary != null) Expanded(flex: 2, child: primary!),
                  ],
                ),
        ),
      ),
    );
  }
}
