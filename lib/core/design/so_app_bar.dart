import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'so_text.dart';
import 'so_tokens.dart';

/// AppBar nền trắng, viền dưới line.
///
/// - Tab gốc ([SoAppBar.root]): tiêu đề title-lg + dòng phụ mono, không nút back.
/// - Màn con ([SoAppBar.new]): nút back + tiêu đề title-md.
class SoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SoAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onBack,
  }) : isRoot = false;

  const SoAppBar.root({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  }) : isRoot = true,
       onBack = null;

  final String title;

  /// Dòng phụ chữ mono, vd. "Shop Demo · Nhân viên" hoặc mã đơn.
  final String? subtitle;
  final List<Widget> actions;
  final bool isRoot;

  /// Mặc định: `Navigator.maybePop`.
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(SoSize.appBar);

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final titleStyle = isRoot
        ? context.textTheme.titleLarge
        : context.textTheme.titleMedium;
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: isRoot ? SoSpace.screen : 0,
      leading: isRoot
          ? null
          : IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(LucideIcons.chevronLeft),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.soText.code.copyWith(color: c.muted),
            ),
        ],
      ),
      actions: [
        ...actions,
        const SizedBox(width: SoSpace.s4),
      ],
    );
  }
}
