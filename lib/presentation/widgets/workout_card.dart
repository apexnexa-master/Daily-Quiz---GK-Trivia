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
                  isBn ? 'ওয়ার্কআউট শুরু করুন' : isHi ? 'वर्कआउट शुरू करें' : 'START WORKOUT',
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
