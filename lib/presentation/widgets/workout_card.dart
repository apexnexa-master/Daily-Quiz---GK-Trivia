// lib/presentation/widgets/workout_card.dart
// "Quick Brain Workout" home card — the primary one-tap action on Home.
// The tile is the banner artwork itself (text lives on the image);
// only the CTA is overlaid at the bottom-right.

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_animations.dart';

class QuickBrainWorkoutCard extends StatelessWidget {
  final String lang;
  const QuickBrainWorkoutCard({super.key, required this.lang});

  @override
  Widget build(BuildContext context) {
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

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Full artwork at its natural aspect ratio so nothing gets cropped.
          AspectRatio(
            aspectRatio: 1289 / 460,
            child: Image.asset(
              'assets/icon/workoutImg.png',
              width: double.infinity,
              fit: BoxFit.fill,
            ),
          ),
          // Overlay text in the banner's free top-right corner (clear of the
          // left-side icons and the bottom-right Start button).
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
              child: Align(
                alignment: Alignment.topRight,
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
                              color: AppColors.neonLime,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                                Shadow(
                                  color: AppColors.neonLime.withValues(alpha: 0.4),
                                  blurRadius: 12,
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
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 8,
                          ),
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // CTA pinned to the bottom-right, over the artwork.
          Positioned(
            right: 14,
            bottom: 14,
            child: AnimatedScaleButton(
              onTap: () => Navigator.pushNamed(context, '/workout'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                decoration: BoxDecoration(
                  gradient: AppColors.workoutGradient,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonLime.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Text(
                  isBn ? 'শুরু করুন' : isHi ? 'शुरू करें' : 'START',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
