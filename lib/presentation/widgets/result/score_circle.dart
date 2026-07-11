// lib/presentation/widgets/result/score_circle.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ScoreCircle extends StatelessWidget {
  final int score;
  final int total;
  final double percentage;
  final AnimationController animation;

  const ScoreCircle({
    super.key,
    required this.score,
    required this.total,
    required this.percentage,
    required this.animation,
  });

  Color _getRingColor(double pct) {
    if (pct >= 0.9) return AppColors.success;
    if (pct >= 0.7) return AppColors.primary;
    if (pct >= 0.5) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = _getRingColor(percentage);
    
    return Center(
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background ring track
            SizedBox(
              width: 150,
              height: 150,
              child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 12,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.15)),
              ),
            ),
            // Foreground animated progress ring
            AnimatedBuilder(
              animation: animation,
              builder: (_, __) {
                final curve = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                );
                return SizedBox(
                  width: 150,
                  height: 150,
                  child: Transform.rotate(
                    angle: -math.pi / 2,
                    child: CircularProgressIndicator(
                      value: curve.value * percentage,
                      strokeWidth: 12,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(ringColor),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                );
              },
            ),
            // Score content inside
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: animation,
                  builder: (_, __) {
                    final curve = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    );
                    final displayScore = (curve.value * score).round();
                    return Text(
                      '$displayScore',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    );
                  },
                ),
                Text(
                  'out of $total',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
