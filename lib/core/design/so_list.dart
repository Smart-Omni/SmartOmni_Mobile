import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'so_tags.dart';
import 'so_text.dart';
import 'so_tokens.dart';

/// Nhóm danh sách: thẻ trắng bo 12, viền line, các hàng ngăn bằng đường chia.
class SoListGroup extends StatelessWidget {
  const SoListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: SoRadius.mdAll,
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Hàng menu cao tối thiểu 48: icon + tiêu đề (+ dòng phụ) + phần cuối.
///
/// - Có [onTap] và không có [trailing]: hiện mũi tên ">".
/// - [comingSoon]: mờ đi, không bấm được, nhãn "Sắp có".
/// - [destructive]: chữ và icon màu danger (vd. Đăng xuất).
class SoListRow extends StatelessWidget {
  const SoListRow({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.comingSoon = false,
    this.destructive = false,
  });

  final String title;
  final IconData? icon;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool comingSoon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final fg = destructive
        ? c.danger
        : comingSoon
        ? c.muted
        : c.ink;
    final end =
        trailing ??
        (comingSoon
            ? const SoStatusTag(label: 'Sắp có', status: SoStatus.neutral)
            : onTap != null
            ? Icon(
                LucideIcons.chevronRight,
                size: SoSize.iconSmall,
                color: c.muted,
              )
            : null);

    return Material(
      color: c.surface,
      child: InkWell(
        onTap: comingSoon ? null : onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SoSize.touch + 8),
          child: Padding(
            padding: SoSpace.card,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: destructive ? c.danger : c.ink2),
                  const SizedBox(width: SoSpace.s12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: context.soText.bodyStrong.copyWith(color: fg),
                      ),
                      if (subtitle != null)
                        Text(subtitle!, style: context.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (end != null) ...[const SizedBox(width: SoSpace.s12), end],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
