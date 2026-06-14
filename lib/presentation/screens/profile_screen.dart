// lib/presentation/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_manager.dart';
import '../../core/services/question_tracking_service.dart';
import '../widgets/gamification_bar.dart';

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
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      body: authAsync.when(
        data: (user) {
          if (user == null) {
            return _NotLoggedIn(lang: lang, isDark: isDark);
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _ProfileHeader(
                  user: user,
                  lang: lang,
                  isDark: isDark,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _StatsSection(lang: lang, isDark: isDark, ref: ref),
                    const SizedBox(height: 16),
                    const DailyRewardBanner(),
                    const SizedBox(height: 8),
                    const DailyChallengesCard(),
                    const SizedBox(height: 8),
                    const GamificationBar(),
                    const SizedBox(height: 24),
                    _AchievementsSection(lang: lang, isDark: isDark, ref: ref),
                    // Exam mode stats - commented out as not required
                    // const SizedBox(height: 24),
                    // _ExamModeStatsSection(lang: lang, isDark: isDark, ref: ref),
                    // const SizedBox(height: 24),
                    // _ExamModeSection(lang: lang, isDark: isDark, ref: ref),
                    const SizedBox(height: 24),
                    if (user.isAnonymous)
                      _UpgradePrompt(lang: lang, ref: ref, isDark: isDark),
                    const SizedBox(height: 24),
                    // Go Pro section - commented out as not required
                    // _ProCard(lang: lang, isDark: isDark),
                    // const SizedBox(height: 24),
                    _SettingsSection(
                      lang: lang,
                      ref: ref,
                      themeMode: themeMode,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),
                    _DisclaimerSection(lang: lang, isDark: isDark),
                    const SizedBox(height: 24),
                    _SignOutSection(lang: lang, ref: ref, isDark: isDark),
                    const SizedBox(height: 32),
                    Center(
                      child: Text(
                        'GK Quiz Daily v1.1.0',
                        style: TextStyle(
                          fontSize: 11,
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
        loading: () => Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
        ),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              Text(
                isBn
                    ? 'কিছু সমস্যা হয়েছে'
                    : isHi
                        ? 'कुछ समस्या हुई'
                        : 'Something went wrong',
                style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final dynamic user;
  final String lang;
  final bool isDark;
  const _ProfileHeader({
    required this.user,
    required this.lang,
    required this.isDark,
  });

  bool get _isBn => lang == 'bn';
  bool get _isHi => lang == 'hi';

  @override
  Widget build(BuildContext context) {
    final isBn = lang == 'bn';
    return Container(
      decoration: BoxDecoration(
        gradient:
            isDark ? AppTheme.primaryGradientDark : AppTheme.primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white, size: 20),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.workspace_premium_rounded,
                                color: Colors.amber.shade300, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              _isBn
                                  ? 'বিনামূল্যে'
                                  : _isHi
                                      ? 'मुफ्त'
                                      : 'Free',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 42,
                          backgroundImage:
                              user.photoURL != null && user.photoURL!.isNotEmpty
                                  ? NetworkImage(user.photoURL!)
                                  : null,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: user.photoURL == null || user.photoURL!.isEmpty
                              ? Text(
                                  (user.displayName?.isNotEmpty == true
                                          ? user.displayName!
                                          : 'U')[0]
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      if (user.isAnonymous)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.warningColor
                                    .withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person_outline,
                              color: Colors.white, size: 14),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.displayName ?? 'Quiz Warrior',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (user.email != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  if (user.isAnonymous) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 14),
                          const SizedBox(width: 6),
                          Text(
                            isBn ? 'অতিথি ব্যবহারকারী' : 'Guest User',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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

  bool get _isBn => lang == 'bn';
  bool get _isHi => lang == 'hi';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(localStreakProvider);
    final totalQuizzesAsync = ref.watch(totalQuizzesProvider);
    final personalBestAsync = ref.watch(localPersonalBestProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.analytics_rounded,
          title: _isBn
              ? 'পরিসংখ্যান'
              : _isHi
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
                  icon: Icons.local_fire_department_rounded,
                  iconColor: AppTheme.warningColor,
                  value: '${streak.currentStreak}',
                  label: _isBn
                      ? 'ধারাবাহিকতা'
                      : _isHi
                          ? 'लगातार'
                          : 'Streak',
                  sublabel: _isBn
                      ? 'দিন'
                      : _isHi
                          ? 'दिन'
                          : 'days',
                  isDark: isDark,
                ),
                loading: () => _StatCardSkeleton(isDark: isDark),
                error: (_, __) => _StatCard(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: AppTheme.warningColor,
                  value: '0',
                  label: _isBn
                      ? 'ধারাবাহিকতা'
                      : _isHi
                          ? 'लगातार'
                          : 'Streak',
                  sublabel: _isBn
                      ? 'দিন'
                      : _isHi
                          ? 'दिन'
                          : 'days',
                  isDark: isDark,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: totalQuizzesAsync.when(
                data: (count) => _StatCard(
                  icon: Icons.quiz_rounded,
                  iconColor: AppTheme.primaryColor,
                  value: '$count',
                  label: _isBn
                      ? 'মোট কুইজ'
                      : _isHi
                          ? 'कुल क्विज़'
                          : 'Total Quizzes',
                  sublabel: _isBn
                      ? 'খেলা হয়েছে'
                      : _isHi
                          ? 'खेले'
                          : 'played',
                  isDark: isDark,
                ),
                loading: () => _StatCardSkeleton(isDark: isDark),
                error: (_, __) => _StatCard(
                  icon: Icons.quiz_rounded,
                  iconColor: AppTheme.primaryColor,
                  value: '0',
                  label: _isBn
                      ? 'মোট কুইজ'
                      : _isHi
                          ? 'कुल क्विज़'
                          : 'Total Quizzes',
                  sublabel: _isBn
                      ? 'খেলা হয়েছে'
                      : _isHi
                          ? 'खेले'
                          : 'played',
                  isDark: isDark,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: personalBestAsync.when(
                data: (best) => _StatCard(
                  icon: Icons.emoji_events_rounded,
                  iconColor: AppTheme.successColor,
                  value: '${best.percentage.toInt()}%',
                  label: _isBn
                      ? 'সেরা স্কোর'
                      : _isHi
                          ? 'सर्वश्रेष्ठ स्कोर'
                          : 'Best Score',
                  sublabel: _isBn
                      ? 'শতাংশ'
                      : _isHi
                          ? 'प्रतिशत'
                          : '%',
                  isDark: isDark,
                ),
                loading: () => _StatCardSkeleton(isDark: isDark),
                error: (_, __) => _StatCard(
                  icon: Icons.emoji_events_rounded,
                  iconColor: AppTheme.successColor,
                  value: '—',
                  label: _isBn
                      ? 'সেরা স্কোর'
                      : _isHi
                          ? 'सर्वश्रेष्ठ स्कोर'
                          : 'Best Score',
                  sublabel: _isBn
                      ? 'শতাংশ'
                      : _isHi
                          ? 'प्रतिशत'
                          : '%',
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : iconColor).withValues(alpha: 0.1),
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
              color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
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
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamModeSection extends StatelessWidget {
  final String lang;
  final bool isDark;
  final WidgetRef ref;
  const _ExamModeSection({
    required this.lang,
    required this.isDark,
    required this.ref,
  });

  bool get _isBn => lang == 'bn';
  bool get _isHi => lang == 'hi';

  @override
  Widget build(BuildContext context) {
    final modes = ['GENERAL', 'WBPSC', 'SSC', 'UPSC', 'BANK'];
    final current = ref.watch(examModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.school_rounded,
          title: _isBn
              ? 'পরীক্ষার মোড'
              : _isHi
                  ? 'परीक्षा मोड'
                  : 'Exam Mode',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : AppTheme.primaryColor)
                    .withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: modes.map((m) {
              final selected = m == current;
              return GestureDetector(
                onTap: () => ref.read(examModeProvider.notifier).state = m,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? (isDark
                            ? AppTheme.primaryGradientDark
                            : AppTheme.primaryGradient)
                        : null,
                    color: selected
                        ? null
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(12),
                    border: selected
                        ? null
                        : Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.grey.withValues(alpha: 0.2),
                          ),
                  ),
                  child: Text(
                    m,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.grey.shade700),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
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

  bool get _isBn => lang == 'bn';
  bool get _isHi => lang == 'hi';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.warningColor.withValues(alpha: isDark ? 0.15 : 0.08),
            AppTheme.warningColor.withValues(alpha: isDark ? 0.08 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: isDark ? 0.3 : 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.link_rounded,
                color: AppTheme.warningColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isBn ? 'অ্যাকাউন্ট সংযুক্ত করুন' : 'Link Your Account',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warningColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isBn
                      ? 'আপনার অগ্রগতি সংরক্ষণ করতে'
                      : _isHi
                          ? 'अपनी प्रगति स्थायी रूप से सहेजें'
                          : 'To save your progress permanently',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.warningColor.withValues(alpha: 0.8),
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
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _isBn ? 'সংযুক্ত করুন' : 'Link',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProCard extends StatelessWidget {
  final String lang;
  final bool isDark;
  const _ProCard({required this.lang, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isBn = lang == 'bn';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF9F67FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryColor.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                isBn ? 'গো প্রো সদস্যতা' : 'Go Pro',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '₹49/mo',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProFeature(
            icon: Icons.block_rounded,
            text: isBn ? 'কোনো বিজ্ঞাপন নেই' : 'Ad-free experience',
          ),
          _ProFeature(
            icon: Icons.all_inclusive_rounded,
            text: isBn ? 'সীমাহীন অনুশীলন' : 'Unlimited practice sets',
          ),
          _ProFeature(
            icon: Icons.analytics_rounded,
            text: isBn ? 'বিস্তারিত বিশ্লেষণ' : 'Detailed analytics',
          ),
          _ProFeature(
            icon: Icons.picture_as_pdf_rounded,
            text: isBn ? 'পিডিএফ নোটস' : 'PDF notes',
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  isBn ? 'আপগ্রেড করুন' : 'Upgrade Now',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.secondaryColor,
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

class _ProFeature extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ProFeature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, color: Colors.white70, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String lang;
  final WidgetRef ref;
  final AppThemeMode themeMode;
  final bool isDark;
  const _SettingsSection({
    required this.lang,
    required this.ref,
    required this.themeMode,
    required this.isDark,
  });

  bool get _isBn => lang == 'bn';
  bool get _isHi => lang == 'hi';

  @override
  Widget build(BuildContext context) {
    final soundSettings = ref.watch(soundSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.settings_rounded,
          title: _isBn
              ? 'সেটিংস'
              : _isHi
                  ? 'सेटिंग्स'
                  : 'Settings',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
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
          child: Column(
            children: [
              _SettingsTile(
                icon: Icons.volume_up_rounded,
                iconColor: AppTheme.primaryColor,
                label: _isBn
                    ? 'শব্দ ও ফিডব্যাক'
                    : _isHi
                        ? 'ध्वनि और फीडबैक'
                        : 'Sound & Feedback',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                ),
                onTap: () => _showSoundSettings(
                    context, ref, lang, isDark, soundSettings),
                isDark: isDark,
                showDivider: true,
              ),
              _SettingsTile(
                icon: Icons.notifications_rounded,
                iconColor: AppTheme.primaryColor,
                label: _isBn
                    ? 'বিজ্ঞপ্তি'
                    : _isHi
                        ? 'सूचनाएं'
                        : 'Notifications',
                trailing: Switch.adaptive(
                  value: true,
                  onChanged: (_) {},
                  activeColor: AppTheme.primaryColor,
                ),
                isDark: isDark,
                showDivider: true,
              ),
              _SettingsTile(
                icon: Icons.dark_mode_rounded,
                iconColor: AppTheme.secondaryColor,
                label: _isBn
                    ? 'ডার্ক মোড'
                    : _isHi
                        ? 'डार्क मोड'
                        : 'Dark Mode',
                trailing: _ThemeBadge(mode: themeMode, isDark: isDark),
                onTap: () => _showThemePicker(context, ref, themeMode, lang),
                isDark: isDark,
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSoundSettings(BuildContext context, WidgetRef ref, String lang,
      bool isDark, soundSettings) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.volume_up_rounded,
                          color: AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isBn
                          ? 'শব্দ সেটিংস'
                          : isHi
                              ? 'ध्वनि सेटिंग्स'
                              : 'Sound Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SoundToggle(
                  title: isBn
                      ? 'সকল শব্দ'
                      : isHi
                          ? 'सभी ध्वनि'
                          : 'All Sounds',
                  subtitle: isBn
                      ? 'শব্দ চালু/বন্ধ করুন'
                      : isHi
                          ? 'ध्वनि चालू/बंद करें'
                          : 'Enable/disable all sounds',
                  value: soundSettings.soundEnabled,
                  onChanged: (v) => ref
                      .read(soundSettingsProvider.notifier)
                      .setSoundEnabled(v),
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _SoundToggle(
                  title: isBn
                      ? 'ট্যাপ ফিডব্যাক'
                      : isHi
                          ? 'टैप फीडबैक'
                          : 'Tap Feedback',
                  subtitle: isBn
                      ? 'বোতাম ট্যাপে শব্দ'
                      : isHi
                          ? 'बटन पर टैप करने पर ध्वनि'
                          : 'Sound on button tap',
                  value: soundSettings.tapFeedback,
                  enabled: soundSettings.soundEnabled,
                  onChanged: (v) => ref
                      .read(soundSettingsProvider.notifier)
                      .setTapFeedback(v),
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _SoundToggle(
                  title: isBn
                      ? 'সঠিক উত্তর শব্দ'
                      : isHi
                          ? 'सही उत्तर ध्वनि'
                          : 'Correct Answer Sound',
                  subtitle: isBn
                      ? 'সঠিক উত্তরে শব্দ'
                      : isHi
                          ? 'सही उत्तर पर ध्वनि'
                          : 'Sound on correct answer',
                  value: soundSettings.correctAnswerSound,
                  enabled: soundSettings.soundEnabled,
                  onChanged: (v) => ref
                      .read(soundSettingsProvider.notifier)
                      .setCorrectSound(v),
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _SoundToggle(
                  title: isBn
                      ? 'ভুল উত্তর শব্দ'
                      : isHi
                          ? 'गलत उत्तर ध्वनि'
                          : 'Wrong Answer Sound',
                  subtitle: isBn
                      ? 'ভুল উত্তরে শব্দ'
                      : isHi
                          ? 'गलत उत्तर पर ध्वनि'
                          : 'Sound on wrong answer',
                  value: soundSettings.wrongAnswerSound,
                  enabled: soundSettings.soundEnabled,
                  onChanged: (v) =>
                      ref.read(soundSettingsProvider.notifier).setWrongSound(v),
                  isDark: isDark,
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref,
      AppThemeMode currentMode, String lang) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isBn
                  ? 'থিম নির্বাচন করুন'
                  : isHi
                      ? 'थीम चुनें'
                      : 'Choose Theme',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : null,
                  ),
            ),
            const SizedBox(height: 16),
            ...[
              (
                AppThemeMode.system,
                Icons.settings_suggest_rounded,
                isBn
                    ? 'সিস্টেম'
                    : isHi
                        ? 'सिस्टम'
                        : 'System',
                isBn
                    ? 'আপনার ডিভাইস অনুসরণ করুন'
                    : isHi
                        ? 'अपने डिवाइस का पालन करें'
                        : 'Follow your device'
              ),
              (
                AppThemeMode.light,
                Icons.light_mode_rounded,
                isBn
                    ? 'লাইট'
                    : isHi
                        ? 'लाइट'
                        : 'Light',
                isBn
                    ? 'হালকা থিম'
                    : isHi
                        ? 'हल्का थीम'
                        : 'Always light theme'
              ),
              (
                AppThemeMode.dark,
                Icons.dark_mode_rounded,
                isBn
                    ? 'ডার্ক'
                    : isHi
                        ? 'डार्क'
                        : 'Dark',
                isBn
                    ? 'অন্ধকার থিম'
                    : isHi
                        ? 'डार्क थीम'
                        : 'Always dark theme'
              ),
            ].map((item) {
              final mode = item.$1;
              final icon = item.$2;
              final label = item.$3;
              final desc = item.$4;
              final selected = mode == currentMode;
              return GestureDetector(
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  Navigator.pop(context);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? LinearGradient(
                            colors: [
                              AppTheme.primaryColor.withValues(alpha: 0.15),
                              AppTheme.primaryColor.withValues(alpha: 0.05),
                            ],
                          )
                        : null,
                    color: selected ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AppTheme.primaryColor.withValues(alpha: 0.5)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey.withValues(alpha: 0.15)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.primaryColor.withValues(alpha: 0.15)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.grey.withValues(alpha: 0.1)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon,
                            size: 20,
                            color: selected
                                ? AppTheme.primaryColor
                                : (isDark
                                    ? Colors.white60
                                    : Colors.grey.shade600)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? AppTheme.primaryColor
                                      : (isDark ? Colors.white : null),
                                )),
                            Text(desc,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey.shade500,
                                )),
                          ],
                        ),
                      ),
                      if (selected)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 14),
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ThemeBadge extends StatelessWidget {
  final AppThemeMode mode;
  final bool isDark;
  const _ThemeBadge({required this.mode, required this.isDark});

  @override
  Widget build(BuildContext context) {
    String label;
    IconData icon;
    switch (mode) {
      case AppThemeMode.system:
        label = 'Auto';
        icon = Icons.settings_suggest_rounded;
        break;
      case AppThemeMode.light:
        label = 'Light';
        icon = Icons.light_mode_rounded;
        break;
      case AppThemeMode.dark:
        label = 'Dark';
        icon = Icons.dark_mode_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool isDark;
  final bool showDivider;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.trailing,
    this.onTap,
    required this.isDark,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: iconColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                  ),
                  trailing,
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.withValues(alpha: 0.1),
            ),
          ),
      ],
    );
  }
}

class _DisclaimerSection extends StatelessWidget {
  final String lang;
  final bool isDark;
  const _DisclaimerSection({required this.lang, required this.isDark});

  bool get _isBn => lang == 'bn';
  bool get _isHi => lang == 'hi';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.info_outline_rounded,
          title: _isBn
              ? 'দাবিত্যাগ ও উৎস'
              : _isHi
                  ? 'अस्वीकरण और स्रोत'
                  : 'Disclaimer & Sources',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
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
          child: Column(
            children: [
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                iconColor: AppTheme.warningColor,
                label: _isBn
                    ? 'দাবিত্যাগ ও উৎস'
                    : _isHi
                        ? 'अस्वीकरण और स्रोत'
                        : 'Disclaimer & Sources',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                ),
                onTap: () => Navigator.pushNamed(context, '/disclaimer'),
                isDark: isDark,
                showDivider: false,
              ),
            ],
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
              backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.logout_rounded,
                        color: AppTheme.errorColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isBn
                        ? 'লগআউট করুন?'
                        : isHi
                            ? 'साइन आउट करें?'
                            : 'Sign out?',
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
                  child: Text(isBn
                      ? 'বাতিল'
                      : isHi
                          ? 'रद्द करें'
                          : 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isBn
                      ? 'লগআউট'
                      : isHi
                          ? 'साइन आउट'
                          : 'Sign Out'),
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
          isBn
              ? 'লগআউট'
              : isHi
                  ? 'साइन आउट'
                  : 'Sign Out',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.errorColor,
          side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.4)),
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
            color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : null,
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
                    AppTheme.primaryColor.withValues(alpha: 0.15),
                    AppTheme.primaryColor.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_rounded,
                  size: 56, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 24),
            Text(
              isBn ? 'প্রোফাইল দেখতে লগইন করুন' : 'Login to view your profile',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : null,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
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
          icon: Icons.emoji_events_rounded,
          title: isBn
              ? 'অর্জন'
              : isHi
                  ? 'उपलब्धियाँ'
                  : 'Achievements',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        achievementsAsync.when(
          data: (achievements) {
            final unlockedCount =
                achievements.where((a) => a.isUnlocked).length;
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.warningColor
                            .withValues(alpha: isDark ? 0.2 : 0.1),
                        AppTheme.warningColor
                            .withValues(alpha: isDark ? 0.1 : 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.warningColor
                          .withValues(alpha: isDark ? 0.3 : 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.stars_rounded,
                            color: AppTheme.warningColor, size: 24),
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
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isBn
                                  ? 'আপনার ট্র্যাক করা অগ্রগতি দেখুন!'
                                  : isHi
                                      ? 'अपनी ट्रैक की गई प्रगति देखें!'
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${((unlockedCount / achievements.length) * 100).round()}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.warningColor,
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
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade200,
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
              ? AppTheme.warningColor.withValues(alpha: isDark ? 0.2 : 0.1)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked
                ? AppTheme.warningColor.withValues(alpha: 0.5)
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
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
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
                    ? AppTheme.successColor.withValues(alpha: 0.2)
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
                      ? AppTheme.successColor
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

class _ExamModeStatsSection extends ConsumerWidget {
  final String lang;
  final bool isDark;
  final WidgetRef ref;
  const _ExamModeStatsSection({
    required this.lang,
    required this.isDark,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final modeStatsAsync = ref.watch(modeStatsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.analytics_rounded,
          title: isBn
              ? 'পরীক্ষার পরিসংখ্যান'
              : isHi
                  ? 'परीक्षा आंकड़े'
                  : 'Exam Statistics',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        modeStatsAsync.when(
          data: (statsMap) {
            final modes = ['GENERAL', 'WBPSC', 'SSC', 'UPSC', 'BANK'];
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.black : AppTheme.primaryColor)
                        .withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: modes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final mode = entry.value;
                  final stats = statsMap[mode]!;
                  final isLast = index == modes.length - 1;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : Border(
                              bottom: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.withValues(alpha: 0.1),
                              ),
                            ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getModeColor(mode)
                                .withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getModeIcon(mode),
                            color: _getModeColor(mode),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mode,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                isBn
                                    ? '${stats.quizzesPlayed} কুইজ · ${stats.formattedTime} সময়'
                                    : isHi
                                        ? '${stats.quizzesPlayed} क्विज़ · ${stats.formattedTime} समय'
                                        : '${stats.quizzesPlayed} quizzes · ${stats.formattedTime} time',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${stats.averageScore}%',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: _getScoreColor(stats.averageScore),
                              ),
                            ),
                            Text(
                              isBn
                                  ? 'গড়'
                                  : isHi
                                      ? 'औसत'
                                      : 'avg',
                              style: TextStyle(
                                fontSize: 9,
                                color: isDark ? Colors.white38 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
          loading: () => Container(
            height: 200,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Color _getModeColor(String mode) {
    switch (mode) {
      case 'GENERAL':
        return AppTheme.primaryColor;
      case 'WBPSC':
        return const Color(0xFF6366F1);
      case 'SSC':
        return const Color(0xFFF59E0B);
      case 'UPSC':
        return const Color(0xFFEF4444);
      case 'BANK':
        return AppTheme.successColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _getModeIcon(String mode) {
    switch (mode) {
      case 'GENERAL':
        return Icons.public_rounded;
      case 'WBPSC':
        return Icons.account_balance_rounded;
      case 'SSC':
        return Icons.assignment_rounded;
      case 'UPSC':
        return Icons.school_rounded;
      case 'BANK':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.quiz_rounded;
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppTheme.successColor;
    if (score >= 60) return AppTheme.warningColor;
    if (score > 0) return AppTheme.errorColor;
    return Colors.grey;
  }
}

class _SoundToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  const _SoundToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    this.enabled = true,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}
