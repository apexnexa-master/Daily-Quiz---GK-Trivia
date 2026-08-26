// lib/presentation/screens/home_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_providers.dart';
import '../providers/scoring_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/quiz_scheduler_service.dart';
import '../../core/utils/offline_manager.dart';
import '../../core/services/daily_progress_service.dart';
import '../widgets/game_card.dart';
import '../widgets/workout_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/daily_challenge_auth.dart';
import '../../routes/app_router.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _countdownTimer;
  String _savedUsername = 'Explorer';
  String _savedPhotoUrl = '';

  @override
  void initState() {
    super.initState();
    _loadSavedIdentity();
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    QuizSchedulerService.instance.refreshTiming(force: true).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadSavedIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedUsername = prefs.getString('temp_username') ?? 'Explorer';
      _savedPhotoUrl = prefs.getString('temp_photo_url') ?? '';
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
    final dailyProgressAsync = ref.watch(dailyProgressProvider);
    final brainStatsAsync = ref.watch(brainStatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    // Retrieve username and photo from currentUserProvider
    final currentUser = ref.watch(currentUserProvider).value;

    // Daily progress metrics (streak, daily goal, brain score)
    final dailyProgress = dailyProgressAsync.value ?? const DailyProgress();
    final streak = dailyProgress.currentStreak;
    // Metrics are hidden for guests and logged-out users.
    final isGuest = currentUser?.isAnonymous ?? true;
    // Gamification stats drive the XP matrix (level + total XP).
    final gamificationStats = ref.watch(gamificationNotifierProvider).value;
    final xp = gamificationStats?.xp ?? 0;
    final level = gamificationStats?.level ?? 1;

    return Scaffold(
      body: Stack(
        children: [
          // Base slate backdrop.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppColors.homeBackdropDark
                    : AppColors.homeBackdropGradient,
              ),
            ),
          ),
          // Ambient neon glows (BRAINX glassmorphism atmosphere) — dark mode only.
          if (isDark) ...[
            const Positioned(
              top: -90,
              left: -70,
              child: _GlowBlob(color: AppColors.neonCyan, size: 260),
            ),
            const Positioned(
              top: 300,
              right: -100,
              child: _GlowBlob(color: AppColors.neonViolet, size: 220),
            ),
            const Positioned(
              bottom: -120,
              right: -80,
              child: _GlowBlob(color: AppColors.neonLime, size: 300),
            ),
          ],
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Custom Header Bar matching BrainX branding
                _buildTopAppBar(context, streak, isBn, isHi),
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
                      ref.invalidate(dailyProgressProvider);
                      ref.invalidate(currentUserProvider);
                      ref.invalidate(brainStatsProvider);
                      ref.invalidate(myWeeklyRankProvider);
                      await _loadSavedIdentity();
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              // Top Metrics Bento Bar (guests see a login prompt instead)
                              if (isGuest)
                                _buildGuestLoginCard(
                                    context, isBn, isHi, isDark)
                              else ...[
                                _buildBrainSkillsHeader(
                                    context, isBn, isHi, isDark),
                                const SizedBox(height: 10),
                                _buildMetricsBentoBox(
                                  dailyProgress,
                                  brainStatsAsync.value,
                                  xp,
                                  level,
                                  isBn,
                                  isHi,
                                  isDark,
                                ),
                              ],
                              const SizedBox(height: 20),

                              // Main Bento Layout
                              // Recommended Workout Card (Bento Large)
                              _buildWorkoutCard(
                                  quizAsync, context, isBn, isHi, isDark),
                              const SizedBox(height: 16),

                              // Quick Brain Workout (one-tap multi-game session)
                              QuickBrainWorkoutCard(lang: lang),
                              const SizedBox(height: 24),

                              // Recommended Games — standalone quick-play games
                              _buildRecommendedGamesSection(
                                  context, isBn, isHi, isDark),
                              const SizedBox(height: 24),

                              const SizedBox(height: 100),
                            ]),
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
    );
  }

  Widget _buildTopAppBar(BuildContext context, int streak, bool isBn, bool isHi) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider).value;
    final photoUrl = (currentUser?.photoUrl?.isNotEmpty == true)
        ? currentUser!.photoUrl!
        : (_savedPhotoUrl.isNotEmpty ? _savedPhotoUrl : null);
    final username = currentUser?.displayName ?? _savedUsername;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Streak pill — fire symbol + number only; tap to learn how it grows.
          GestureDetector(
            onTap: () => _showStreakDialog(context, streak, isBn, isHi, isDark),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: isDark ? 0.08 : 0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFFF97316).withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 16,
                    color: Color(0xFFF97316),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$streak',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Avatar + name pill (same component style as the streak pill).
          Flexible(
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/profile'),
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: isDark ? 0.08 : 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? AppColors.neonCyan.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: photoUrl != null
                            ? Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _avatarPlaceholder(isDark),
                              )
                            : _avatarPlaceholder(isDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        username,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder(bool isDark) {
    return Container(
      color: (isDark ? AppColors.primary : AppColors.primaryDark)
          .withValues(alpha: 0.15),
      child: Icon(
        Icons.person_rounded,
        color: isDark ? AppColors.primary : AppColors.primaryDark,
        size: 20,
      ),
    );
  }

  Widget _buildBrainSkillsHeader(
      BuildContext context, bool isBn, bool isHi, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.insights_rounded, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Text(
              isBn ? 'মস্তিষ্ক ও দক্ষতা' : isHi ? 'मस्तिष्क और कौशल' : 'Brain Skills',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: () {
            ref.invalidate(brainStatsProvider);
            ref.invalidate(myWeeklyRankProvider);
            Navigator.pushNamed(context, '/stats');
          },
          icon: Icon(
            Icons.view_agenda_rounded,
            size: 16,
            color: isDark ? AppColors.primary : AppColors.primaryDark,
          ),
          label: Text(
            isBn ? 'সব দেখুন' : isHi ? 'सभी देखें' : 'View All',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.primary : AppColors.primaryDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsBentoBox(DailyProgress dailyProgress,
      BrainStatsBundle? brainStats, int xp, int level, bool isBn, bool isHi, bool isDark) {
    // Engine Brain Score with a safe legacy fallback (before the first scored
    // session the engine has no data yet).
    final engine = brainStats?.brain.score ?? 0;
    final brainScore =
        engine > 0 ? engine : (dailyProgress.brainScore.clamp(0, 100));
    final gamesCompleted =
        dailyProgress.dailyGamesCompleted.clamp(0, dailyProgress.dailyGoal);
    final dailyGoal = dailyProgress.dailyGoal;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF131A30).withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? AppColors.neonCyan.withValues(alpha: 0.22)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : AppColors.primary)
                    .withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              if (isDark)
                BoxShadow(
                  color: AppColors.neonCyan.withValues(alpha: 0.08),
                  blurRadius: 28,
                  spreadRadius: -2,
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Daily Goal with mini progress bar
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showDailyGoalDialog(
                      context, dailyProgress, isBn, isHi, isDark),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            dailyProgress.isDailyGoalComplete
                                ? Icons.emoji_events_rounded
                                : Icons.gps_fixed_rounded,
                            color: const Color(0xFF10B981),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$gamesCompleted/$dailyGoal',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimaryLight,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: dailyGoal > 0 ? gamesCompleted / dailyGoal : 0,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            dailyProgress.isDailyGoalComplete
                                ? AppColors.success
                                : const Color(0xFF10B981),
                          ),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (isBn
                                ? 'দৈনিক লক্ষ্য'
                                : isHi
                                    ? 'दैनिक लक्ष्य'
                                    : 'Daily Goal')
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildMetricItem(
                icon: Icons.psychology_rounded,
                iconColor: isDark ? AppColors.primary : AppColors.primaryDark,
                label: isBn
                    ? 'মস্তিষ্ক স্কোর'
                    : isHi
                        ? 'मस्तिष्क स्कोर'
                        : 'Brain Score',
                value: '$brainScore',
                isDark: isDark,
                valueWidget: _AnimatedCountUp(
                  value: brainScore,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    letterSpacing: -0.2,
                  ),
                ),
                onTap: () => _showBrainScoreDialog(
                    context, dailyProgress, brainStats, isBn, isHi, isDark),
              ),
              const SizedBox(width: 8),
              _buildMetricItem(
                icon: Icons.bolt_rounded,
                iconColor: const Color(0xFFF59E0B),
                label: isBn ? 'অভিজ্ঞতা' : isHi ? 'एक्सपी' : 'XP',
                value: '$xp',
                isDark: isDark,
                onTap: () =>
                    _showXpDialog(context, xp, level, isBn, isHi, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuestLoginCard(
      BuildContext context, bool isBn, bool isHi, bool isDark) {
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
            child:
                const Icon(Icons.link_rounded, color: AppColors.warning, size: 22),
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
                    color: isDark
                        ? AppColors.warning.withValues(alpha: 0.8)
                        : AppColors.warningDark.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isBn
                  ? 'লগইন'
                  : isHi
                      ? 'लॉगिन'
                      : 'Login',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showStreakDialog(
      BuildContext context, int streak, bool isBn, bool isHi, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        title: Row(
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              color: Color(0xFFF97316),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              isBn ? 'দিনের ধারা' : isHi ? 'दिन की स्ट्रीक' : 'Day Streak',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isBn ? 'বর্তমান ধারা' : isHi ? 'वर्तमान स्ट्रीक' : 'Current Streak',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                Text(
                  '$streak',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF97316),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              isBn
                  ? 'কীভাবে ধারা বাড়ে?'
                  : isHi
                      ? 'स्ट्रीक कैसे बढ़ती है?'
                      : 'How streaks increase',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isBn
                  ? 'প্রতিদিন অন্তত ১টি গেম খেললে ধারা বাড়ে। টানা প্রতিদিন খেললে ধারা +১ করে বাড়ে।'
                  : isHi
                      ? 'हर दिन कम से कम 1 गेम खेलने पर स्ट्रीक बढ़ती है। लगातार खेलने से स्ट्रीक +1 बढ़ती है।'
                      : 'Play at least 1 game every day to grow your streak. Each consecutive day adds +1.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isBn
                  ? 'একদিন না খেললে ধারা ০-তে রিসেট হয়ে যায়।'
                  : isHi
                      ? 'एक दिन न खेलने पर स्ट्रीक 0 पर रीसेट हो जाती है।'
                      : 'Missing a day resets your streak back to 0.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              isBn
                  ? 'বন্ধ করুন'
                  : isHi
                      ? 'बंद करें'
                      : 'Close',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showDailyGoalDialog(BuildContext context, DailyProgress progress,
      bool isBn, bool isHi, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.gps_fixed_rounded,
                color: Color(0xFF10B981), size: 22),
            const SizedBox(width: 8),
            Text(
              isBn
                  ? 'দৈনিক লক্ষ্য'
                  : isHi
                      ? 'दैनिक लक्ष्य'
                      : 'Daily Goal',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${progress.dailyGamesCompleted.clamp(0, progress.dailyGoal)} / ${progress.dailyGoal} '
              '${isBn ? 'গেম' : isHi ? 'गेम' : 'games'}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.dailyGoal > 0
                    ? progress.dailyGamesCompleted
                            .clamp(0, progress.dailyGoal) /
                        progress.dailyGoal
                    : 0,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress.isDailyGoalComplete
                      ? AppColors.success
                      : const Color(0xFF10B981),
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              progress.isDailyGoalComplete
                  ? (isBn
                      ? 'আজকের লক্ষ্য সম্পন্ন! দুর্দান্ত! 🎉'
                      : isHi
                          ? 'आज का लक्ष्य पूरा हुआ! बढ़िया! 🎉'
                          : "Today's goal complete! Great job! 🎉")
                  : (isBn
                      ? 'লক্ষ্য: আজকের চ্যালেঞ্জ + ২টি ভিন্ন গেম খেলুন। প্রতিদিন রিসেট হয়।'
                      : isHi
                          ? 'लक्ष्य: आज की चुनौती + 2 अलग-अलग गेम खेलें। हर दिन रीसेट होता है।'
                          : "Goal: play today's challenge + 2 different games. Resets every day."),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              isBn
                  ? 'বন্ধ করুন'
                  : isHi
                      ? 'बंद करें'
                      : 'Close',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showBrainScoreDialog(BuildContext context, DailyProgress progress,
      BrainStatsBundle? brainStats, bool isBn, bool isHi, bool isDark) {
    const pillars = [
      (BrainPillar.knowledge, '🧠', 'Knowledge', 'জ্ঞান', 'ज्ञान'),
      (BrainPillar.logic, '🧩', 'Logic', 'যুক্তি', 'तर्क'),
      (BrainPillar.speed, '⚡', 'Speed', 'গতি', 'गति'),
      (BrainPillar.memory, '🧠', 'Memory', 'স্মৃতি', 'स्मृति'),
      (BrainPillar.reaction, '🎯', 'Reaction', 'প্রতিক্রিয়া', 'प्रतिक्रिया'),
    ];

    // Engine data wins once it exists; the legacy pillar history is only a
    // fallback for brand-new users.
    final engine = brainStats?.brain;
    final ratings = engine?.ratings;
    final score = (engine?.score ?? 0) > 0
        ? engine!.score
        : progress.brainScore;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        title: Row(
          children: [
            Icon(Icons.psychology_rounded,
                color: isDark ? AppColors.primary : AppColors.primaryDark,
                size: 22),
            const SizedBox(width: 8),
            Text(
              isBn
                  ? 'মস্তিষ্ক স্কোর'
                  : isHi
                      ? 'मस्तिष्क स्कोर'
                      : 'Brain Score',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnimatedCountUp(
              value: score,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isBn
                  ? 'সর্বশেষ পারফরম্যান্স থেকে ক্রমবর্ধমান স্কোর (প্রতি স্তম্ভে একটি সেশনের ইতিহাস)'
                  : isHi
                      ? 'हालिया प्रदर्शन से क्रमिक स्कोर (प्रति स्तंभ सत्र इतिहास)'
                      : 'Progressive score from your recent performance (session history per pillar)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 16),
            ...pillars.map((p) {
              final (key, emoji, en, bn, hi) = p;
              final hasData = ratings?.hasData(key) ??
                  (progress.pillarScores[key]?.isNotEmpty ?? false);
              final score = ratings != null && ratings.hasData(key)
                  ? ratings.rating(key).round()
                  : progress.pillarScore(key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isBn
                            ? bn
                            : isHi
                                ? hi
                                : en,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 90,
                        child: LinearProgressIndicator(
                          value: hasData ? score / 100 : 0,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 34,
                      child: Text(
                        hasData ? '$score' : '—',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: hasData
                              ? (isDark
                                  ? Colors.white
                                  : AppColors.textPrimaryLight)
                              : (isDark
                                  ? Colors.white24
                                  : Colors.grey.shade400),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              isBn
                  ? 'বন্ধ করুন'
                  : isHi
                      ? 'बंद करें'
                      : 'Close',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showXpDialog(BuildContext context, int xp, int level, bool isBn, bool isHi,
      bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 22),
            const SizedBox(width: 8),
            Text(
              isBn ? 'অভিজ্ঞতা (XP)' : isHi ? 'एक्सपी (XP)' : 'XP',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isBn ? 'মোট XP' : isHi ? 'कुल XP' : 'Total XP',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                Text(
                  '$xp XP',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isBn ? 'স্তর' : isHi ? 'स्तर' : 'Level',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                Text(
                  '$level',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              isBn ? 'XP কী?' : isHi ? 'XP क्या है?' : 'What is XP?',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isBn
                  ? 'XP হলো ব্যস্ততা পয়েন্ট — আপনি গেম খেলে যা পান।'
                  : isHi
                      ? 'XP अभ्यास अंक हैं जो गेम खेलने पर मिलते हैं।'
                      : 'XP are engagement points you earn simply by playing.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isBn ? 'কীভাবে পান?' : isHi ? 'कैसे कमाएँ?' : 'How to earn?',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isBn
                  ? 'প্র্যাকটিস +১০, ডেইলি চ্যালেঞ্জ +২৫, ওয়ার্কআউট +৩০, ব্যাটল +১০ (প্রতিদিন সর্বোচ্চ ১৫০)।'
                  : isHi
                      ? 'प्रैक्टिस +10, डेली चैलेंज +25, वर्कआउट +30, बैटल +10 (रोज़ अधिकतम 150)।'
                      : 'Practice +10, Daily Challenge +25, Workout +30, Battle +10 (max 150/day).',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isBn ? 'কী কাজে লাগে?' : isHi ? 'इसका उपयोग?' : 'What is it useful for?',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isBn
                  ? 'স্তর বাড়ায়; স্তর ১০/২৫/৫০-এ অর্জন আনলক হয়, যা কয়েন ও XP দেয়।'
                  : isHi
                      ? 'स्तर बढ़ाता है; स्तर 10/25/50 पर उपलब्धियाँ अनलॉक होती हैं, जो सिक्के व XP देती हैं।'
                      : "Raises your level; Lv 10/25/50 unlock achievements that reward coins + XP.",
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isBn
                  ? 'লিডারবোর্ড র‍্যাংকিং বা মস্তিষ্ক স্কোরে XP অন্তর্ভুক্ত হয় না।'
                  : isHi
                      ? 'XP लीडरबोर्ड रैंकिंग या मस्तिष्क स्कोर में शामिल नहीं होता।'
                      : 'XP is never part of leaderboard ranking or your Brain Score.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              isBn
                  ? 'বন্ধ করুন'
                  : isHi
                      ? 'बंद करें'
                      : 'Close',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    String value = '',
    Widget? valueWidget,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 6),
                valueWidget ??
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color:
                            isDark ? Colors.white : AppColors.textPrimaryLight,
                        letterSpacing: -0.2,
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutCard(AsyncValue<dynamic> quizAsync, BuildContext context,
      bool isBn, bool isHi, bool isDark) {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final difference = midnight.difference(now);
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    final timeLeftStr = isBn
        ? '$hours ঘণ্টা $minutes মিনিট বাকি'
        : isHi
            ? '$hours घंटे $minutes मिनट शेष'
            : '$hours h $minutes m left';

    final sectionTitle = isBn
        ? 'আজকের চ্যালেঞ্জ'
        : isHi
            ? 'आज की चुनौती'
            : "Today's Challenge";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.bolt_rounded,
          accent: AppColors.primary,
          title: sectionTitle,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          child: Row(
            children: [
              // Card 1: GK Challenge (Open)
              _buildChallengeTile(
                context: context,
                isDark: isDark,
                badgeText: isBn
                    ? 'জিকে লাইভ'
                    : isHi
                        ? 'जीके लाइव'
                        : 'GK LIVE',
                title: isBn
                    ? 'জিকে চ্যালেঞ্জ'
                    : isHi
                        ? 'जीके चुनौती'
                        : 'GK Challenge',
                subtitle: isBn
                    ? 'আজকের জিকে চ্যালেঞ্জ খেলুন'
                    : isHi
                        ? 'जीके लाइव चुनौती खेलें'
                        : 'Daily general knowledge run',
                timeLeft: timeLeftStr,
                isLocked: false,
                isLive: true,
                onTap: () {
                  if (!DailyChallengeAuth.canStart(ref)) {
                    DailyChallengeAuth.requireLogin(context, ref);
                    return;
                  }
                  quizAsync.whenData((quiz) {
                    if (quiz != null) {
                      ref.read(quizSessionProvider.notifier).startQuiz(quiz);
                      Navigator.pushNamed(context, AppRouter.introGkQuiz);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                "Today's GK challenge is not available yet.")),
                      );
                    }
                  });
                },
                isBn: isBn,
                isHi: isHi,
                imagePath: 'assets/covers/gk_quiz.svg',
              ),
              const SizedBox(width: 12),
              // Card 2: Arrow Path Maze (Unlocked Daily Challenge)
              _buildChallengeTile(
                context: context,
                isDark: isDark,
                badgeText: isBn
                    ? 'যুক্তি'
                    : isHi
                        ? 'তর্ক'
                        : 'LOGIC',
                title: isBn
                    ? 'দিকনির্দেশ ধাঁধা'
                    : isHi
                        ? 'दिशा पहेली'
                        : 'Arrow Puzzle 3D',
                subtitle: isBn
                    ? 'তর্ক ও প্যাটার্ন ওরিয়েন্টেশন'
                    : isHi
                        ? 'तार्किक भूलभुलैया'
                        : 'Directional speed tracking',
                timeLeft: timeLeftStr,
                isLocked: false,
                isLive: true,
                onTap: () {
                  if (!DailyChallengeAuth.canStart(ref)) {
                    DailyChallengeAuth.requireLogin(context, ref);
                    return;
                  }
                  Navigator.pushNamed(context, AppRouter.introArrowPuzzle, arguments: {
                    'isDailyChallenge': true,
                  });
                },
                isBn: isBn,
                isHi: isHi,
                imagePath: 'assets/covers/arrow_maze.svg',
              ),
              const SizedBox(width: 12),
              // Card 3: Math Speed Sprint
              _buildChallengeTile(
                context: context,
                isDark: isDark,
                badgeText: isBn
                    ? 'গণিত'
                    : isHi
                        ? 'गणित'
                        : 'MATH',
                title: isBn
                    ? 'গণিত স্প্রিন্ট'
                    : isHi
                        ? 'गणित स्प्रिंट'
                        : 'Math Speed Sprint',
                subtitle: isBn
                    ? 'গতি ও হিসাব পরীক্ষা'
                    : isHi
                        ? 'त्वरित गणना खेल'
                        : 'Mental arithmetic sprint',
                isLocked: false,
                isLive: false,
                onTap: () {
                  Navigator.pushNamed(context, AppRouter.introMathSprint);
                },
                isBn: isBn,
                isHi: isHi,
                imagePath: 'assets/covers/math_sprint.svg',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeTile({
    required BuildContext context,
    required bool isDark,
    required String badgeText,
    required String title,
    required String subtitle,
    String? timeLeft,
    required bool isLocked,
    required bool isLive,
    required VoidCallback onTap,
    required bool isBn,
    required bool isHi,
    String? imagePath,
    String? footerText,
  }) {
    final categoryColor = isLive
        ? AppColors.primary
        : (badgeText.contains('LOGIC') ||
                badgeText.contains('যুক্তি') ||
                badgeText.contains('तर्क')
            ? const Color(0xFF00F1FE)
            : const Color(0xFFB79CFF));

    return GameCard(
      width: 210,
      compact: true,
      coverAspectRatio: 1.45,
      imagePath: imagePath,
      accent: categoryColor,
      badge: badgeText,
      isLive: isLive,
      isLocked: isLocked,
      meta: timeLeft,
      metaIcon: timeLeft != null ? Icons.access_time_rounded : null,
      title: title,
      subtitle: subtitle,
      footer: isLocked
          ? (isBn
              ? 'পরবর্তী স্তরে খুলবে'
              : isHi
                  ? 'अगले स्तर पर अनलॉक'
                  : 'Unlocks next level')
          : footerText,
      onTap: onTap,
    );
  }

  // ── Section header (icon squircle + spaced title + hairline rule) ───────

  Widget _buildSectionHeader({
    required IconData icon,
    required Color accent,
    required String title,
    required bool isDark,
  }) {
    final iconColor = isDark
        ? accent
        : Color.lerp(accent, Colors.black, 0.30)!;
    final lineColor = (isDark ? Colors.white : Colors.black)
        .withValues(alpha: isDark ? 0.07 : 0.06);
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.16 : 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: accent.withValues(alpha: isDark ? 0.28 : 0.22),
              width: 1,
            ),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.grey.shade800,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: lineColor)),
      ],
    );
  }

  // ── Recommended Games (standalone quick-play tiles) ──────────────────────

  Widget _buildRecommendedGamesSection(
      BuildContext context, bool isBn, bool isHi, bool isDark) {
    const accentCyan = Color(0xFF00F1FE);
    const accentPurple = Color(0xFFB79CFF);
    const accentOrange = Color(0xFFF97316);
    const accentEmerald = Color(0xFF34D399);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.recommend_rounded,
          accent: accentEmerald,
          title: isBn
              ? 'রেকমেন্ডেড গেমস'
              : isHi
                  ? 'सुझाए गए गेम्स'
                  : 'RECOMMENDED',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 172,
          ),
          children: [
            _buildRecommendedGameTile(
              context: context,
              isDark: isDark,
              isBn: isBn,
              isHi: isHi,
              badgeText: isBn
                  ? 'পাজল'
                  : isHi
                      ? 'पहेली'
                      : 'PUZZLE',
              title: isBn
                  ? 'ফ্লো ফ্রি'
                  : isHi
                      ? 'फ्लो फ्री'
                      : 'Flow Free',
              subtitle: isBn
                  ? 'রঙের জোড়া জুড়ে গ্রিড পূরণ'
                  : isHi
                      ? 'रंगीन जोड़े जोड़ें'
                      : 'Connect matching colors',
              accent: accentEmerald,
              imagePath: 'assets/covers/flow_free.svg',
              footer: isBn
                  ? 'পাইপ পাজল'
                  : isHi
                      ? 'पाइप पहेली'
                      : 'Pipe puzzle',
              onTap: () => Navigator.pushNamed(context, AppRouter.introFlowFree),
            ),
            _buildRecommendedGameTile(
              context: context,
              isDark: isDark,
              isBn: isBn,
              isHi: isHi,
              badgeText: isBn
                  ? 'স্ট্রোক'
                  : isHi
                      ? 'स्ट्रोक'
                      : 'ONE STROKE',
              title: isBn
                  ? 'ওয়ান লাইন'
                  : isHi
                      ? 'वन लाइन'
                      : 'One Line',
              subtitle: isBn
                  ? 'এক টানে পুরো ছবি আঁকুন'
                  : isHi
                      ? 'एक लकीर में आकृति बनाएँ'
                      : 'Trace it in a single stroke',
              accent: const Color(0xFFE040FB),
              imagePath: 'assets/covers/one_line.svg',
              footer: isBn
                  ? 'ইউলার ট্রেইল'
                  : isHi
                      ? 'यूलर पथ'
                      : 'Euler trail',
              onTap: () => Navigator.pushNamed(context, AppRouter.introOneLine),
            ),
            _buildRecommendedGameTile(
              context: context,
              isDark: isDark,
              isBn: isBn,
              isHi: isHi,
              badgeText: isBn
                  ? 'গণিত'
                  : isHi
                      ? 'गणित'
                      : 'MATH',
              title: isBn
                  ? 'ম্যাথ স্প্রিন্ট'
                  : isHi
                      ? 'मैथ स्प्रिंट'
                      : 'Math Sprint',
              subtitle: isBn
                  ? 'গতি ও হিসাব পরীক্ষা'
                  : isHi
                      ? 'त्वरित गणना खेल'
                      : 'Mental arithmetic sprint',
              accent: accentPurple,
              imagePath: 'assets/covers/math_sprint.svg',
              footer: isBn
                  ? 'মানসিক গণিত'
                  : isHi
                      ? 'मानसिक गणित'
                      : 'Mental math',
              onTap: () => Navigator.pushNamed(context, AppRouter.introMathSprint),
            ),
            _buildRecommendedGameTile(
              context: context,
              isDark: isDark,
              isBn: isBn,
              isHi: isHi,
              badgeText: isBn
                  ? 'গতি'
                  : isHi
                      ? 'गति'
                      : 'SPEED',
              title: isBn
                  ? 'স্ট্রুপ রাশ'
                  : isHi
                      ? 'स्ट्रूप रश'
                      : 'Stroop Rush',
              subtitle: isBn
                  ? 'প্রতিক্রিয়া ও ফোকাস গতি'
                  : isHi
                      ? 'प्रतिक्रिया व फोकस गति'
                      : 'Reaction & focus speed',
              accent: accentOrange,
              imagePath: 'assets/covers/stroop_rush.svg',
              footer: isBn
                  ? 'ফোকাস ও প্রতিক্রিয়া'
                  : isHi
                      ? 'फोकस व प्रतिक्रिया'
                      : 'Focus & reaction',
              onTap: () => Navigator.pushNamed(context, AppRouter.introStroopRush),
            ),
            _buildRecommendedGameTile(
              context: context,
              isDark: isDark,
              isBn: isBn,
              isHi: isHi,
              badgeText: isBn
                  ? 'যুক্তি'
                  : isHi
                      ? 'तर्क'
                      : 'LOGIC',
              title: isBn
                  ? 'দিকনির্দেশ ধাঁধা'
                  : isHi
                      ? 'दिशा पहेली'
                      : 'Arrow Puzzle 3D',
              subtitle: isBn
                  ? 'তর্ক ও প্যাটার্ন ওরিয়েন্টেশন'
                  : isHi
                      ? 'तार्किक भूलभुलैया'
                      : 'Directional speed tracking',
              accent: accentCyan,
              imagePath: 'assets/covers/arrow_maze.svg',
              footer: isBn
                  ? 'যুক্তি ও দিকনির্দেশ'
                  : isHi
                      ? 'तर्क व दिशा'
                      : 'Logic & orientation',
              onTap: () => Navigator.pushNamed(context, AppRouter.introArrowPuzzle),
            ),
            _buildRecommendedGameTile(
              context: context,
              isDark: isDark,
              isBn: isBn,
              isHi: isHi,
              badgeText: isBn
                  ? 'তীর'
                  : isHi
                      ? 'तीर'
                      : 'ARROWS',
              title: isBn
                  ? 'এরো সিলুয়েট'
                  : isHi
                      ? 'एरो सिल्हूट'
                      : 'Arrow Silhouette',
              subtitle: isBn
                  ? 'তীর দিয়ে আকৃতি ভেঙে পালান'
                  : isHi
                      ? 'तीरों की आकृति तोड़कर बचें'
                      : 'Escape arrows from silhouettes',
              accent: accentCyan,
              imagePath: null,
              footer: isBn
                  ? 'সিলুয়েট পাজল'
                  : isHi
                      ? 'सिल्हूट पहेली'
                      : 'Silhouette puzzle',
              onTap: () => Navigator.pushNamed(context, AppRouter.introArrowSilhouette),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecommendedGameTile({
    required BuildContext context,
    required bool isDark,
    required bool isBn,
    required bool isHi,
    required String badgeText,
    required String title,
    required String subtitle,
    required String footer,
    required Color accent,
    required VoidCallback onTap,
    String? imagePath,
    Widget? cover,
  }) {
    return GameCard(
      fillHeight: true,
      compact: true,
      coverHeight: 116,
      imagePath: imagePath,
      cover: cover,
      accent: accent,
      badge: badgeText,
      isLive: true,
      title: title,
      subtitle: subtitle,
      footer: footer,
      onTap: onTap,
    );
  }

}

/// Slowly counts up to [value] whenever it appears or changes.
///
/// Pauses automatically while the screen is covered (TickerMode) so the
/// animation is still visible when the user returns to the screen.
class _AnimatedCountUp extends StatefulWidget {
  final int value;
  final TextStyle style;

  const _AnimatedCountUp({required this.value, required this.style});

  @override
  State<_AnimatedCountUp> createState() => _AnimatedCountUpState();
}

class _AnimatedCountUpState extends State<_AnimatedCountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _animation = Tween<double>(begin: 0, end: widget.value.toDouble()).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_AnimatedCountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
              begin: _animation.value, end: widget.value.toDouble())
          .animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => Text(
        '${_animation.value.round()}',
        style: widget.style,
      ),
    );
  }
}

/// Soft radial blob used to paint ambient neon glows on the dark backdrop.
class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.16),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}