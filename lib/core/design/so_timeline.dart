import 'package:flutter/material.dart';

import 'so_text.dart';
import 'so_tokens.dart';

enum SoStepState { done, current, upcoming }

class SoTimelineStep {
  const SoTimelineStep({
    required this.title,
    required this.state,
    this.subtitle,
  });

  final String title;
  final SoStepState state;

  /// Vd. thời gian, hoặc "Sàn tự cập nhật".
  final String? subtitle;
}

/// Tiến trình đơn: nút vuông 12px nối bằng đường mảnh.
/// Xong = brand đặc, hiện tại = viền brand, chưa tới = viền lineControl.
class SoTimeline extends StatelessWidget {
  const SoTimeline({super.key, required this.steps});

  final List<SoTimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 12,
                  child: Column(
                    children: [
                      const SizedBox(height: 5),
                      _Node(state: steps[i].state),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Center(
                            child: Container(width: 1, color: c.line),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: SoSpace.s12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i < steps.length - 1 ? SoSpace.s16 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].title,
                          style: context.soText.bodyStrong.copyWith(
                            color: steps[i].state == SoStepState.upcoming
                                ? c.muted
                                : c.ink,
                          ),
                        ),
                        if (steps[i].subtitle != null)
                          Text(
                            steps[i].subtitle!,
                            style: context.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.state});

  final SoStepState state;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return Container(
      width: 12,
      height: 12,
      decoration: switch (state) {
        SoStepState.done => BoxDecoration(color: c.brand),
        SoStepState.current => BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.brand, width: 2),
        ),
        SoStepState.upcoming => BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.lineControl, width: 1.5),
        ),
      },
    );
  }
}
