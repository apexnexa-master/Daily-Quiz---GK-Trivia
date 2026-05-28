// lib/presentation/widgets/gamification_bar.dart
// Gamification status bar showing XP, Level, Coins, Lives

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';

class GamificationBar extends ConsumerWidget {
  const GamificationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(gamificationNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return statsAsync.when(
      data: (stats) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.1),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                )
              : LinearGradient(
                  colors: [
                    Colors.white,
                    const Color(0xFFF8FAFC),
                  ],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildLevelBadge(stats, isDark),
            const SizedBox(width: 12),
            Expanded(child: _buildXPProgress(stats, isDark)),
            const SizedBox(width: 12),
            _buildCoins(stats, isDark),
            const SizedBox(width: 8),
            _buildLives(stats, isDark),
          ],
        ),
      ),
      loading: () => const SizedBox(height: 56),
      error: (_, __) => const SizedBox(height: 56),
    );
  }

  Widget _buildLevelBadge(stats, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            '${stats.level}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXPProgress(stats, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.bolt_rounded, size: 14, color: AppTheme.warningColor),
            const SizedBox(width: 4),
            Text(
              '${stats.xp} XP',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
            ),
            const Spacer(),
            Text(
              '${stats.xpForNextLevel}',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.grey[400],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: stats.levelProgress,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation(AppTheme.warningColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildCoins(stats, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.successColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '${stats.coins}',
            style: TextStyle(
              color: AppTheme.successColor,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLives(stats, bool isDark) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: stats.lives > 0
              ? AppTheme.errorColor.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(
                Icons.favorite_rounded,
                size: 14,
                color: i < stats.lives
                    ? AppTheme.errorColor
                    : (isDark ? Colors.white24 : Colors.grey[300]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DailyRewardBanner extends ConsumerWidget {
  const DailyRewardBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(gamificationNotifierProvider);
    final lang = ref.watch(languageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return statsAsync.when(
      data: (stats) {
        if (!stats.canClaimDailyReward) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => _claimReward(context, ref, lang),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667EEA),
                  const Color(0xFF764BA2),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667EEA).withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🎁', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBn
                            ? 'দৈনিক পুরস্কার!'
                            : isHi
                                ? 'दैनिक पुरस्कार!'
                                : 'Daily Reward!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isBn
                            ? '+${10 + (stats.currentStreak ~/ 7) * 10} 🪙 পান'
                            : isHi
                                ? '+${10 + (stats.currentStreak ~/ 7) * 10} 🪙 मिलें'
                                : '+${10 + (stats.currentStreak ~/ 7) * 10} 🪙 Coins',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isBn
                        ? 'দাবি'
                        : isHi
                            ? 'लो'
                            : 'Claim',
                    style: TextStyle(
                      color: const Color(0xFF667EEA),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _claimReward(BuildContext context, WidgetRef ref, String lang) async {
    final notifier = ref.read(gamificationNotifierProvider.notifier);
    final claimed = await notifier.claimDailyReward();

    if (context.mounted) {
      final message = claimed
          ? (lang == 'bn'
              ? 'পুরস্কার পেয়েছেন! 🎉'
              : lang == 'hi'
                  ? 'पुरस्कार मिला! 🎉'
                  : 'Reward claimed! 🎉')
          : (lang == 'bn'
              ? 'আগেই দাবি করেছেন'
              : lang == 'hi'
                  ? 'पहले ही लिया'
                  : 'Already claimed');
      final color = claimed ? AppTheme.successColor : AppTheme.errorColor;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
        ),
      );
    }
  }
}

class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(gamificationNotifierProvider);
    final lang = ref.watch(languageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return statsAsync.when(
      data: (stats) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withValues(alpha: 0.2),
                    Colors.red.withValues(alpha: 0.2),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Text('🔥', style: TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBn
                        ? 'ধারাবাহিকতা'
                        : isHi
                            ? 'स्ट्रीक'
                            : 'Streak',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${stats.currentStreak}',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isBn
                            ? 'দিন'
                            : isHi
                                ? 'दिन'
                                : 'days',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isBn
                      ? 'সেরা'
                      : isHi
                          ? 'सर्वश्रेष्ठ'
                          : 'Best',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey[500],
                    fontSize: 10,
                  ),
                ),
                Text(
                  '${stats.longestStreak} 🔥',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      loading: () => const SizedBox(height: 80),
      error: (_, __) => const SizedBox(height: 80),
    );
  }
}

class QuickActionsBar extends ConsumerWidget {
  const QuickActionsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionButton(
              icon: Icons.people_alt_rounded,
              label: isBn
                  ? 'Battle'
                  : isHi
                      ? 'लड़ाई'
                      : 'Battle',
              color: AppTheme.errorColor,
              isDark: isDark,
              onTap: () => Navigator.pushNamed(context, '/battle'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.emoji_events_rounded,
              label: isBn
                  ? 'র‌্যাংকিং'
                  : isHi
                      ? 'रैंकिंग'
                      : 'Rank',
              color: AppTheme.primaryColor,
              isDark: isDark,
              onTap: () => Navigator.pushNamed(context, '/leaderboard'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.workspace_premium_rounded,
              label: isBn
                  ? 'উপাদান'
                  : isHi
                      ? 'उपलब्धियां'
                      : 'Badges',
              color: AppTheme.successColor,
              isDark: isDark,
              onTap: () => Navigator.pushNamed(context, '/achievements'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.card_giftcard_rounded,
              label: isBn
                  ? 'আমন্ত্রণ'
                  : isHi
                      ? 'निमंत्रण'
                      : 'Invite',
              color: Colors.purple,
              isDark: isDark,
              onTap: () => _showReferralDialog(context, ref, lang),
            ),
          ),
        ],
      ),
    );
  }

  void _showReferralDialog(BuildContext context, WidgetRef ref, String lang) {
    final code = ref.read(referralCodeProvider);
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1B4B)
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Text('🎁', style: TextStyle(fontSize: 32)),
            ),
            const SizedBox(height: 16),
            Text(
              isBn
                  ? 'বন্ধুদের আমন্ত্রণ করুন!'
                  : isHi
                      ? 'दोस्तों को आमंत्रित करें!'
                      : 'Invite Friends!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isBn
                  ? 'আপনার কোড শেয়ার করুন এবং ১০০ 🪙 পান!'
                  : isHi
                      ? 'अपना कोड साझा करें और 100 🪙 पाएं!'
                      : 'Share your code and get 100 🪙!',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white54
                    : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      code,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Copy to clipboard and share
                    },
                    icon: const Icon(Icons.copy_rounded),
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Share functionality
                },
                icon: const Icon(Icons.share_rounded),
                label: Text(isBn
                    ? 'শেয়ার করুন'
                    : isHi
                        ? 'साझा करें'
                        : 'Share'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyChallengesCard extends ConsumerWidget {
  const DailyChallengesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(dailyChallengesProvider);
    final lang = ref.watch(languageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                isBn
                    ? 'দৈনিক চ্যালেঞ্জ'
                    : isHi
                        ? 'दैनिक चुनौतियां'
                        : 'Daily Challenges',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${challenges.where((c) => c.isCompleted).length}/${challenges.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...challenges.map((challenge) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ChallengeItem(
                  challenge: challenge,
                  isDark: isDark,
                ),
              )),
        ],
      ),
    );
  }
}

class _ChallengeItem extends StatelessWidget {
  final dynamic challenge;
  final bool isDark;

  const _ChallengeItem({
    required this.challenge,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: challenge.isCompleted
                ? AppTheme.successColor.withValues(alpha: 0.15)
                : AppTheme.primaryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            challenge.isCompleted ? Icons.check_rounded : Icons.flag_rounded,
            color: challenge.isCompleted
                ? AppTheme.successColor
                : AppTheme.primaryColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                challenge.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: challenge.progressPercent,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(
                    challenge.isCompleted
                        ? AppTheme.successColor
                        : AppTheme.primaryColor,
                  ),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '+${challenge.xpReward} XP',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.warningColor,
              ),
            ),
            Text(
              '+${challenge.coinReward} 🪙',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.successColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
