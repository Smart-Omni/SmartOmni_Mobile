import 'package:flutter/material.dart';

import 'so_tokens.dart';

/// Hàng [SoFilterChip] cuộn ngang, lề màn 16. Dùng làm `bottom` của
/// `SoAppBar` (nằm chung tấm kính với thanh), vd. M-20, M-60.
class SoChipBar extends StatelessWidget implements PreferredSizeWidget {
  const SoChipBar({super.key, required this.chips});

  final List<Widget> chips;

  static const double height = SoSize.chip + SoSpace.s12 * 2;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: SoSpace.screen,
          vertical: SoSpace.s12,
        ),
        child: Row(
          children: [
            for (final (i, chip) in chips.indexed) ...[
              if (i > 0) const SizedBox(width: SoSpace.s8),
              chip,
            ],
          ],
        ),
      ),
    );
  }
}
