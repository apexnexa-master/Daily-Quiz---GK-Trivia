// lib/presentation/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../widgets/profile/profile_overview.dart';
import '../widgets/profile/settings_section.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_manager.dart';
import '../../core/theme/app_animations.dart';
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
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            });
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
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
                    if (user.isAnonymous) ...[
                      StaggeredListItem(
                        index: 5,
                        child: _UpgradePrompt(lang: lang, isDark: isDark),
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
                      child: _SignOutSection(lang: lang, ref: ref, isDark: isDark),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: Text(
                        'BrainX v1.5.0',
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

class _UpgradePrompt extends StatelessWidget {
  final String lang;
  final bool isDark;
  const _UpgradePrompt({
    required this.lang,
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
                  isBn
                      ? 'আপনার অগ্রগতি সংরক্ষণ করতে লগইন করুন'
                      : isHi
                          ? 'अपनी प्रगति सहेजने के लिए लॉगिन करें'
                          : 'Sign In to Save Your Progress',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.warning : AppColors.warningDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isBn
                      ? 'দৈনিক চ্যালেঞ্জ খেলুন এবং লিডারবোর্ডে উপরে উঠুন'
                      : isHi
                          ? 'दैनिक चुनौतियां खेलें और लीडरबोर्ड पर चढ़ें'
                          : 'Play daily challenges and climb the leaderboard.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.warning.withValues(alpha: 0.8) : AppColors.warningDark.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isBn ? 'লগইন' : 'Login',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
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
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.warning : AppColors.warningDark,
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
