import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'so_glass.dart';
import 'so_text.dart';
import 'so_tokens.dart';

/// Viên kính mỏng đổi cửa hàng ở đầu C-10 / C-20 / C-30 (DESIGN.md mục 8b):
/// logo tròn 32 + tên cửa hàng + mũi tên xuống. Bấm để mở C-00.
class SoShopSwitcher extends StatelessWidget {
  const SoShopSwitcher({super.key, required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Semantics(
      button: true,
      label: 'Cửa hàng đang xem: $name. Đổi cửa hàng',
      excludeSemantics: true,
      // Vùng chạm tối thiểu 48 quanh viên cao 40.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: SoSize.touch),
        child: Center(
          widthFactor: 1,
          child: SoGlass(
            level: SoGlassLevel.thin,
            borderRadius: SoRadius.capsuleAll,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                customBorder: SoShape.squircle(SoRadius.capsuleAll),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SoSpace.s4,
                    SoSpace.s4,
                    SoSpace.s12,
                    SoSpace.s4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SoShopLogo(name: name, size: 32),
                      const SizedBox(width: SoSpace.s8),
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: SoSpace.s4),
                      Icon(
                        LucideIcons.chevronDown,
                        size: SoSize.iconSmall,
                        color: c.ink2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo tròn của cửa hàng. Chưa có ảnh logo (backend chưa trả) nên vẽ chữ
/// cái đầu của tên trên nền brandTint.
class SoShopLogo extends StatelessWidget {
  const SoShopLogo({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.brandTint, shape: BoxShape.circle),
      child: Text(
        initial,
        style:
            (size >= 40
                    ? context.textTheme.titleMedium
                    : context.textTheme.labelLarge)
                ?.copyWith(color: c.brand),
      ),
    );
  }
}
