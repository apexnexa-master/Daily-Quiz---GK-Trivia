// lib/presentation/widgets/workout_card.dart
// "Quick Brain Workout" home card — the primary one-tap action on Home.
// The tile is the banner artwork itself (text lives on the image); the whole
// card is a single tap target with an inline gradient START chip.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_animations.dart';

class QuickBrainWorkoutCard extends StatelessWidget {
  final String lang;
  const QuickBrainWorkoutCard({super.key, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bannerAsset = isDark
        ? 'assets/covers/workout_banner.svg'
        : 'assets/covers/light/workout_banner.svg';
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final titlePrefix = isBn ? 'কুইক ' : isHi ? 'क्विक ' : 'QUICK ';
    final titleWord = isBn ? 'ব্রেন' : isHi ? 'ब्रेन' : 'BRAIN';
    final titleSuffix = isBn ? ' ওয়ার্কআউট' : isHi ? ' वर्कआउट' : ' WORKOUT';
    final subtitle = isBn
        ? 'এক সেশনে ৩টি দক্ষতা অনুশীলন করুন'
        : isHi
            ? 'एक सत्र में 3 कौशल प्रशिक्षित करें'
            : 'Train 3 skills in one session';

    return AnimatedScaleButton(
      onTap: () => Navigator.pushNamed(context, '/workout'),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonLime.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Full artwork at its natural aspect ratio so nothing gets cropped.
            AspectRatio(
              aspectRatio: 1289 / 460,
              child: SvgPicture.asset(
                bannerAsset,
                width: double.infinity,
                fit: BoxFit.fill,
              ),
            ),
            // Top-left badge: Daily Workout indicator
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.42)
                      : Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.neonLime
                        .withValues(alpha: isDark ? 0.35 : 0.55),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      color: isDark
                          ? AppColors.neonLime
                          : const Color(0xFF0B8F6C),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isBn ? 'দৈনিক সেশন' : isHi ? 'दैनिक सत्र' : 'DAILY COMBO',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color:
                            isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Text block in the banner's free right zone, stacked like the
            // poster tiles: headline -> subtitle pill -> inline start chip.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 14, 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: titlePrefix),
                            TextSpan(
                              text: titleWord,
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.neonLime
                                    : const Color(0xFF0B8F6C),
                                shadows: [
                                  Shadow(
                                    color: (isDark ? Colors.black : Colors.white)
                                        .withValues(alpha: 0.7),
                                    blurRadius: 8,
                                  ),
                                  Shadow(
                                    color: AppColors.neonLime
                                        .withValues(
                                            alpha: isDark ? 0.4 : 0.5),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                            ),
                            TextSpan(text: titleSuffix),
                          ],
                        ),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          height: 1.1,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1F2937),
                          shadows: [
                            Shadow(
                              color: (isDark ? Colors.black : Colors.white)
                                  .withValues(alpha: 0.7),
                              blurRadius: 10,
                            ),
                            Shadow(
                              color: Colors.black.withValues(
                                  alpha: isDark ? 0.4 : 0.15),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.42)
                              : Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.16)
                                : Colors.black.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.9)
                                : const Color(0xFF33415C),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: AppColors.workoutGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.neonLime.withValues(alpha: 0.30),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isBn ? 'শুরু করুন' : isHi ? 'शुरू करें' : 'START',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.black,
                              size: 13,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
