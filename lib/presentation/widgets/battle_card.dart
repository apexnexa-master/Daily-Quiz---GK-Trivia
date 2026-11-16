// lib/presentation/widgets/battle_card.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_animations.dart';
import 'soft_duotone_icon.dart';

class BattleArenaCard extends StatelessWidget {
  final String lang;
  const BattleArenaCard({super.key, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    final title = isBn ? '১ বনাম ১ কুইজ যুদ্ধ' : isHi ? '1 बनाम 1 क्विज़ युद्ध' : '1v1 Quiz Battle';
    final subtitle = isBn
        ? 'বন্ধুদের সাথে সরাসরি লাইভ দ্বৈরথ লড়ুন বা বটের সাথে অনুশীলন করুন।'
        : isHi
            ? 'दोस्तों के साथ लाइव खेलें या बॉट के साथ अभ्यास करें।'
            : 'Duel friends in real-time online, or train offline against a bot!';
    final btnLabel = isBn ? 'যুদ্ধক্ষেত্রে প্রবেশ করুন' : isHi ? 'युद्ध में शामिल हों' : 'Enter Battle Arena';

    const accent = AppColors.gamingGreen;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF20262F), Color(0xFF171C24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.gamingBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.08 : 0.06),
            blurRadius: 26,
            spreadRadius: -8,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              bottom: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: 0.16),
                      accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.gamingTextSecondary,
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SoftDuotoneIcon(
                        icon: Icons.sports_martial_arts_rounded,
                        accent: accent,
                        size: 44,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AnimatedScaleButton(
                    onTap: () {
                      Navigator.pushNamed(context, '/battle');
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.30),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bolt_rounded, color: AppColors.gamingBg, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            btnLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.gamingBg,
                            ),
                          ),
                        ],
                      ),
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
