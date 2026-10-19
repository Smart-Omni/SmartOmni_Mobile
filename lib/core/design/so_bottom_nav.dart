import 'package:flutter/material.dart';

import 'so_glass.dart';
import 'so_text.dart';
import 'so_tokens.dart';

class SoNavItem {
  const SoNavItem({required this.icon, required this.label, this.key});

  final IconData icon;
  final String label;
  final Key? key;
}

/// Thanh tab kính nổi (docs/DESIGN.md bản 2, mục 5): capsule kính regular
/// cao 64, cách mép trái/phải 16 và mép dưới 12 (cộng safe area). Mục đang
/// chọn: viên brandTint sau icon, icon + chữ màu brand; mục khác màu ink2.
///
/// Scaffold chứa thanh này đặt `extendBody: true` để nội dung cuộn dưới kính;
/// danh sách chừa chỗ ở cuối bằng `SoSpace.scrollable`.
class SoBottomNav extends StatelessWidget {
  const SoBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<SoNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SoSpace.s16,
        0,
        SoSpace.s16,
        SoSpace.s12 + bottom,
      ),
      child: SoGlass(
        borderRadius: SoRadius.capsuleAll,
        padding: const EdgeInsets.symmetric(horizontal: SoSpace.s4),
        child: SizedBox(
          height: SoSize.bottomNav,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    key: items[i].key,
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SoNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final fg = selected ? c.brand : c.ink2;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: SoMotion.normal,
              curve: SoMotion.curve,
              width: 52,
              height: 30,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: selected
                    ? c.brandTint
                    : c.brandTint.withValues(alpha: 0),
                shape: SoShape.squircle(SoRadius.capsuleAll),
              ),
              child: Icon(item.icon, size: SoSize.iconNav, color: fg),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelSmall?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
