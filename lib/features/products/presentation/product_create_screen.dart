import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/input_formatters.dart';
import '../../../core/utils/validators.dart';
import '../../account/presentation/account_widgets.dart';
import '../domain/product.dart';
import 'products_providers.dart';

/// M-32 Tạo sản phẩm mới kèm 1 SKU (POST /api/products), DESIGN.md mục 8b.
/// Nhiều SKU, ảnh, link sàn: "Sắp có" (USER_FLOWS F-S3 bước 4).
class ProductCreateScreen extends ConsumerStatefulWidget {
  const ProductCreateScreen({super.key});

  @override
  ConsumerState<ProductCreateScreen> createState() =>
      _ProductCreateScreenState();
}

class _ProductCreateScreenState extends ConsumerState<ProductCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _skuCode = TextEditingController();
  final _variant = TextEditingController();
  final _price = TextEditingController();
  bool _busy = false;

  /// Lỗi từ server: gắn vào ô mã SKU nếu nói về SKU, còn lại hiện ở đầu form.
  String? _skuError;
  String? _formError;

  List<TextEditingController> get _fields => [
    _name,
    _desc,
    _skuCode,
    _variant,
    _price,
  ];

  bool get _dirty => _fields.any((c) => c.text.trim().isNotEmpty);

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  String? _optional(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _submit() async {
    // Phím Done ở ô giá vẫn gọi được khi nút Lưu đang khóa.
    if (_busy) return;
    setState(() => _skuError = _formError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final created = await ref
          .read(productsRepositoryProvider)
          .createProduct(
            CreateProductInput(
              name: _name.text.trim(),
              description: _optional(_desc),
              skus: [
                CreateSkuInput(
                  skuCode: _skuCode.text.trim(),
                  variantName: _optional(_variant),
                  basePrice: VndInputFormatter.parse(_price.text)!.toDouble(),
                ),
              ],
            ),
          );
      ref.invalidate(productsListProvider);
      if (!mounted) return;
      showSoToast(context, 'Đã tạo sản phẩm');
      // Mở chi tiết (API thật) thay vì về M-30: ở bản thật danh sách M-30
      // còn là dữ liệu mẫu nên sản phẩm mới chưa hiện ở đó.
      context.pushReplacement(Routes.merchantProductDetail(created.id));
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : 'Kiểm tra kết nối mạng rồi thử lại.';
      setState(() {
        if (message.toLowerCase().contains('sku')) {
          _skuError = message;
        } else {
          _formError = message;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Back khi form đã có dữ liệu: hỏi trước khi bỏ.
  Future<void> _confirmDiscard() async {
    final discard = await showSoBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SoBottomSheet(
        title: 'Bỏ sản phẩm đang nhập?',
        secondary: SoButton.secondary(
          key: const Key('discard_cancel'),
          label: 'Tiếp tục nhập',
          onPressed: () => Navigator.pop(sheetContext, false),
        ),
        primary: SoButton.danger(
          key: const Key('discard_confirm'),
          label: 'Bỏ',
          onPressed: () => Navigator.pop(sheetContext, true),
        ),
        child: Text(
          'Những gì bạn đã nhập sẽ không được lưu.',
          // context của sheet: màn tạo có thể đã đóng khi sheet còn đang đóng.
          style: sheetContext.textTheme.bodyMedium,
        ),
      ),
    );
    if ((discard ?? false) && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    // Form không chạy dưới kính (giống A-03/A-04): ô đang nhập không bị che.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _busy) return;
        _dirty ? _confirmDiscard() : context.pop();
      },
      child: SoAmbientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: const SoAppBar(title: 'Sản phẩm mới', close: true),
          bottomNavigationBar: SoActionBar(
            // Hủy đi qua PopScope: form có dữ liệu thì hỏi trước khi bỏ.
            secondary: SoButton.secondary(
              key: const Key('product_create_cancel'),
              label: 'Hủy',
              onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
            ),
            primary: SoButton(
              key: const Key('product_create_submit'),
              label: 'Lưu sản phẩm',
              loading: _busy,
              onPressed: _submit,
            ),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                SoSpace.screen,
                SoSpace.s8,
                SoSpace.screen,
                SoSpace.s24,
              ),
              children: [
                if (_formError != null) ...[
                  SoBanner(
                    key: const Key('product_create_error'),
                    tone: SoBannerTone.danger,
                    title: 'Chưa tạo được sản phẩm',
                    message: _formError,
                  ),
                  const SizedBox(height: SoSpace.s16),
                ],
                _Card(
                  children: [
                    SoTextField(
                      key: const Key('product_name'),
                      label: 'Tên sản phẩm *',
                      controller: _name,
                      hint: 'Vd: Áo thun cổ tròn',
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          Validators.required(v, field: 'Tên sản phẩm'),
                    ),
                    SoTextField(
                      key: const Key('product_desc'),
                      label: 'Mô tả',
                      controller: _desc,
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                    ),
                  ],
                ),
                const GroupTitle(
                  'SKU',
                  trailing: 'Nhiều SKU, ảnh, link sàn · Sắp có',
                ),
                _Card(
                  children: [
                    SoTextField(
                      key: const Key('sku_code'),
                      label: 'Mã SKU *',
                      controller: _skuCode,
                      hint: 'AT-001-M',
                      helper: 'Chữ in hoa, số và dấu -, không có dấu cách.',
                      mono: true,
                      errorText: _skuError,
                      inputFormatters: skuCodeFormatters,
                      textInputAction: TextInputAction.next,
                      validator: (v) => Validators.required(v, field: 'Mã SKU'),
                    ),
                    SoTextField(
                      key: const Key('sku_variant'),
                      label: 'Phân loại',
                      controller: _variant,
                      hint: 'Vd: Đen / M',
                      textInputAction: TextInputAction.next,
                    ),
                    SoTextField(
                      key: const Key('sku_price'),
                      label: 'Giá bán *',
                      controller: _price,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      inputFormatters: const [VndInputFormatter()],
                      textAlign: TextAlign.end,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      suffix: Padding(
                        padding: const EdgeInsets.only(right: SoSpace.s16),
                        child: Text(
                          '₫',
                          style: context.textTheme.bodyLarge?.copyWith(
                            color: c.ink2,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          Validators.positiveVnd(v, field: 'Giá bán'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ đặc chứa các ô nhập của một nhóm, cách nhau 16.
class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: SoSpace.card,
      decoration: SoShape.card(context.soColors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, field) in children.indexed) ...[
            if (i > 0) const SizedBox(height: SoSpace.s16),
            field,
          ],
        ],
      ),
    );
  }
}
