// lib/presentation/workout/workout_progress_banner.dart
// Compact "in-game" indicator shown on top of a game screen while it runs
// inside a Quick Brain Workout. Kept intentionally light so it never distracts
// from the game itself.

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'workout_models.dart';

class WorkoutProgressBanner extends StatelessWidget {
  final WorkoutStep step;
  final String lang;
  final EdgeInsetsGeometry padding;

  const WorkoutProgressBanner({
    super.key,
    required this.step,
    this.lang = 'en',
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 2),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = step.game.skill.accent;
    final number = '${(step.index + 1).toString().padLeft(2, '0')} / ${step.total.toString().padLeft(2, '0')}';

    return Container(
      margin: padding,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            number,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: accent,
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 12, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15)),
          const SizedBox(width: 8),
          Text(step.game.skill.emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 5),
          Text(
            step.game.title(lang).toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }
}