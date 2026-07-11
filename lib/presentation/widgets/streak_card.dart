// lib/presentation/widgets/streak_card.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_animations.dart';
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
            ? const LinearGradient(
                colors: [Color(0xFFFF9F43), Color(0xFFFF5252)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: isDark
                    ? [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.03)]
                    : [Colors.white, const Color(0xFFF8FAFC)],
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
        border: isActive
            ? null
            : Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.withValues(alpha: 0.15),
                width: 1.5,
              ),
      ),
      child: Row(
        children: [
          // Left: flame + number
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  isActive
                      ? const PulseWidget(
                          child: Icon(
                            AppIcons.streak,
                            color: Colors.white,
                            size: 32,
                          ),
                        )
                      : Icon(
                          Icons.mode_night_rounded,
                          color: isDark ? Colors.white24 : Colors.grey.shade400,
                          size: 28,
                        ),
                  const SizedBox(width: 8),
                  Text(
                    '$current',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: isActive ? Colors.white : (isDark ? Colors.white24 : Colors.grey.shade400),
                      height: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isBn ? 'দিনের ধারাবাহিকতা' : isHi ? 'दिनों का सिलसिला' : 'day streak',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white.withValues(alpha: 0.85) : (isDark ? Colors.white38 : Colors.grey.shade500),
                ),
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
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? (isActive
                              ? Colors.white
                              : AppColors.streak)
                          : (isActive
                              ? Colors.white.withValues(alpha: 0.25)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.grey.shade200)),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.2)
                      : (isDark
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  isBn ? 'সর্বোচ্চ: $longest 🎯' : isHi ? 'सर्वश्रेष्ठ: $longest 🎯' : 'Best: $longest 🎯',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
