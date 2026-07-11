// lib/presentation/widgets/streak_card.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/firestore_models.dart';

class StreakCard extends StatelessWidget {
  final StreakModel? streak;
  final String lang;
  const StreakCard({super.key, this.streak, required this.lang});

  @override
  Widget build(BuildContext context) {
    final current = streak?.currentStreak ?? 0;
    final longest = streak?.longestStreak ?? 0;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final isActive = current > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: isActive
            ? AppTheme.streakGradient
            : LinearGradient(
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 0.05),
                        Colors.white.withValues(alpha: 0.03)
                      ]
                    : [
                        Theme.of(context).colorScheme.surface,
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                      ],
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isActive
            ? [
                BoxShadow(
                    color: AppTheme.warningColor.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ]
            : (isDark ? null : AppTheme.softShadow(AppTheme.primaryColor)),
        border: isActive
            ? null
            : Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.withValues(alpha: 0.1),
              ),
      ),
      child: Row(
        children: [
          // Left: flame + number
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isActive ? '🔥' : '💤',
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$current',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: isActive
                          ? Colors.white
                          : (isDark ? Colors.white38 : Colors.grey.shade400),
                      height: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                isBn ? 'দিনের ধারাবাহিকতা' : isHi ? 'दिनों का सिलसिला' : 'day streak',
                style: isBn
                    ? AppTheme.bengaliStyle(
                        fontSize: 13,
                        color: isActive
                            ? Colors.white70
                            : (isDark ? Colors.white38 : Colors.grey.shade500))
                    : TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isActive
                            ? Colors.white70
                            : (isDark ? Colors.white38 : Colors.grey.shade500)),
              ),
            ],
          ),
          const Spacer(),
          // Right: week dots + best
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 7-day dot tracker
              Row(
                children: List.generate(7, (i) {
                  final filled = i < current.clamp(0, 7);
                  return Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? (isActive
                              ? Colors.white
                              : (isDark
                                  ? AppTheme.warningColor
                                  : AppTheme.warningColor
                                      .withValues(alpha: 0.7)))
                          : (isActive
                              ? Colors.white.withOpacity(0.25)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.grey.shade200)),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withOpacity(0.2)
                      : (isDark
                          ? AppTheme.primaryColor.withValues(alpha: 0.15)
                          : Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isBn ? 'সর্বোচ্চ: $longest 🎯' : isHi ? 'सर्वश्रेष्ठ: $longest 🎯' : 'Best: $longest 🎯',
                  style: isBn
                      ? AppTheme.bengaliStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary)
                      : TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
