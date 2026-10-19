import 'package:flutter/widgets.dart';

import 'so_text.dart';

/// Nền màn: `ground` + 3 mảng màu loang làm mờ (teal góc trên trái, sky góc
/// trên phải, sand phía dưới). Đây là chỗ **duy nhất** được dùng gradient.
///
/// Cố định, không cuộn theo nội dung, không chạy hiệu ứng động, đặt trong
/// [RepaintBoundary] để kính phía trên không làm vẽ lại nền.
///
/// Khu Customer có thể truyền [accent] (màu thương hiệu cửa hàng) thay cho
/// mảng teal.
class SoAmbientBackground extends StatelessWidget {
  const SoAmbientBackground({super.key, this.accent, required this.child});

  final Color? accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: ColoredBox(
            color: c.ground,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Blob(
                  color: accent ?? c.ambientTeal,
                  alignment: const Alignment(-1.1, -1.0),
                  radius: 0.9,
                ),
                _Blob(
                  color: c.ambientSky,
                  alignment: const Alignment(1.2, -0.75),
                  radius: 0.8,
                ),
                _Blob(
                  color: c.ambientSand,
                  alignment: const Alignment(0.2, 1.15),
                  radius: 1.0,
                ),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Một mảng màu loang: gradient tròn từ màu (độ đậm vừa) về trong suốt.
/// Dùng gradient thay cho blur thật để nền rẻ khi vẽ.
class _Blob extends StatelessWidget {
  const _Blob({
    required this.color,
    required this.alignment,
    required this.radius,
  });

  final Color color;
  final Alignment alignment;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: alignment,
          radius: radius,
          colors: [
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
    );
  }
}
