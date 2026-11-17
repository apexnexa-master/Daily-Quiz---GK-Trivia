// lib/presentation/widgets/workout_card.dart
// "Daily Brain Workout" hero card for Home. Matches the game tiles: charcoal
// surface, a colorful 2.5D emblem, one crisp title/subtitle pair and a single
// inline CTA. The whole card remains one tap target.

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
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    final titleWord = isBn
        ? 'ব্রেন'
        : isHi
            ? 'ब्रेन'
            : 'BRAIN';
    final titleSuffix = isBn
        ? ' ওয়ার্কআউট'
        : isHi
            ? ' वर्कआउट'
            : ' WORKOUT';
    final subtitle = isBn
        ? '৩টি দ্রুত গেম · ৫ মিনিট'
        : isHi
            ? '3 तेज़ गेम · 5 मिनट'
            : '3 quick games · 5 minutes';
    final badgeLabel = isBn
        ? 'দৈনিক প্রশিক্ষণ'
        : isHi
            ? 'दैनिक प्रशिक्षण'
            : 'DAILY TRAINING';
    final ctaLabel = isBn
        ? 'এখন খেলুন'
        : isHi
            ? 'अभी खेलें'
            : 'PLAY NOW';

    final lime = isDark ? AppColors.neonLime : const Color(0xFF0B8F6C);
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary =
        isDark ? AppColors.gamingTextSecondary : const Color(0xFF526075);
    final emblemAsset = isDark
        ? 'assets/covers/workout_brain_emblem.svg'
        : 'assets/covers/light/workout_brain_emblem.svg';

    return AnimatedScaleButton(
      onTap: () => Navigator.pushNamed(context, '/workout'),
      pressedScale: 0.97,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? AppColors.tileDark : AppColors.tileLight,
        border: isDark ? AppColors.tileBorderDark : AppColors.tileBorderLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(

              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.tileRaisedDark
                                  : AppColors.tileRaisedLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: lime.withValues(
                                    alpha: isDark ? 0.55 : 0.45),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt_rounded, size: 12, color: lime),
                                const SizedBox(width: 4),
                                Text(
                                  badgeLabel,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          '$titleWord$titleSuffix',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                            height: 1.08,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                            color:
                                textSecondary.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: AppColors.workoutGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.neonLime.withValues(
                                      alpha: isDark ? 0.30 : 0.22),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  ctaLabel,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.black,
                                  size: 15,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 132,
                    height: 132,
                    child: SvgPicture.asset(
                      emblemAsset,
                      width: 128,
                      height: 128,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
