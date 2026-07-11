// lib/presentation/widgets/result/xp_breakdown_card.dart
import 'package:flutter/material.dart';
import '../../../../data/models/gamification_models.dart';
import '../../../core/theme/app_colors.dart';

class XPBreakdownCard extends StatelessWidget {
  final QuizRewards? rewards;
  final String lang;
  final bool isDark;

  const XPBreakdownCard({
    super.key,
    required this.rewards,
    required this.lang,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (rewards == null) return const SizedBox.shrink();

    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF1E1B4B), // Indigo dark
                  const Color(0xFF311042), // Purple dark
                ]
              : [
                  const Color(0xFFEEF2FF), // Indigo light
                  const Color(0xFFFDF2F8), // Pink light
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.primary.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isBn
                ? 'কুইজ পুরস্কার অর্জিত! 🎉'
                : isHi
                    ? 'क्विज़ पुरस्कार प्राप्त! 🎉'
                    : 'Quiz Rewards Earned! 🎉',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.primary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // XP Reward
              _rewardPill(
                icon: Icons.bolt_rounded,
                color: AppColors.xp,
                amount: '+${rewards!.xpEarned} XP',
                label: isBn ? 'এক্সপি' : 'XP',
              ),
              // Coins Reward
              _rewardPill(
                icon: Icons.monetization_on_rounded,
                color: AppColors.coin,
                amount: '+${rewards!.coinsEarned}',
                label: isBn ? 'কয়েন' : 'Coins',
              ),
            ],
          ),
          if (rewards!.streakBonus > 0 || rewards!.speedBonus > 0) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Colors.white24, height: 16),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (rewards!.streakBonus > 0)
                  _bonusText(
                    icon: Icons.local_fire_department_rounded,
                    color: AppColors.streak,
                    text: isBn 
                        ? 'ধারাবাহিকতা বোনাস: +${rewards!.streakBonus}' 
                        : 'स्ट्रीक बोनस: +${rewards!.streakBonus}',
                  ),
                if (rewards!.speedBonus > 0)
                  _bonusText(
                    icon: Icons.speed_rounded,
                    color: AppColors.accent,
                    text: isBn 
                        ? 'গতি বোনাস: +${rewards!.speedBonus}' 
                        : 'गति बोनस: +${rewards!.speedBonus}',
                  ),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _rewardPill({
    required IconData icon,
    required Color color,
    required String amount,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                amount,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bonusText({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
