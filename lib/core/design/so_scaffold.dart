import 'package:flutter/material.dart';

import 'so_ambient_background.dart';
import 'so_app_bar.dart';
import 'so_tokens.dart';

/// Khung màn dùng chung: nền loang + `CustomScrollView` với [appBar] ghim ở
/// đầu, [slivers] là nội dung, và khoảng chừa ở cuối.
///
/// Khoảng chừa cuối = `MediaQuery.padding.bottom` đọc **bên trong** Scaffold
/// + 16. Trong khung có thanh tab nổi (Scaffold ngoài đặt `extendBody`) số
/// này đã gồm thanh tab 64 + lề 12 + vùng an toàn; màn con có [bottomBar]
/// thì Scaffold đã trừ phần thanh, chỉ còn 16.
///
/// [bottomBar]: thanh hành động kính (`SoActionBar`) của màn con.
/// [onRefresh]: kéo xuống để tải lại.
/// [scrollable]: `false` khi nội dung là skeleton (không cho cuộn).
class SoScaffold extends StatelessWidget {
  const SoScaffold({
    super.key,
    required this.appBar,
    required this.slivers,
    this.bottomBar,
    this.onRefresh,
    this.scrollable = true,
  });

  final SoAppBar appBar;
  final List<Widget> slivers;
  final Widget? bottomBar;
  final RefreshCallback? onRefresh;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return SoAmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: bottomBar,
        body: Builder(
          builder: (context) {
            final padding = MediaQuery.paddingOf(context);
            Widget view = CustomScrollView(
              physics: scrollable
                  ? const AlwaysScrollableScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              slivers: [
                appBar,
                ...slivers,
                SliverToBoxAdapter(
                  child: SizedBox(height: padding.bottom + SoSpace.s16),
                ),
              ],
            );
            if (onRefresh != null) {
              view = RefreshIndicator(
                edgeOffset: padding.top + appBar.pinnedHeight,
                onRefresh: onRefresh!,
                child: view,
              );
            }
            return view;
          },
        ),
      ),
    );
  }
}
