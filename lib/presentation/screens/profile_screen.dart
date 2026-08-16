// lib/presentation/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../widgets/profile/profile_overview.dart';
import '../widgets/profile/settings_section.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_manager.dart';
import '../../core/theme/app_animations.dart';
import '../../core/constants/app_constants.dart';

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
                        index: 3,
                        child: _UpgradePrompt(lang: lang, isDark: isDark),
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Settings
                    StaggeredListItem(
                      index: 4,
                      child: SettingsSection(
                        lang: lang,
                        themeMode: themeMode,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 24),
                    StaggeredListItem(
                      index: 5,
                      child: _SignOutSection(lang: lang, ref: ref, isDark: isDark),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: Text(
                        '${AppConstants.appName} v1.5.0',
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


