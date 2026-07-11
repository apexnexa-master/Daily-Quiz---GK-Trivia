// lib/presentation/widgets/quiz/quiz_timer_bar.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class QuizTimerBar extends StatelessWidget {
  final AnimationController animation;
  final int remainingSeconds;
  final int totalSeconds;

  const QuizTimerBar({
    super.key,
    required this.animation,
    required this.remainingSeconds,
    this.totalSeconds = 30,
  });

  Color _timerColor(int s) {
    if (s > 20) return AppColors.success;
    if (s > 10) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final double progress = remainingSeconds / totalSeconds;
    final isLowTime = remainingSeconds <= 5;
    
    return Row(
      children: [
        Expanded(
          child: Stack(
            children: [
              // Background track
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white10
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Animated progress bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 8,
                width: MediaQuery.of(context).size.width * progress * 0.7,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _timerColor(remainingSeconds),
                      _timerColor(remainingSeconds).withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: _timerColor(remainingSeconds).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Timer Text Badge
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isLowTime 
                ? AppColors.error.withValues(alpha: 0.15)
                : Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isLowTime 
                  ? AppColors.error.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_rounded,
                size: 14,
                color: _timerColor(remainingSeconds),
              ),
              const SizedBox(width: 4),
              Text(
                '$remainingSeconds',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _timerColor(remainingSeconds),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
