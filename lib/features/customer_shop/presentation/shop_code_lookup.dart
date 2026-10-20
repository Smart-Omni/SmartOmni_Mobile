import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/design/design.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/input_formatters.dart';
import '../../../core/utils/validators.dart';
import '../domain/customer_shop.dart';
import 'customer_shop_providers.dart';

/// Ô mã cửa hàng (mono) + nút quét QR + thẻ "Đã tìm thấy". Tra mã khi khách
/// ngừng gõ 0,5 giây. Dùng ở sheet "Thêm cửa hàng" (C-00) và A-05 Đăng ký.
///
/// Key con: `<keyPrefix>_code`, `_error`, `_qr`, `_preview`.
class ShopCodeLookup extends ConsumerStatefulWidget {
  const ShopCodeLookup({
    super.key,
    required this.keyPrefix,
    this.onChanged,
    this.isJoined,
    this.errorText,
  });

  final String keyPrefix;

  /// Kết quả tra mã đổi: cửa hàng tìm thấy, hoặc `null` khi đang gõ / lỗi.
  final ValueChanged<ShopPreview?>? onChanged;

  /// Khách đã tham gia mã này chưa (C-00). Rồi thì báo lỗi, không tra.
  final bool Function(String code)? isJoined;

  /// Lỗi từ bên ngoài (vd. tham gia thất bại), hiện thay lỗi tra mã.
  final String? errorText;

  @override
  ShopCodeLookupState createState() => ShopCodeLookupState();
}

class ShopCodeLookupState extends ConsumerState<ShopCodeLookup> {
  static const _debounce = Duration(milliseconds: 500);

  final _code = TextEditingController();
  Timer? _timer;
  ShopPreview? _preview;
  String? _error;
  bool _looking = false;
  bool _qrTapped = false;

  /// Cửa hàng ứng với mã đang nhập. Chưa tra xong thì tra ngay.
  Future<ShopPreview?> resolve() async {
    if (_preview == null) await _lookup();
    return _preview;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _setPreview(ShopPreview? preview) {
    if (_preview == preview) return;
    setState(() => _preview = preview);
    widget.onChanged?.call(preview);
  }

  void _onChanged(String _) {
    _timer?.cancel();
    setState(() => _error = null);
    _setPreview(null);
    if (_code.text.isNotEmpty) _timer = Timer(_debounce, _lookup);
  }

  Future<void> _lookup() async {
    _timer?.cancel();
    final code = normalizeShopCode(_code.text);
    if (code.isEmpty) return;
    if (widget.isJoined?.call(code) ?? false) {
      setState(() => _error = 'Bạn đã tham gia cửa hàng này.');
      return;
    }
    setState(() => _looking = true);
    try {
      final preview = await ref
          .read(customerShopRepositoryProvider)
          .previewShop(code);
      // Bỏ kết quả cũ nếu khách đã gõ mã khác trong lúc chờ.
      if (!mounted || normalizeShopCode(_code.text) != code) return;
      _setPreview(preview);
    } catch (e) {
      if (!mounted || normalizeShopCode(_code.text) != code) return;
      setState(
        () => _error = e is ApiException
            ? e.message
            : 'Kiểm tra kết nối mạng rồi thử lại.',
      );
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.keyPrefix;
    final preview = _preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoTextField(
          key: Key('${p}_code'),
          label: 'Mã cửa hàng',
          controller: _code,
          hint: 'Vd: SHOPDEMO',
          mono: true,
          inputFormatters: shopCodeFormatters,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (_) => _lookup(),
          validator: (v) => Validators.required(v, field: 'Mã cửa hàng'),
          errorText: widget.errorText ?? _error,
          errorKey: Key('${p}_error'),
          // Toast trong sheet bị lớp phủ che, nên báo ngay dưới ô.
          helper: _qrTapped ? 'Quét mã QR sắp có, hãy nhập mã cửa hàng.' : null,
          suffix: IconButton(
            key: Key('${p}_qr'),
            tooltip: 'Quét mã QR',
            icon: Icon(LucideIcons.scanLine, color: context.soColors.ink2),
            // Dòng lỗi che mất dòng hướng dẫn, nên xóa lỗi cũ để thấy báo.
            onPressed: () => setState(() {
              _qrTapped = true;
              _error = null;
            }),
          ),
        ),
        if (_looking) ...[
          const SizedBox(height: SoSpace.s16),
          const SoSkeleton(height: 72, radius: SoRadius.lg),
        ] else if (preview != null) ...[
          const SizedBox(height: SoSpace.s16),
          _PreviewCard(key: Key('${p}_preview'), preview: preview),
        ],
      ],
    );
  }
}

/// Thẻ kết quả tra mã: logo tròn, "Đã tìm thấy", tên.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({super.key, required this.preview});

  final ShopPreview preview;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Container(
      padding: SoSpace.card,
      decoration: SoShape.card(c),
      child: Row(
        children: [
          SoShopLogo(name: preview.name),
          const SizedBox(width: SoSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đã tìm thấy',
                  style: context.textTheme.bodySmall?.copyWith(color: c.ink2),
                ),
                Text(
                  preview.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleMedium,
                ),
              ],
            ),
          ),
          Icon(LucideIcons.circleCheck, color: c.success),
        ],
      ),
    );
  }
}
