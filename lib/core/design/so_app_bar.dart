import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/platform.dart';
import 'so_glass.dart';
import 'so_tags.dart';
import 'so_text.dart';
import 'so_tokens.dart';

/// AppBar kính (docs/DESIGN.md bản 2, mục 5), dựng thành **sliver ghim** ở
/// đầu `CustomScrollView`. Dùng qua `SoScaffold`, không đặt vào
/// `Scaffold.appBar`.
///
/// - Màn gốc ([SoAppBar.root]): tiêu đề lớn `largeTitle` + dòng phụ
///   `footnote` nằm ngay dưới thanh 52 và **cuộn đi cùng nội dung**; khi đã
///   cuộn qua, thanh còn 52 với tiêu đề `headline` ở giữa.
/// - Màn con ([SoAppBar.new]): nút back tròn 36 nền `fill` + tiêu đề
///   `headline` (+ dòng phụ mono, vd. mã đơn). [close]: nút đóng (X) thay
///   cho nút back, dùng cho màn tạo mới (vd. M-32).
///
/// Ở đầu trang thanh trong suốt; khi nội dung cuộn xuống dưới thì chuyển
/// sang kính mỏng. Nội dung luôn bắt đầu dưới thanh, chỉ trượt dưới kính khi
/// cuộn.
///
/// [bottom]: phần dính dưới thanh (hàng chip lọc, ô tìm): cuộn lên cùng tiêu
/// đề lớn rồi dính lại dưới thanh, nằm chung tấm kính.
class SoAppBar extends StatelessWidget {
  const SoAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onBack,
    this.bottom,
    this.close = false,
    this.channel,
    this.subtitleIsCode = true,
  }) : isRoot = false,
       leading = null;

  const SoAppBar.root({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.bottom,
    this.leading,
  }) : isRoot = true,
       onBack = null,
       close = false,
       channel = null,
       subtitleIsCode = false;

  final String title;

  /// Màn gốc: dòng phụ dưới tiêu đề lớn, vd. "Shop Demo · Nhân viên".
  /// Màn con: dòng mono dưới tiêu đề, vd. mã đơn.
  final String? subtitle;
  final List<Widget> actions;
  final bool isRoot;

  /// Màn con: nút đóng (X) thay cho nút back.
  final bool close;

  /// Màn con: [subtitle] là mã (chữ mono). `false`: chữ thường `footnote`,
  /// vd. "Tư vấn sản phẩm · không đặt hàng" ở C-12.
  final bool subtitleIsCode;

  /// Màn con: kênh bán (`SoChannelTag`) dưới tiêu đề, vd. tên khách ở M-61.
  final Platform? channel;

  /// Mặc định: `Navigator.maybePop`.
  final VoidCallback? onBack;

  /// Màn gốc: widget ghim bên trái thanh 52 (vd. `SoShopSwitcher` ở C-10).
  /// Có [leading] thì thanh không hiện tiêu đề nhỏ khi thu.
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  /// Chiều cao khối tiêu đề lớn (chỉ màn gốc): dòng chữ 40 + dòng phụ 18
  /// (cả hai phóng theo cỡ chữ hệ thống) + lề 8.
  double _largeTitleHeight(TextScaler scaler) => isRoot
      ? scaler.scale(40) +
            (subtitle != null ? scaler.scale(18) : 0) +
            SoSpace.s8
      : 0;

  /// Phần luôn ghim dưới vùng an toàn: thanh 52 + [bottom].
  double get pinnedHeight =>
      SoSize.appBar + (bottom?.preferredSize.height ?? 0);

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SoAppBarDelegate(
        bar: this,
        insets: MediaQuery.paddingOf(context),
        large: _largeTitleHeight(MediaQuery.textScalerOf(context)),
      ),
    );
  }
}

class _SoAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SoAppBarDelegate({
    required this.bar,
    required this.insets,
    required this.large,
  });

  final SoAppBar bar;
  final EdgeInsets insets;

  /// Chiều cao khối tiêu đề lớn (0 ở màn con).
  final double large;

  @override
  double get minExtent => insets.top + bar.pinnedHeight;

  @override
  double get maxExtent => minExtent + large;

  @override
  bool shouldRebuild(_SoAppBarDelegate old) =>
      old.bar != bar || old.insets != insets || old.large != large;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final c = context.soColors;
    final top = insets.top;
    // collapse: phần tiêu đề lớn đã cuộn đi (0 → large), đúng bằng quãng cuộn.
    final collapse = shrinkOffset.clamp(0.0, large);
    final progress = large == 0 ? 1.0 : collapse / large;
    final titleOpacity = bar.isRoot
        ? ((progress - 0.7) / 0.3).clamp(0.0, 1.0)
        : 1.0;
    final glassOn = shrinkOffset > 0 || overlaps;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Kính chỉ hiện khi đã cuộn (nội dung bắt đầu trượt dưới thanh).
        Positioned.fill(
          child: AnimatedOpacity(
            opacity: glassOn ? 1 : 0,
            duration: SoMotion.fast,
            curve: SoMotion.curve,
            child: const SoGlass(
              level: SoGlassLevel.thin,
              borderRadius: BorderRadius.zero,
              shadow: false,
              child: SizedBox.expand(),
            ),
          ),
        ),
        // Né tai thỏ / vùng cong khi xoay ngang.
        Positioned(
          top: top,
          left: insets.left,
          right: insets.right,
          height: SoSize.appBar,
          // Thanh đã thành kính: kính bên trong thanh (vd. SoShopSwitcher) vẽ
          // nền đặc để không có kính chồng lên kính.
          child: SoGlassScope(
            enabled: SoGlassScope.enabledOf(context) && !glassOn,
            child: _Toolbar(
              title: bar.title,
              subtitle: bar.isRoot ? null : bar.subtitle,
              channel: bar.channel,
              subtitleIsCode: bar.subtitleIsCode,
              isRoot: bar.isRoot,
              close: bar.close,
              titleOpacity: titleOpacity,
              actions: bar.actions,
              onBack: bar.onBack,
              leading: bar.leading,
            ),
          ),
        ),
        // Tiêu đề lớn bám mép dưới vùng đang thu, nên đi lên đúng bằng quãng
        // cuộn như một phần của nội dung.
        if (bar.isRoot && collapse < large)
          Positioned(
            top: top + SoSize.appBar,
            left: insets.left,
            right: insets.right,
            height: large - collapse,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.bottomLeft,
                minHeight: large,
                maxHeight: large,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 1 - progress,
                    child: _LargeTitle(
                      title: bar.title,
                      subtitle: bar.subtitle,
                      subtitleColor: c.ink2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (bar.bottom != null)
          Positioned(
            top: top + SoSize.appBar + large - collapse,
            left: insets.left,
            right: insets.right,
            height: bar.bottom!.preferredSize.height,
            child: bar.bottom!,
          ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.title,
    required this.subtitle,
    required this.channel,
    required this.subtitleIsCode,
    required this.isRoot,
    required this.close,
    required this.titleOpacity,
    required this.actions,
    required this.onBack,
    required this.leading,
  });

  final String title;
  final String? subtitle;
  final Platform? channel;
  final bool subtitleIsCode;
  final bool isRoot;
  final bool close;
  final double titleOpacity;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    // Màn gốc có leading: viên bên trái (co lại khi chật) + nút bên phải,
    // không có tiêu đề nhỏ.
    if (leading case final leading?) {
      return Row(
        children: [
          const SizedBox(width: SoSpace.screen),
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: leading),
          ),
          ...actions,
          const SizedBox(width: SoSpace.s4),
        ],
      );
    }
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.titleMedium,
    );

    // Màn gốc: tiêu đề nhỏ chỉ có trong cây khi đã thu, để không trùng chữ
    // với tiêu đề lớn (đọc màn hình, finder trong test). Không bọc Center:
    // NavigationToolbar tự căn giữa theo cả bề rộng thanh, kể cả khi bên phải
    // có nút.
    final Widget? center = isRoot
        ? (titleOpacity > 0
              ? Opacity(opacity: titleOpacity, child: titleText)
              : null)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              titleText,
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: subtitleIsCode
                      ? context.soText.code.copyWith(color: c.ink2)
                      : context.textTheme.bodySmall?.copyWith(color: c.ink2),
                ),
              if (channel != null) SoChannelTag(platform: channel!),
            ],
          );

    return NavigationToolbar(
      leading: isRoot
          ? null
          // Vùng chạm 48 (IconButton tự đệm 6 mỗi bên quanh viên 36): đệm
          // trái 8 để viên tròn cách mép 14, trong khoảng 12–16 của lề màn.
          : Padding(
              padding: const EdgeInsets.only(left: SoSpace.s8),
              child: IconButton(
                key: const Key('so_app_bar_leading'),
                tooltip: close
                    ? MaterialLocalizations.of(context).closeButtonTooltip
                    : MaterialLocalizations.of(context).backButtonTooltip,
                style: IconButton.styleFrom(
                  backgroundColor: c.fill,
                  foregroundColor: c.ink,
                  fixedSize: const Size.square(SoSize.controlSmall),
                  minimumSize: const Size.square(SoSize.controlSmall),
                  shape: SoShape.squircle(SoRadius.capsuleAll),
                ),
                icon: Icon(
                  close ? LucideIcons.x : LucideIcons.chevronLeft,
                  size: SoSize.iconSmall,
                ),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
            ),
      middle: center,
      centerMiddle: isRoot,
      middleSpacing: isRoot ? SoSpace.screen : SoSpace.s4,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...actions,
          const SizedBox(width: SoSpace.s4),
        ],
      ),
    );
  }
}

class _LargeTitle extends StatelessWidget {
  const _LargeTitle({
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
  });

  final String title;
  final String? subtitle;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SoSpace.screen,
        0,
        SoSpace.screen,
        SoSpace.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.headlineLarge,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                color: subtitleColor,
              ),
            ),
        ],
      ),
    );
  }
}
