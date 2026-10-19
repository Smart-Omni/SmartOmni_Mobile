import 'package:flutter/material.dart';

import 'so_glass.dart';
import 'so_tokens.dart';

/// Thanh hành động kính dưới đáy màn con (đặt ở
/// `Scaffold.bottomNavigationBar`).
///
/// Tối đa 2 nút: nút phụ chiếm 1 phần, nút chính 2 phần.
class SoActionBar extends StatelessWidget {
  const SoActionBar({super.key, this.primary, this.secondary});

  /// Thường là `SoButton`.
  final Widget? primary;

  /// Thường là `SoButton.secondary`.
  final Widget? secondary;

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
          child: Row(
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
