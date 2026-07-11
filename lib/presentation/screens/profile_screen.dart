// lib/presentation/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../widgets/gamification_bar.dart';
import '../widgets/profile/profile_overview.dart';
import '../widgets/profile/settings_section.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_manager.dart';
import '../../core/theme/app_animations.dart';
import '../../data/models/gamification_models.dart';
import '../../core/services/question_tracking_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final lang = ref.watch(languageProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return Scaffold(
      body: authAsync.when(
        data: (user) {
          if (user == null) {
            return _NotLoggedIn(lang: lang, isDark: isDark);
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ProfileOverview(
                  user: user,
                  lang: lang,
                  isDark: isDark,
                ),
              ),
              SliverPadding(
                padding: AppSpacing.paddingScreen,
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Stats section with entrance animation
                    StaggeredListItem(
                      index: 0,
                      child: _StatsSection(lang: lang, isDark: isDark, ref: ref),
                    ),
                    const SizedBox(height: 16),
                    StaggeredListItem(
                      index: 1,
                      child: const DailyRewardBanner(),
                    ),
                    const SizedBox(height: 8),
                    StaggeredListItem(
                      index: 2,
                      child: const DailyChallengesCard(),
                    ),
                    const SizedBox(height: 8),
                    StaggeredListItem(
                      index: 3,
                      child: const GamificationBar(),
                    ),
                    const SizedBox(height: 24),
                    // Achievements
                    StaggeredListItem(
                      index: 4,
                      child: _AchievementsSection(lang: lang, isDark: isDark, ref: ref),
                    ),
                    const SizedBox(height: 24),
                    if (user.isAnonymous) ...[
                      StaggeredListItem(
                        index: 5,
                        child: _UpgradePrompt(lang: lang, ref: ref, isDark: isDark),
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Settings
                    StaggeredListItem(
                      index: 6,
                      child: SettingsSection(
                        lang: lang,
                        themeMode: themeMode,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 24),
                    StaggeredListItem(
                      index: 7,
                      child: _DisclaimerSection(lang: lang, isDark: isDark),
                    ),
                    const SizedBox(height: 24),
                    StaggeredListItem(
                      index: 8,
                      child: _SignOutSection(lang: lang, ref: ref, isDark: isDark),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: Text(
                        'GK Quiz Daily v1.1.0',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                isBn
                    ? 'কিছু সমস্যা হয়েছে'
                    : isHi
                        ? 'कुछ समस्या हुई'
                        : 'Something went wrong',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsSection extends ConsumerWidget {
  final String lang;
  final bool isDark;
  final WidgetRef ref;
  const _StatsSection({
    required this.lang,
    required this.isDark,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(localStreakProvider);
    final totalQuizzesAsync = ref.watch(totalQuizzesProvider);
    final personalBestAsync = ref.watch(localPersonalBestProvider);
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.analytics_rounded,
          title: isBn
              ? 'পরিসংখ্যান'
              : isHi
                  ? 'आंकड़े'
                  : 'Statistics',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: streakAsync.when(
                data: (streak) => _StatCard(
                  icon: AppIcons.streak,
                  iconColor: AppColors.streak,
                  value: '${streak.currentStreak}',
                  label: isBn ? 'ধারাবাহিকতা' : isHi ? 'स्ट्रीक' : 'Streak',
                  sublabel: isBn ? 'দিন' : isHi ? 'दिन' : 'days',
                  isDark: isDark,
                ),
                loading: () => _StatCardSkeleton(isDark: isDark),
                error: (_, __) => _StatCard(
                  icon: AppIcons.streak,
                  iconColor: AppColors.streak,
                  value: '0',
                  label: isBn ? 'ধারাবাহিকতা' : isHi ? 'स्ट्रीक' : 'Streak',
                  sublabel: isBn ? 'দিন' : isHi ? 'दिन' : 'days',
                  isDark: isDark,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: totalQuizzesAsync.when(
                data: (count) => _StatCard(
                  icon: Icons.quiz_rounded,
                  iconColor: AppColors.primary,
                  value: '$count',
                  label: isBn ? 'মোট কুইজ' : isHi ? 'कुल क्विज़' : 'Total Quizzes',
                  sublabel: isBn ? 'খেলা হয়েছে' : isHi ? 'खेले' : 'played',
                  isDark: isDark,
                ),
                loading: () => _StatCardSkeleton(isDark: isDark),
                error: (_, __) => _StatCard(
                  icon: Icons.quiz_rounded,
                  iconColor: AppColors.primary,
                  value: '0',
                  label: isBn ? 'মোট কুইজ' : isHi ? 'कुल क्विज़' : 'Total Quizzes',
                  sublabel: isBn ? 'খেলা হয়েছে' : isHi ? 'खेले' : 'played',
                  isDark: isDark,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: personalBestAsync.when(
                data: (best) => _StatCard(
                  icon: AppIcons.achievement,
                  iconColor: AppColors.success,
                  value: '${best.percentage.toInt()}%',
                  label: isBn ? 'সেরা স্কোর' : isHi ? 'सर्वश्रेष्ठ स्कोर' : 'Best Score',
                  sublabel: isBn ? 'শতাংশ' : isHi ? 'प्रतिशत' : '%',
                  isDark: isDark,
                ),
                loading: () => _StatCardSkeleton(isDark: isDark),
                error: (_, __) => _StatCard(
                  icon: AppIcons.achievement,
                  iconColor: AppColors.success,
                  value: '—',
                  label: isBn ? 'সেরা স্কোর' : isHi ? 'सर्वश्रेष्ठ स्कोर' : 'Best Score',
                  sublabel: isBn ? 'শতাংশ' : isHi ? 'प्रतिशत' : '%',
                  isDark: isDark,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String sublabel;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.sublabel,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatCardSkeleton extends StatelessWidget {
  final bool isDark;
  const _StatCardSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _UpgradePrompt extends StatelessWidget {
  final String lang;
  final WidgetRef ref;
  final bool isDark;
  const _UpgradePrompt({
    required this.lang,
    required this.ref,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.warning.withValues(alpha: isDark ? 0.15 : 0.08),
            AppColors.warning.withValues(alpha: isDark ? 0.08 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: isDark ? 0.3 : 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.link_rounded, color: AppColors.warning, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBn ? 'অ্যাকাউন্ট সংযুক্ত করুন' : 'Link Your Account',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isBn
                      ? 'আপনার অগ্রগতি সংরক্ষণ করতে'
                      : isHi
                          ? 'अपनी प्रगति स्थायी रूप से सहेजें'
                          : 'To save your progress permanently',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warning.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              await ref.read(authServiceProvider).upgradeAnonymousAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isBn ? 'সংযুক্ত করুন' : 'Link',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerSection extends StatelessWidget {
  final String lang;
  final bool isDark;
  const _DisclaimerSection({required this.lang, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.info_outline_rounded,
          title: isBn
              ? 'দাবিত্যাগ ও উৎস'
              : isHi
                  ? 'अस्वीकरण और स्रोत'
                  : 'Disclaimer & Sources',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : Colors.grey)
                    .withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
            ),
            title: Text(
              isBn
                  ? 'দাবিত্যাগ ও উৎস'
                  : isHi
                      ? 'अस्वीकरण और स्रोत'
                      : 'Disclaimer & Sources',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : Colors.grey.shade400,
            ),
            onTap: () => Navigator.pushNamed(context, '/disclaimer'),
          ),
        ),
      ],
    );
  }
}

class _SignOutSection extends StatelessWidget {
  final String lang;
  final WidgetRef ref;
  final bool isDark;
  const _SignOutSection({
    required this.lang,
    required this.ref,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: isDark ? AppColors.cardDark : Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isBn ? 'লগআউট করুন?' : isHi ? 'साइन आउट करें?' : 'Sign out?',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : null,
                    ),
                  ),
                ],
              ),
              content: Text(
                isBn
                    ? 'আপনি কি নিশ্চিতভাবে লগআউট করতে চান?'
                    : isHi
                        ? 'क्या आप वाकई साइन आउट करना चाहते हैं?'
                        : 'Are you sure you want to sign out?',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(isBn ? 'বাতিল' : isHi ? 'रद्द करें' : 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isBn ? 'লগআউট' : isHi ? 'साइन आउट' : 'Sign Out'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await ref.read(authServiceProvider).signOut();
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          }
        },
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: Text(
          isBn ? 'লগআউট' : isHi ? 'साइन आउट' : 'Sign Out',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDark;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }
}

class _NotLoggedIn extends StatelessWidget {
  final String lang;
  final bool isDark;
  const _NotLoggedIn({required this.lang, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isBn = lang == 'bn';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(AppIcons.profile, size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              isBn ? 'প্রোফাইল দেখতে লগইন করুন' : 'Login to view your profile',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(isBn ? 'লগইন করুন' : 'Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementsSection extends ConsumerWidget {
  final String lang;
  final bool isDark;
  final WidgetRef ref;
  const _AchievementsSection({
    required this.lang,
    required this.isDark,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final achievementsAsync = ref.watch(achievementsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: AppIcons.achievement,
          title: isBn ? 'অর্জন' : isHi ? 'उपलब्धियाँ' : 'Achievements',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        achievementsAsync.when(
          data: (achievements) {
            final unlockedCount = achievements.where((a) => a.isUnlocked).length;
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.warning.withValues(alpha: isDark ? 0.2 : 0.1),
                        AppColors.warning.withValues(alpha: isDark ? 0.1 : 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: isDark ? 0.3 : 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.stars_rounded, color: AppColors.warning, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isBn
                                  ? '$unlockedCount/${achievements.length} অর্জন আনলক করা'
                                  : isHi
                                      ? '$unlockedCount/${achievements.length} उपलब्धियाँ अनलॉक'
                                      : '$unlockedCount/${achievements.length} Achievements Unlocked',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isBn
                                  ? 'আপনার অগ্রগতি ট্র্যাক করুন!'
                                  : isHi
                                      ? 'अपनी प्रगति ट्रैक करें!'
                                      : 'Track your progress!',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${((unlockedCount / achievements.length) * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: achievements.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final achievement = achievements[i];
                      return _AchievementBadge(
                        achievement: achievement,
                        isDark: isDark,
                        isBn: isBn,
                      );
                    },
                  ),
                ),
              ],
            );
          },
          loading: () => Container(
            height: 100,
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final Achievement achievement;
  final bool isDark;
  final bool isBn;
  const _AchievementBadge({
    required this.achievement,
    required this.isDark,
    required this.isBn,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlocked = achievement.isUnlocked;
    return GestureDetector(
      onTap: () => _showAchievementDialog(context),
      child: Container(
        width: 70,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isUnlocked
              ? AppColors.warning.withValues(alpha: isDark ? 0.2 : 0.1)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked
                ? AppColors.warning.withValues(alpha: 0.5)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.shade300),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              achievement.icon,
              style: TextStyle(
                fontSize: 24,
                color: isUnlocked ? null : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              achievement.title,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isUnlocked
                    ? (isDark ? Colors.white : Colors.black87)
                    : Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showAchievementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              achievement.icon,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              achievement.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              achievement.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: achievement.isUnlocked
                    ? AppColors.success.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                achievement.isUnlocked
                    ? (isBn ? '✓ আনলক করা' : '✓ Unlocked')
                    : (isBn ? '🔒 লক করা' : '🔒 Locked'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: achievement.isUnlocked
                      ? AppColors.success
                      : Colors.grey,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
