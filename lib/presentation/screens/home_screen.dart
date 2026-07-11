// lib/presentation/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../widgets/quiz_cta_card.dart';
import '../widgets/home_header.dart';
import '../widgets/exam_mode_selector.dart';
import '../widgets/shimmer_loading.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/quiz_scheduler_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_animations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/offline_manager.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final lang = ref.watch(languageProvider);
    final quizAsync = ref.watch(todayQuizProvider);
    final isProAsync = ref.watch(isProProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.homeBackdropDark : AppColors.homeBackdropGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              HomeHeader(lang: lang, isDark: isDark),
              const NetworkStatusBanner(),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    ref.invalidate(todayQuizProvider);
                    ref.invalidate(localStreakProvider);
                    ref.invalidate(localLeaderboardProvider);
                    ref.invalidate(localPersonalBestProvider);
                    ref.invalidate(totalQuizzesProvider);
                    ref.invalidate(totalScoreProvider);
                    ref.invalidate(gamificationNotifierProvider);
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: AppSpacing.paddingScreen,
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // Greeting text with staggered entrance animation
                            StaggeredListItem(
                              index: 0,
                              child: _buildGreeting(context, lang, isDark),
                            ),
                            const SizedBox(height: 12),
                            // Countdown timer
                            StaggeredListItem(
                              index: 1,
                              child: _buildCountdownTimer(context, lang, isDark),
                            ),
                            const SizedBox(height: 16),
                            // Exam Mode Selector
                            StaggeredListItem(
                              index: 2,
                              child: ExamModeSelector(isDark: isDark),
                            ),
                            const SizedBox(height: 16),
                            // Today's Quiz Card
                            StaggeredListItem(
                              index: 3,
                              child: quizAsync.when(
                                data: (quiz) => QuizCtaCard(quiz: quiz, lang: lang),
                                loading: () => const QuizCardShimmer(),
                                error: (e, _) => _buildErrorCard(e.toString(), isDark),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Stats Cards
                            StaggeredListItem(
                              index: 4,
                              child: _buildStatsCards(context, ref, isDark, isBn, isHi),
                            ),
                            const SizedBox(height: 48),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              isProAsync.when(
                data: (isPro) => isPro ? const SizedBox.shrink() : const BannerAdWidget(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Container(
      height: 1,
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.grey.withValues(alpha: 0.12),
    );
  }

  Widget _buildGreeting(BuildContext context, String lang, bool isDark) {
    final hour = DateTime.now().hour;
    String greeting;
    if (lang == 'bn') {
      greeting = hour < 12
          ? 'সুপ্রভাত! 👋'
          : hour < 17
              ? 'শুভ অপরাহ্ন! 👋'
              : 'শুভ সন্ধ্যা! 🌙';
    } else if (lang == 'hi') {
      greeting = hour < 12
          ? 'सुप्रभात! 👋'
          : hour < 17
              ? 'शुभ दोपहर! 👋'
              : 'शुभ संध्या! 🌙';
    } else {
      greeting = hour < 12
          ? 'Good Morning! 👋'
          : hour < 17
              ? 'Good Afternoon! 👋'
              : 'Good Evening! 🌙';
    }
    return Text(
      greeting,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white : AppColors.textPrimaryLight,
      ),
    );
  }

  Widget _buildCountdownTimer(BuildContext context, String lang, bool isDark) {
    final scheduler = QuizSchedulerService.instance;
    final isQuizActive = scheduler.isQuizActive();
    final countdownStr = scheduler.getCountdownString();
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    Color statusColor;
    IconData statusIcon;

    if (isQuizActive) {
      statusColor = AppColors.success;
      statusIcon = Icons.play_circle_filled_rounded;
    } else {
      final now = DateTime.now();
      final startHour = scheduler.quizStartHour;
      if (now.hour >= startHour) {
        statusColor = AppColors.warning;
        statusIcon = AppIcons.timer;
      } else {
        statusColor = AppColors.primary;
        statusIcon = AppIcons.timer;
      }
    }

    return GestureDetector(
      onTap: () => _onCountdownTapped(context, isQuizActive, lang),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: isDark ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isQuizActive
                        ? (isBn
                            ? 'কুইজ চলছে!'
                            : isHi
                                ? 'क्विज़ चल रहा है!'
                                : 'Quiz Live!')
                        : (isBn
                            ? 'পরবর্তী কুইজ'
                            : isHi
                                ? 'अगला क्विज़'
                                : 'Next Quiz'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    countdownStr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              AppIcons.chevronRight,
              color: isDark ? Colors.white54 : Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _onCountdownTapped(
      BuildContext context, bool isQuizActive, String lang) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    if (isQuizActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isBn
              ? 'কুইজ এখন চলছে! শুরু করুন।'
              : isHi
                  ? 'क्विज़ अभी चल रहा है! शुरू करें।'
                  : 'Quiz is live! Start now.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isBn
              ? 'কুইজ এখন সক্রিয় নয়। অনুশীলন মোড ব্যবহার করুন।'
              : isHi
                  ? 'क्विज़ अभी सक्रिय नहीं है। अभ्यास मोड का उपयोग करें।'
                  : 'Quiz not active. Use Practice Mode.'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Widget _buildQuickStrip(
      BuildContext context, WidgetRef ref, String lang, bool isDark) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    final actions = [
      (AppIcons.pvp, AppColors.error, 
       isBn ? 'লড়াই' : isHi ? 'मुकाबला' : 'Battle', () => Navigator.pushNamed(context, '/battle')),
      (AppIcons.leaderboard, AppColors.primary,
       isBn ? 'র‍্যাঙ্ক' : isHi ? 'रैंक' : 'Rank', () => Navigator.pushNamed(context, '/leaderboard')),
      (AppIcons.achievement, AppColors.success,
       isBn ? 'ব্যাজ' : isHi ? 'बैज' : 'Badges', () => Navigator.pushNamed(context, '/achievements')),
      (Icons.card_giftcard_rounded, Colors.purple,
       isBn ? 'আমন্ত্রণ' : isHi ? 'आमंत्रण' : 'Invite', () => _showReferralDialog(context, ref, lang)),
    ];

    return Row(
      children: actions.map((a) {
        return Expanded(
          child: GestureDetector(
            onTap: a.$4,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.withValues(alpha: 0.1),
                ),
                boxShadow: isDark ? null : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: a.$2.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(a.$1, color: a.$2, size: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    a.$3,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
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
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 32),
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
                    : AppColors.textPrimaryLight,
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
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(AppIcons.copy),
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(AppIcons.share),
                label: Text(isBn
                    ? 'শেয়ার করুন'
                    : isHi
                        ? 'সाझा करें'
                        : 'Share'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
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

  Widget _buildStatsCards(
      BuildContext context, WidgetRef ref, bool isDark, bool isBn, bool isHi) {
    final accuracyAsync = ref.watch(overallAccuracyProvider);
    final bestAsync = ref.watch(localPersonalBestProvider);
    final totalAsync = ref.watch(totalQuizzesProvider);
    final totalScoreAsync = ref.watch(totalScoreProvider);

    return Row(
      children: [
        // Accuracy Card
        Expanded(
          child: accuracyAsync.when(
            data: (acc) => _buildStatCard(
              context,
              icon: Icons.percent_rounded,
              value: '${acc.toInt()}%',
              label: isBn ? 'সঠিকতা' : isHi ? 'सटीकता' : 'Accuracy',
              color: AppColors.secondary,
              isDark: isDark,
            ),
            loading: () => const ShimmerBox(height: 96),
            error: (_, __) => _buildStatCard(
              context,
              icon: Icons.percent_rounded,
              value: '0%',
              label: isBn ? 'সঠিকতা' : isHi ? 'सटीकता' : 'Accuracy',
              color: AppColors.secondary,
              isDark: isDark,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Personal Best Card
        Expanded(
          child: bestAsync.when(
            data: (b) => _buildStatCard(
              context,
              icon: AppIcons.achievement,
              value: b.totalQuestions > 0 ? '${b.percentage.toInt()}%' : '--',
              label: isBn ? 'সেরা স্কোর' : isHi ? 'सर्वश्रेष्ठ' : 'Best',
              color: AppColors.primary,
              isDark: isDark,
            ),
            loading: () => const ShimmerBox(height: 96),
            error: (_, __) => _buildStatCard(
              context,
              icon: AppIcons.achievement,
              value: '--',
              label: isBn ? 'সেরা স্কোর' : isHi ? 'सर्वश्रेष्ठ' : 'Best',
              color: AppColors.primary,
              isDark: isDark,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Total Quizzes Card
        Expanded(
          child: totalAsync.when(
            data: (t) => totalScoreAsync.when(
              data: (s) => _buildStatCard(
                context,
                icon: Icons.analytics_rounded,
                value: '$t',
                label: isBn ? 'কুইজ' : isHi ? 'क्विज़' : 'Quizzes',
                color: AppColors.success,
                isDark: isDark,
                subtitle: '+$s pts',
              ),
              loading: () => const ShimmerBox(height: 96),
              error: (_, __) => _buildStatCard(
                context,
                icon: Icons.analytics_rounded,
                value: '$t',
                label: isBn ? 'কুইজ' : isHi ? 'क्विज़' : 'Quizzes',
                color: AppColors.success,
                isDark: isDark,
              ),
            ),
            loading: () => const ShimmerBox(height: 96),
            error: (_, __) => const ShimmerBox(height: 96),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context,
      {required IconData icon,
      required String value,
      required String label,
      required Color color,
      required bool isDark,
      String? subtitle}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 8,
                color: AppColors.success,
                fontWeight: FontWeight.w800,
              ),
            ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardPreview(
      BuildContext context, WidgetRef ref, String lang, bool isDark) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final leaderboardAsync = ref.watch(localLeaderboardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              AppIcons.leaderboard,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              isBn
                  ? "আজকের শীর্ষ"
                  : isHi
                      ? "आज के शीर्ष"
                      : "Today's Top",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/leaderboard'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                isBn ? 'সব দেখুন →' : isHi ? 'सभी देखें →' : 'See all →',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        leaderboardAsync.when(
          data: (entries) {
            if (entries.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    isBn
                        ? 'কুইজ দিয়ে প্রথম হন!'
                        : isHi
                            ? 'क्विज़ देकर पहले बनें!'
                            : 'Be the first to attempt!',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }
            return Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                children: entries.take(5).toList().asMap().entries.map((e) {
                  final entry = e.value;
                  final rank = e.key + 1;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: e.key < entries.length - 1
                          ? Border(
                              bottom: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.withValues(alpha: 0.08),
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.medalForRank(rank),
                          color: rank == 1
                              ? Colors.amber
                              : rank == 2
                                  ? Colors.grey
                                  : rank == 3
                                      ? Colors.brown
                                      : Colors.transparent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '#$rank',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 10),
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            entry.playerName.isNotEmpty ? entry.playerName[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.playerName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getScoreColor(entry.score).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${entry.score}/10',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _getScoreColor(entry.score),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
          loading: () => const LeaderboardShimmer(),
          error: (_, __) => const LeaderboardShimmer(),
        ),
      ],
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 8) return AppColors.success;
    if (score >= 5) return AppColors.warning;
    return AppColors.error;
  }

  Widget _buildErrorCard(String msg, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyFactCard(BuildContext context, String lang, bool isDark) {
    final day = DateTime.now().day;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    final facts = [
      {
        'en': 'The Indian Constitution is the longest written constitution of any sovereign country in the world.',
        'hi': 'भारतीय संविधान दुनिया के किसी भी संप्रभु देश का सबसे लंबा लिखित संविधान है।',
        'bn': 'ভারতের সংবিধান বিশ্বের যেকোনো সার্বভৌম দেশের দীর্ঘতম লিখিত সংবিধান।'
      },
      {
        'en': 'Chanakya (Kautilya) was a pioneer of political science and economics in ancient India.',
        'hi': 'चाणक्य (कौटिल्य) प्राचीन भारत में राजनीति विज्ञान और अर्थशास्त्र के प्रणेता थे।',
        'bn': 'চাণক্য (কৌটিল্য) প্রাচীন ভারতের রাষ্ট্রবিজ্ঞান ও অর্থনীতির পথপ্রদর্শক ছিলেন।'
      },
      {
        'en': 'Zero and the decimal system were developed in ancient India by mathematicians like Aryabhata.',
        'hi': 'प्राचीन भारत में आर्यभट्ट जैसे गणितज्ञों द्वारा शून्य और दशमलव प्रणाली का विकास किया गया था।',
        'bn': 'প্রাচীন ভারতে আর্যভট্টের মতো গণিতবিদদের দ্বারা শূন্য এবং দশমিক পদ্ধতি তৈরি হয়েছিল।'
      },
      {
        'en': 'The national motto of India, "Satyameva Jayate", is taken from the Mundaka Upanishad.',
        'hi': 'भारत का राष्ट्रीय आदर्श वाक्य, "सत्यमेव जयते", मुंडक उपनिषद से लिया गया है।',
        'bn': 'ভারতের জাতীয় স্লোগান, "সত্যমেভ জয়তে", মুণ্ডক উপনিষদ থেকে নেওয়া হয়েছে।'
      },
      {
        'en': 'Rabindranath Tagore is the only person to have written national anthems for two countries: India and Bangladesh.',
        'hi': 'रवींद्रनाथ टैगोर एकमात्र व्यक्ति हैं जिन्होंने दो देशों के लिए राष्ट्रगान लिखा है: भारत और बांग्लादेश।',
        'bn': 'রবীন্দ্রনাথ ঠাকুর হলেন একমাত্র ব্যক্তি যিনি দুটি দেশের জাতীয় সঙ্গীত লিখেছেন: ভারত এবং বাংলাদেশ।'
      },
      {
        'en': 'The Indus Valley Civilization was one of the world\'s earliest urban societies with advanced planning.',
        'hi': 'सिंधु घाटी सभ्यता उन्नत योजना के साथ दुनिया के सबसे शुरुआती शहरी समाजों में से एक थी।',
        'bn': 'সিন্ধু উপত্যকা সভ্যতা ছিল উন্নত নগর পরিকল্পনাসহ বিশ্বের অন্যতম প্রাচীন নগর সমাজ।'
      },
      {
        'en': 'The Reserve Bank of India (RBI) was established on April 1, 1935, based on the Hilton Young Commission.',
        'hi': 'हिल्टन यंग कमीशन के आधार पर 1 अप्रैल, 1935 को भारतीय रिजर्व बैंक (RBI) की स्थापना की गई थी।',
        'bn': 'হিলটন ইয়ং কমিশনের ভিত্তিতে ১৯৩৫ সালের ১ এপ্রিল ভারতীয় রিজার্ভ ব্যাঙ্ক (RBI) প্রতিষ্ঠিত হয়।'
      }
    ];

    final fact = facts[day % facts.length];
    final factText = fact[lang] ?? fact['en']!;

    final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final borderCol = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.1);
    final titleColor = isDark ? AppColors.accent : AppColors.primary;
    final textColor = isDark ? Colors.white70 : AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBn ? 'দৈনিক তথ্য' : isHi ? 'दैनिक तथ्य' : 'Did You Know?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  factText,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
