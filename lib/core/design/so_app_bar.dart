import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'so_glass.dart';
import 'so_text.dart';
import 'so_tokens.dart';

/// AppBar kính (docs/DESIGN.md bản 2, mục 5).
///
/// - Màn gốc ([SoAppBar.root]): tiêu đề lớn `largeTitle` + dòng phụ
///   `footnote`. Khi nội dung cuộn, tiêu đề lớn thu lại, thanh còn 52 với
///   tiêu đề `headline` ở giữa.
/// - Màn con ([SoAppBar.new]): nút back tròn 36 nền `fill` + tiêu đề
///   `headline` (+ dòng phụ mono, vd. mã đơn).
///
/// Ở đầu trang thanh trong suốt; khi nội dung cuộn xuống dưới thì chuyển
/// sang kính mỏng. Để nội dung chạy được dưới kính, Scaffold đặt
/// `extendBodyBehindAppBar: true` và danh sách dùng `SoSpace.scrollable`.
///
/// [bottom]: phần dính dưới thanh (hàng chip lọc, ô tìm), nằm chung tấm kính.
class SoAppBar extends StatefulWidget implements PreferredSizeWidget {
  const SoAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onBack,
    this.bottom,
  }) : isRoot = false;

  const SoAppBar.root({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.bottom,
  }) : isRoot = true,
       onBack = null;

  final String title;

  /// Màn gốc: dòng phụ dưới tiêu đề lớn, vd. "Shop Demo · Nhân viên".
  /// Màn con: dòng mono dưới tiêu đề, vd. mã đơn.
  final String? subtitle;
  final List<Widget> actions;
  final bool isRoot;

  /// Mặc định: `Navigator.maybePop`.
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;

  /// Chiều cao khối tiêu đề lớn (chỉ màn gốc): chữ 40 + dòng phụ 18 + lề.
  double get _largeTitleHeight =>
      isRoot ? 40 + (subtitle != null ? 18 : 0) + SoSpace.s8 : 0;

  @override
  Size get preferredSize => Size.fromHeight(
    SoSize.appBar + _largeTitleHeight + (bottom?.preferredSize.height ?? 0),
  );

  @override
  State<SoAppBar> createState() => _SoAppBarState();
}

class _SoAppBarState extends State<SoAppBar> {
  ScrollNotificationObserverState? _observer;

  /// Độ cuộn của danh sách chính, kẹp trong [0, chiều cao tiêu đề lớn + 1].
  double _offset = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observer?.removeListener(_onScroll);
    _observer = ScrollNotificationObserver.maybeOf(context);
    _observer?.addListener(_onScroll);
  }

  @override
  void dispose() {
    _observer?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll(ScrollNotification n) {
    // Chỉ danh sách dọc trực tiếp trong body (bỏ hàng chip cuộn ngang).
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return;
    final offset = n.metrics.pixels.clamp(0.0, widget._largeTitleHeight + 1);
    if (offset != _offset) setState(() => _offset = offset);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final top = MediaQuery.paddingOf(context).top;
    final large = widget._largeTitleHeight;
    final bottomHeight = widget.bottom?.preferredSize.height ?? 0;

    // collapse: phần tiêu đề lớn đã thu (0 → large).
    final collapse = _offset.clamp(0.0, large);
    final progress = large == 0 ? 1.0 : collapse / large;
    final scrolled = _offset > 0;
    final barHeight = top + SoSize.appBar + large - collapse + bottomHeight;

    final smallTitleOpacity = widget.isRoot
        ? ((progress - 0.7) / 0.3).clamp(0.0, 1.0)
        : 1.0;

    return SizedBox(
      height: top + widget.preferredSize.height,
      child: Stack(
        children: [
          // Nền kính: chỉ phủ phần thanh đang hiện, chặn chạm vào nội dung
          // đang nằm dưới kính.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: barHeight,
            child: AnimatedOpacity(
              opacity: scrolled ? 1 : 0,
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
          Positioned(
            top: top,
            left: 0,
            right: 0,
            height: SoSize.appBar,
            child: _Toolbar(
              title: widget.title,
              subtitle: widget.isRoot ? null : widget.subtitle,
              isRoot: widget.isRoot,
              titleOpacity: smallTitleOpacity,
              actions: widget.actions,
              onBack: widget.onBack,
            ),
          ),
          if (widget.isRoot)
            Positioned(
              top: top + SoSize.appBar,
              left: 0,
              right: 0,
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
                        title: widget.title,
                        subtitle: widget.subtitle,
                        subtitleColor: c.ink2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (widget.bottom != null)
            Positioned(
              top: top + SoSize.appBar + large - collapse,
              left: 0,
              right: 0,
              height: bottomHeight,
              child: widget.bottom!,
            ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.title,
    required this.subtitle,
    required this.isRoot,
    required this.titleOpacity,
    required this.actions,
    required this.onBack,
  });

  final String title;
  final String? subtitle;
  final bool isRoot;
  final double titleOpacity;
  final List<Widget> actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.titleMedium,
    );

    // Màn gốc: tiêu đề nhỏ chỉ có trong cây khi đã thu, để không trùng chữ
    // với tiêu đề lớn (đọc màn hình, finder trong test).
    final Widget? center = isRoot
        ? (titleOpacity > 0
              ? Opacity(
                  opacity: titleOpacity,
                  child: Center(child: titleText),
                )
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
                  style: context.soText.code.copyWith(color: c.ink2),
                ),
            ],
          );

    return NavigationToolbar(
      leading: isRoot
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: SoSpace.s4),
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                style: IconButton.styleFrom(
                  backgroundColor: c.fill,
                  foregroundColor: c.ink,
                  fixedSize: const Size.square(SoSize.controlSmall),
                  minimumSize: const Size.square(SoSize.controlSmall),
                  shape: SoShape.squircle(SoRadius.capsuleAll),
                ),
                icon: const Icon(
                  LucideIcons.chevronLeft,
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
