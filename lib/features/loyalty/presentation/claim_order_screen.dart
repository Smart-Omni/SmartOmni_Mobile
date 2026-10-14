import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/platform.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/state_views.dart';
import 'loyalty_providers.dart';

/// Khách chọn shop + nhập mã đơn để tích điểm.
///
/// Điều kiện: đơn đã hoàn tất trên sàn và qua 15 ngày; mỗi đơn chỉ claim 1 lần.
class ClaimOrderScreen extends ConsumerStatefulWidget {
  const ClaimOrderScreen({super.key});

  @override
  ConsumerState<ClaimOrderScreen> createState() => _ClaimOrderScreenState();
}

class _ClaimOrderScreenState extends ConsumerState<ClaimOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  Platform _platform = Platform.shopee;
  bool _busy = false;
  String? _result;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final points = await ref
          .read(loyaltyRepositoryProvider)
          .claimOrder(platform: _platform, orderCode: _codeCtrl.text);
      ref.invalidate(loyaltySummaryProvider);
      if (!mounted) return;
      setState(() => _result = 'Thành công! Bạn được cộng $points điểm.');
      _codeCtrl.clear();
    } catch (e) {
      if (mounted) setState(() => _result = AsyncValueView.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Claim đơn tích điểm')),
      body: Column(
        children: [
          const MockDataBanner(
            note:
                'Thử mã: 240920SHOP01 (Shopee), 5779000099998888 (TikTok), 241008SHOP02 (chưa đủ 15 ngày).',
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Đơn đã hoàn tất trên sàn từ 15 ngày trở lên mới được claim. '
                    'Mỗi đơn chỉ được claim một lần.',
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<Platform>(
                    segments: [
                      for (final p in Platform.values)
                        ButtonSegment(value: p, label: Text(p.label)),
                    ],
                    selected: {_platform},
                    onSelectionChanged: (s) =>
                        setState(() => _platform = s.first),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Mã đơn trên sàn',
                    ),
                    validator: (v) => Validators.required(v, field: 'Mã đơn'),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: const Text('Claim điểm'),
                  ),
                  if (_result != null) ...[
                    const SizedBox(height: 16),
                    Text(_result!, key: const Key('claim_result')),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
