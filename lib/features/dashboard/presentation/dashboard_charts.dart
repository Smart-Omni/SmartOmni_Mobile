import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../core/models/platform.dart';
import '../../../core/utils/formatters.dart';
import '../data/dashboard_data.dart';

/// Khung thẻ trắng viền line, dùng cho các thẻ biểu đồ.
class DashboardCard extends StatelessWidget {
  const DashboardCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Container(
      padding: const EdgeInsets.all(SoSpace.s16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: SoRadius.mdAll,
        border: Border.all(color: c.line),
      ),
      child: child,
    );
  }
}

/// Doanh thu theo kênh: mỗi sàn một thanh ngang brand + % + số tiền.
/// Màu không phân biệt sàn (cùng brand); sàn được nhận ra qua nhãn.
class RevenueByChannelCard extends StatelessWidget {
  const RevenueByChannelCard({super.key, required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return DashboardCard(
      child: Column(
        children: [
          for (final (i, platform) in Platform.values.indexed) ...[
            if (i > 0) const SizedBox(height: SoSpace.s16),
            Row(
              children: [
                Expanded(child: SoChannelTag(platform: platform)),
                Text(
                  Formatters.vnd(summary.revenueByChannel[platform] ?? 0),
                  style: context.soText.numeral,
                ),
              ],
            ),
            const SizedBox(height: SoSpace.s8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: SoRadius.xsAll,
                    child: SizedBox(
                      height: 8,
                      child: ColoredBox(
                        color: c.surfaceSunken,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: summary.channelShare(platform),
                          child: ColoredBox(color: c.brand),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    Formatters.percent(summary.channelShare(platform)),
                    textAlign: TextAlign.right,
                    style: context.soText.code.copyWith(color: c.ink2),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Doanh thu 7 ngày: 7 cột, hôm nay màu brand, các ngày trước brandTint.
///
/// brandTint gần như trùng nền trắng (tương phản 1,16:1) nên luôn có nhãn
/// ngày dưới cột, nhãn số trên cột đang chọn (mặc định hôm nay; chạm cột để
/// xem ngày khác) và mô tả đủ số liệu cho trình đọc màn hình.
class Revenue7DaysCard extends StatefulWidget {
  const Revenue7DaysCard({
    super.key,
    required this.values,
    required this.today,
  });

  /// 7 giá trị, phần tử cuối là hôm nay.
  final List<double> values;
  final DateTime today;

  @override
  State<Revenue7DaysCard> createState() => _Revenue7DaysCardState();
}

class _Revenue7DaysCardState extends State<Revenue7DaysCard> {
  late int _selected = widget.values.length - 1;

  static const _chartHeight = 112.0;
  static const _labelHeight = 18.0;

  String _weekday(int index) {
    final day = widget.today.subtract(
      Duration(days: widget.values.length - 1 - index),
    );
    return day.weekday == DateTime.sunday ? 'CN' : 'T${day.weekday + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.values;
    final max = values.fold<double>(0, (a, b) => b > a ? b : a);
    final total = values.fold<double>(0, (a, b) => a + b);
    final todayIndex = values.length - 1;
    final description = [
      for (var i = 0; i < values.length; i++)
        '${i == todayIndex ? 'Hôm nay' : _weekday(i)} '
            '${Formatters.vnd(values[i])}',
    ].join(', ');

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tổng 7 ngày', style: context.textTheme.bodySmall),
          Text(Formatters.vnd(total), style: context.soText.numeral),
          const SizedBox(height: SoSpace.s16),
          Semantics(
            label: 'Doanh thu 7 ngày: $description',
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < values.length; i++)
                  Expanded(
                    child: GestureDetector(
                      key: Key('revenue_bar_$i'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selected = i),
                      child: _Column(
                        value: values[i],
                        ratio: max <= 0 ? 0 : values[i] / max,
                        label: _weekday(i),
                        isToday: i == todayIndex,
                        isSelected: i == _selected,
                        chartHeight: _chartHeight,
                        labelHeight: _labelHeight,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.value,
    required this.ratio,
    required this.label,
    required this.isToday,
    required this.isSelected,
    required this.chartHeight,
    required this.labelHeight,
  });

  final double value;
  final double ratio;
  final String label;
  final bool isToday;
  final bool isSelected;
  final double chartHeight;
  final double labelHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final labelStyle = context.textTheme.bodySmall;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: labelHeight,
          child: isSelected
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    Formatters.compactVnd(value),
                    style: context.soText.code.copyWith(fontSize: 11),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: chartHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              widthFactor: 0.56,
              heightFactor: ratio.clamp(0.02, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isToday ? c.brand : c.brandTint,
                  border: isSelected && !isToday
                      ? Border.all(color: c.brand)
                      : null,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(SoRadius.xs),
                  ),
                ),
              ),
            ),
          ),
        ),
        Divider(height: 1, color: c.line),
        SizedBox(
          height: labelHeight + 4,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              label,
              style: isToday
                  ? labelStyle?.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w600,
                    )
                  : labelStyle,
            ),
          ),
        ),
      ],
    );
  }
}
