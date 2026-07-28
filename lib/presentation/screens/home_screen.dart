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

                            // 3. 1v1 Battle Arena Card
                            StaggeredListItem(
                              index: 2,
                              child: _buildBattleCard(context, isDark, isBn, isHi),
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

  Widget _buildBattleCard(
      BuildContext context, bool isDark, bool isBn, bool isHi) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF0D9488), const Color(0xFF115E59)]
              : [const Color(0xFFF0FDFA), const Color(0xFFCCFBF1), const Color(0xFF99F6E4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: isDark ? 0.35 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -25,
              bottom: -25,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: isDark ? 0.08 : 0.04),
                  shape: BoxShape.circle,
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
                              isBn ? '১ বনাম ১ কুইজ যুদ্ধ' : isHi ? '1 बनाम 1 क्विज़ युद्ध' : '1v1 Quiz Battle',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isBn
                                  ? 'লাইভ কুইজ লড়াইয়ে বন্ধুদের চ্যালেঞ্জ করুন অথবা বটের সাথে অনুশীলন করুন।'
                                  : isHi
                                      ? 'लाइव क्विज़ लड़ाई में दोस्तों को चुनौती दें या बॉट के साथ अभ्यास करें।'
                                      : 'Duel friends in real-time online, or train offline against a bot.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.success.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: AppColors.success,
                          size: 22,
                        ),
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            isBn ? 'যুদ্ধ শুরু করুন' : isHi ? 'युद्ध शुरू करें' : 'Play Battle',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
