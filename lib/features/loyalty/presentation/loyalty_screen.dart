import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/loyalty_rules.dart';
import 'loyalty_providers.dart';

/// Điểm, hạng, lịch sử tích điểm và voucher của khách.
class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Điểm & hạng')),
      body: Column(
        children: [
          const MockDataBanner(),
          Expanded(
            child: AsyncValueView(
              value: ref.watch(loyaltySummaryProvider),
              onRetry: () => ref.invalidate(loyaltySummaryProvider),
              data: (s) {
                final next = s.tier.next;
                final progress = next == null
                    ? 1.0
                    : (s.totalPoints - s.tier.minPoints) /
                          (next.minPoints - s.tier.minPoints);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hạng ${s.tier.label}',
                              style: text.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${Formatters.number(s.totalPoints)} điểm',
                              style: text.headlineMedium,
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: progress.clamp(0, 1),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              next == null
                                  ? 'Bạn đang ở hạng cao nhất'
                                  : 'Còn ${s.pointsToNext} điểm để lên ${next.label}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1.000 ₫ tiền hàng thực trả = 1 điểm (không tính phí ship, thuế). '
                      'Điểm không hết hạn. Hạng: ${LoyaltyTier.values.map((t) => '${t.label} ≥ ${t.minPoints}').join(', ')}.',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 24),
                    Text('Voucher của bạn', style: text.titleMedium),
                    const _VoucherList(),
                    const SizedBox(height: 24),
                    Text('Lịch sử tích điểm', style: text.titleMedium),
                    if (s.history.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Chưa có lần tích điểm nào.'),
                      ),
                    for (final e in s.history)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('#${e.orderCode} · ${e.platform.label}'),
                        subtitle: Text(Formatters.dateTime(e.claimedAt)),
                        trailing: Text('+${e.points}'),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherList extends ConsumerWidget {
  const _VoucherList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vouchers = ref.watch(vouchersProvider);
    return vouchers.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text(AsyncValueView.errorMessage(e)),
      data: (list) => list.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Chưa có voucher. Cửa hàng sẽ gửi khi có ưu đãi.'),
            )
          : Column(
              children: [
                for (final v in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.confirmation_number_outlined),
                    title: Text(v.code),
                    subtitle: Text(
                      '${v.description}\nDùng trên ${v.platform.label} · HSD ${Formatters.date(v.expiresAt)}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: 'Sao chép mã',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: v.code));
                        if (context.mounted) {
                          showInfoSnackBar(context, 'Đã sao chép ${v.code}');
                        }
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
