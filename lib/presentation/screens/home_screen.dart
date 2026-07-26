// lib/presentation/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../widgets/quiz_cta_card.dart';
import '../widgets/home_header.dart';
import '../widgets/practice_card.dart';
import '../widgets/shimmer_loading.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/quiz_scheduler_service.dart';
import '../../core/services/quiz/quiz_timing_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_animations.dart';
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
    QuizTimingManager.instance.listenToTimingChanges();
    QuizSchedulerService.instance.refreshTiming(force: true).then((_) {
      if (mounted) setState(() {});
    });
    QuizTimingManager.instance.timingVersion.addListener(_onTimingChanged);
  }

  void _onTimingChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    QuizTimingManager.instance.timingVersion.removeListener(_onTimingChanged);
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // 1. Focal Hero Quiz Card (Today's Daily Quiz)
                            StaggeredListItem(
                              index: 0,
                              child: quizAsync.when(
                                data: (quiz) => QuizCtaCard(quiz: quiz, lang: lang),
                                loading: () => const QuizCardShimmer(),
                                error: (e, _) => _buildErrorCard(e.toString(), isDark),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 2. Practice Arena Card
                            StaggeredListItem(
                              index: 1,
                              child: PracticeArenaCard(lang: lang),
                            ),
                            const SizedBox(height: 16),

                            // 3. Performance Stats Row (Accuracy, Best Score, Total Quizzes)
                            StaggeredListItem(
                              index: 2,
                              child: _buildStatsCards(context, ref, isDark, isBn, isHi),
                            ),
                            const SizedBox(height: 32),
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
            loading: () => const ShimmerBox(height: 80),
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
        const SizedBox(width: 10),
        // Personal Best Card
        Expanded(
          child: bestAsync.when(
            data: (b) => _buildStatCard(
              context,
              icon: AppIcons.achievement,
              value: b.totalQuestions > 0 ? '${b.percentage.toInt()}%' : '--',
              label: isBn ? 'সেরা স্কোর' : isHi ? 'সর্বश्रेष्ठ' : 'Best',
              color: AppColors.primary,
              isDark: isDark,
            ),
            loading: () => const ShimmerBox(height: 80),
            error: (_, __) => _buildStatCard(
              context,
              icon: AppIcons.achievement,
              value: '--',
              label: isBn ? 'সেরা স্কোর' : isHi ? 'সর্বश्रेष्ठ' : 'Best',
              color: AppColors.primary,
              isDark: isDark,
            ),
          ),
        ),
        const SizedBox(width: 10),
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
              loading: () => const ShimmerBox(height: 80),
              error: (_, __) => _buildStatCard(
                context,
                icon: Icons.analytics_rounded,
                value: '$t',
                label: isBn ? 'কুইজ' : isHi ? 'क्विज़' : 'Quizzes',
                color: AppColors.success,
                isDark: isDark,
              ),
            ),
            loading: () => const ShimmerBox(height: 80),
            error: (_, __) => const ShimmerBox(height: 80),
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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.15 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Failed to load quiz. Please check internet connection.',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
