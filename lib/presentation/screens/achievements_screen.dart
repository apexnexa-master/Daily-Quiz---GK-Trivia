// lib/presentation/screens/achievements_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_animations.dart';
import '../../data/models/gamification_models.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(gamificationAchievementsProvider);
    final statsAsync = ref.watch(gamificationNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(languageProvider);
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    final unlockedCount = achievements.where((a) => a.isUnlocked).length;
    final totalXP = achievements
        .where((a) => a.isUnlocked)
        .fold<int>(0, (sum, a) => sum + a.xpReward);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.homeBackdropDark : AppColors.homeBackdropGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, isDark, isBn, isHi, unlockedCount,
                  achievements.length, totalXP),
              Expanded(
                child: statsAsync.when(
                  data: (stats) => _buildAchievementsList(
                      achievements, isDark, isBn, isHi),
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                  error: (_, __) => _buildAchievementsList(
                      achievements, isDark, isBn, isHi),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, bool isBn, bool isHi,
      int unlocked, int total, int totalXP) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back_rounded,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight),
              ),
              const SizedBox(width: 4),
              Text(
                isBn
                    ? 'অর্জন'
                    : isHi
                        ? 'उपलब्धियां'
                        : 'Achievements',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress summary header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: isDark ? AppColors.primaryGradientDark : AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
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
                  child: const Icon(AppIcons.achievement,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$unlocked / $total',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        isBn ? 'অর্জন আনলক করা' : isHi ? 'अनलॉक' : 'Unlocked',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '+$totalXP',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.coin,
                      ),
                    ),
                    Text(
                      'Total XP',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsList(List<AchievementModel> achievements,
      bool isDark, bool isBn, bool isHi) {
    final sorted = List<AchievementModel>.from(achievements)
      ..sort((a, b) {
        if (a.isUnlocked && !b.isUnlocked) return -1;
        if (!a.isUnlocked && b.isUnlocked) return 1;
        return b.xpReward.compareTo(a.xpReward);
      });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final achievement = sorted[index];
        return StaggeredListItem(
          index: index,
          child: _AchievementCard(
            achievement: achievement,
            isDark: isDark,
          ),
        );
      },
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final AchievementModel achievement;
  final bool isDark;

  const _AchievementCard({
    required this.achievement,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlocked = achievement.isUnlocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked
              ? AppColors.success.withValues(alpha: 0.3)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.1)),
          width: 1.5,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? AppColors.warning.withValues(alpha: 0.15)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.08)),
              shape: BoxShape.circle,
              border: Border.all(
                color: isUnlocked 
                    ? AppColors.warning.withValues(alpha: 0.3) 
                    : Colors.transparent,
              ),
            ),
            child: Center(
              child: Text(
                isUnlocked ? achievement.icon : '🔒',
                style: TextStyle(
                  fontSize: 24,
                  color: isUnlocked ? null : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Info Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.titleKey,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isUnlocked
                        ? (isDark ? Colors.white : AppColors.textPrimaryLight)
                        : (isDark ? Colors.white54 : Colors.grey),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.descriptionKey,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _RewardTag(
                      icon: AppIcons.xp,
                      value: '+${achievement.xpReward}',
                      color: AppColors.xp,
                      isUnlocked: isUnlocked,
                    ),
                    const SizedBox(width: 8),
                    _RewardTag(
                      icon: AppIcons.coin,
                      value: '+${achievement.coinReward}',
                      color: AppColors.coin,
                      isUnlocked: isUnlocked,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Completed badge
          if (isUnlocked)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.check,
                color: AppColors.success,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }
}

class _RewardTag extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  final bool isUnlocked;

  const _RewardTag({
    required this.icon,
    required this.value,
    required this.color,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isUnlocked ? color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked ? color.withValues(alpha: 0.3) : (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: isUnlocked ? color : Colors.grey),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isUnlocked ? color : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
