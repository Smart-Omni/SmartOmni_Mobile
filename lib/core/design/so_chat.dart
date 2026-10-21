import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'so_glass.dart';
import 'so_text.dart';
import 'so_tokens.dart';

/// Màu nền của bong bóng chat.
enum SoChatTone {
  /// Bên mình: brand; bên kia: thẻ trắng.
  normal,

  /// Thẻ trắng, chữ ink2: nội dung không xem được.
  muted,

  /// Nền warningTint: câu trả lời dự phòng của trợ lý (C-12).
  fallback,
}

/// Bong bóng chat (M-61, C-12): bên mình nằm phải, bên kia nằm trái, rộng
/// tối đa 78%, bo `lg`. [below]: dòng phụ dưới bong bóng (người gửi · giờ,
/// cảnh báo, thẻ sản phẩm), cách 4.
class SoChatBubble extends StatelessWidget {
  const SoChatBubble({
    super.key,
    required this.mine,
    required this.child,
    this.tone = SoChatTone.normal,
    this.below = const [],
  });

  final bool mine;
  final Widget child;
  final SoChatTone tone;
  final List<Widget> below;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final (Decoration decoration, Color fg) = switch (tone) {
      SoChatTone.normal when mine => (
        ShapeDecoration(
          color: c.brand,
          shape: SoShape.squircle(SoRadius.lgAll),
        ),
        c.onBrand,
      ),
      SoChatTone.normal => (SoShape.card(c), c.ink),
      SoChatTone.muted => (SoShape.card(c), c.ink2),
      SoChatTone.fallback => (
        ShapeDecoration(
          color: c.warningTint,
          shape: SoShape.squircle(SoRadius.lgAll),
        ),
        c.ink,
      ),
    };
    final side = mine ? Alignment.centerRight : Alignment.centerLeft;
    return Align(
      alignment: side,
      child: FractionallySizedBox(
        widthFactor: 0.78,
        alignment: side,
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SoSpace.s16,
                vertical: SoSpace.s12,
              ),
              decoration: decoration,
              child: IconTheme.merge(
                data: IconThemeData(color: fg, size: SoSize.iconSmall),
                child: DefaultTextStyle.merge(
                  style: context.textTheme.bodyLarge?.copyWith(color: fg),
                  child: child,
                ),
              ),
            ),
            for (final w in below) ...[const SizedBox(height: SoSpace.s4), w],
          ],
        ),
      ),
    );
  }
}

/// Ô soạn kính dưới đáy màn chat: [nút ảnh] + ô nhập (nền trắng, tối đa 4
/// dòng) + nút gửi tròn brand. Nút gửi khóa khi ô trống hoặc [sending].
/// Nâng lên theo bàn phím. Đặt ở `SoScaffold.bottomBar`.
///
/// [onPhoto]: `null` thì không có nút ảnh (vd. C-12).
class SoChatComposer extends StatefulWidget {
  const SoChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.sending = false,
    this.onPhoto,
    this.hint = 'Nhập tin nhắn',
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  final VoidCallback? onPhoto;
  final String hint;

  @override
  State<SoChatComposer> createState() => _SoChatComposerState();
}

class _SoChatComposerState extends State<SoChatComposer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(SoChatComposer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final canSend = widget.controller.text.trim().isNotEmpty && !widget.sending;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SoGlass(
        borderRadius: BorderRadius.zero,
        shadow: false,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              widget.onPhoto == null ? SoSpace.screen : SoSpace.s4,
              SoSpace.s8,
              SoSpace.s4,
              SoSpace.s8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.onPhoto != null)
                  IconButton(
                    key: const Key('composer_photo'),
                    tooltip: 'Gửi ảnh',
                    icon: Icon(LucideIcons.imagePlus, color: c.ink2),
                    onPressed: widget.onPhoto,
                  ),
                Expanded(
                  child: TextField(
                    key: const Key('composer_input'),
                    controller: widget.controller,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: context.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: SoSpace.s16,
                        vertical: SoSpace.s12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: SoSpace.s4),
                IconButton(
                  key: const Key('composer_send'),
                  tooltip: 'Gửi',
                  onPressed: canSend ? widget.onSend : null,
                  style: IconButton.styleFrom(
                    backgroundColor: c.brand,
                    foregroundColor: c.onBrand,
                    disabledBackgroundColor: c.fillStrong,
                    disabledForegroundColor: c.muted,
                  ),
                  icon: const Icon(LucideIcons.sendHorizontal),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
