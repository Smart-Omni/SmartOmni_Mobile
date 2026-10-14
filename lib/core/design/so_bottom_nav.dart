import 'package:flutter/material.dart';

import 'so_text.dart';
import 'so_tokens.dart';

class SoNavItem {
  const SoNavItem({required this.icon, required this.label, this.key});

  final IconData icon;
  final String label;
  final Key? key;
}

/// Thanh điều hướng dưới cao 64. Mục đang chọn có ô 56×28 nền brandTint.
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
    final c = context.soColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
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
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? c.brandTint : null,
                borderRadius: SoRadius.smAll,
              ),
              child: Icon(item.icon, size: SoSize.icon, color: fg),
            ),
            const SizedBox(height: SoSpace.s4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.soText.navLabel.copyWith(
                color: selected ? c.ink : c.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
