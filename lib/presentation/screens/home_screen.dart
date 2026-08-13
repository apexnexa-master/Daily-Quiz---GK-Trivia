// lib/presentation/screens/home_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_animations.dart';
import '../../core/services/quiz_scheduler_service.dart';
import '../../core/utils/offline_manager.dart';
import '../../core/services/daily_progress_service.dart';
import '../widgets/game_card.dart';
import '../widgets/workout_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../utils/daily_challenge_auth.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _countdownTimer;
  String _savedUsername = 'Explorer';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    // Retrieve username and photo from currentUserProvider
    final currentUser = ref.watch(currentUserProvider).value;
    final username = currentUser?.displayName ?? _savedUsername;

    // Daily progress metrics (streak, daily goal, brain score)
    final dailyProgress = dailyProgressAsync.value ?? const DailyProgress();
    final streak = dailyProgress.currentStreak;
    // Metrics are hidden for guests and logged-out users.
    final isGuest = currentUser?.isAnonymous ?? true;

    return Scaffold(
      body: Stack(
        children: [
          // Base slate backdrop.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: isDark ? AppColors.homeBackdropDark : AppColors.homeBackdropGradient,
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
                _buildTopAppBar(context),
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
                      await _loadSavedIdentity();
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              // Small Greeting Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isBn ? 'নমস্কার, $username' : isHi ? 'नमस्ते, $username' : 'Hello, $username',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('EEEE, MMM d').format(DateTime.now()),
                                    style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Top Metrics Bento Bar (hidden for guests)
                            if (!isGuest)
                              _buildMetricsBentoBox(streak, dailyProgress, isBn, isHi, isDark),
                            const SizedBox(height: 20),

                            // Main Bento Layout
                            // Recommended Workout Card (Bento Large)
                            _buildWorkoutCard(quizAsync, context, isBn, isHi, isDark),
                            const SizedBox(height: 16),

                             // Quick Brain Workout (one-tap multi-game session)
                             QuickBrainWorkoutCard(lang: lang),
                             const SizedBox(height: 24),

                            // Train Your Brain title
                            Text(
                              isBn ? 'আপনার মস্তিষ্ক প্রশিক্ষণ দিন' : isHi ? 'अपने दिमाग को प्रशिक्षित करें' : 'Train Your Brain',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Train Your Brain grid (only playable skills)
                             _buildTrainYourBrainSection(quizAsync, context, isBn, isHi, isDark),
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

  Widget _buildTopAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand name (BRAINX)
          Text(
            'BRAINX',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: AppColors.primary,
              shadows: isDark
                  ? const [Shadow(color: AppColors.neonLime, blurRadius: 14)]
                  : null,
            ),
          ),
          // Leaderboard glass button (right side)
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/leaderboard'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.06 : 0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? AppColors.neonCyan.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.06),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.leaderboard_rounded,
                    color: isDark ? AppColors.primary : AppColors.primaryDark,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsBentoBox(int streak, DailyProgress dailyProgress, bool isBn, bool isHi, bool isDark) {
    final brainScore = dailyProgress.brainScore;
    final gamesCompleted = dailyProgress.dailyGamesCompleted.clamp(0, dailyProgress.dailyGoal);
    final dailyGoal = dailyProgress.dailyGoal;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFF151D1E).withValues(alpha: 0.25) 
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
                color: (isDark ? Colors.black : AppColors.primary).withValues(alpha: 0.04),
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
              _buildMetricItem(
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFF97316),
                label: isBn ? 'দিনের ধারা' : isHi ? 'दिन की स्ट्रीक' : 'Day Streak',
                value: '$streak',
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              // Daily Goal with mini progress bar
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showDailyGoalDialog(context, dailyProgress, isBn, isHi, isDark),
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
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
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
                        (isBn ? 'দৈনিক লক্ষ্য' : isHi ? 'दैनिक लक्ष्य' : 'Daily Goal').toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
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
                label: isBn ? 'মস্তিষ্ক স্কোর' : isHi ? 'मस्तिष्क स्कोर' : 'Brain Score',
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
                onTap: () => _showBrainScoreDialog(context, dailyProgress, isBn, isHi, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDailyGoalDialog(BuildContext context, DailyProgress progress, bool isBn, bool isHi, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.gps_fixed_rounded, color: Color(0xFF10B981), size: 22),
            const SizedBox(width: 8),
            Text(
              isBn ? 'দৈনিক লক্ষ্য' : isHi ? 'दैनिक लक्ष्य' : 'Daily Goal',
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
                    ? progress.dailyGamesCompleted.clamp(0, progress.dailyGoal) / progress.dailyGoal
                    : 0,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress.isDailyGoalComplete ? AppColors.success : const Color(0xFF10B981),
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
              isBn ? 'বন্ধ করুন' : isHi ? 'बंद करें' : 'Close',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showBrainScoreDialog(BuildContext context, DailyProgress progress, bool isBn, bool isHi, bool isDark) {
    const pillars = [
      (BrainPillar.knowledge, '🧠', 'Knowledge', 'জ্ঞান', 'ज्ञान'),
      (BrainPillar.logic, '🧩', 'Logic', 'যুক্তি', 'तर्क'),
      (BrainPillar.speed, '⚡', 'Speed', 'গতি', 'गति'),
      (BrainPillar.memory, '🧠', 'Memory', 'স্মৃতি', 'स्मृति'),
      (BrainPillar.reaction, '🎯', 'Reaction', 'প্রতিক্রিয়া', 'প্রतिक्रिया'),
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        title: Row(
          children: [
            Icon(Icons.psychology_rounded, color: isDark ? AppColors.primary : AppColors.primaryDark, size: 22),
            const SizedBox(width: 8),
            Text(
              isBn ? 'মস্তিষ্ক স্কোর' : isHi ? 'मस्तिष्क स्कोर' : 'Brain Score',
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
              value: progress.brainScore,
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
                  ? 'আপনার সাম্প্রতিক পারফরম্যান্সের গড় (প্রতি স্তম্ভে সর্বশেষ ১০টি গেম)'
                  : isHi
                      ? 'आपके हालिया प्रदर्शन का औसत (प्रत्येक स्तंभ के अंतिम 10 गेम)'
                      : 'Average of your recent performance (last 10 games per pillar)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 16),
            ...pillars.map((p) {
              final (key, emoji, en, bn, hi) = p;
              final score = progress.pillarScore(key);
              final hasData = (progress.pillarScores[key]?.isNotEmpty ?? false);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isBn ? bn : isHi ? hi : en,
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
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
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
                              ? (isDark ? Colors.white : AppColors.textPrimaryLight)
                              : (isDark ? Colors.white24 : Colors.grey.shade400),
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
              isBn ? 'বন্ধ করুন' : isHi ? 'बंद करें' : 'Close',
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
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
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
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutCard(AsyncValue<dynamic> quizAsync, BuildContext context, bool isBn, bool isHi, bool isDark) {
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

    final sectionTitle = isBn ? 'আজকের চ্যালেঞ্জ' : isHi ? 'आज की चुनौती' : "Today's Challenge";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              sectionTitle,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
                badgeText: isBn ? 'জিকে লাইভ' : isHi ? 'जीके लाइव' : 'GK LIVE',
                title: isBn ? 'জিকে চ্যালেঞ্জ' : isHi ? 'जीके चुनौती' : 'GK Challenge',
                subtitle: isBn ? 'আজকের জিকে চ্যালেঞ্জ খেলুন' : isHi ? 'जीके लाइव चुनौती खेलें' : 'Daily general knowledge run',
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
                      Navigator.pushNamed(context, '/quiz');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Today's GK challenge is not available yet.")),
                      );
                    }
                  });
                },
                isBn: isBn,
                isHi: isHi,
                imagePath: 'assets/icon/quiz3.png',
              ),
              const SizedBox(width: 12),
              // Card 2: Arrow Path Maze (Unlocked Daily Challenge)
              _buildChallengeTile(
                context: context,
                isDark: isDark,
                badgeText: isBn ? 'যুক্তি' : isHi ? 'তর্ক' : 'LOGIC',
                title: isBn ? 'দিকনির্দেশ ধাঁধা' : isHi ? 'दिशा पहेली' : 'Arrow Puzzle 3D',
                subtitle: isBn ? 'তর্ক ও প্যাটার্ন ওরিয়েন্টেশন' : isHi ? 'तार्किक भूलभुलैया' : 'Directional speed tracking',
                timeLeft: timeLeftStr,
                isLocked: false,
                isLive: true,
                onTap: () {
                  if (!DailyChallengeAuth.canStart(ref)) {
                    DailyChallengeAuth.requireLogin(context, ref);
                    return;
                  }
                  Navigator.pushNamed(context, '/arrow-puzzle', arguments: {
                    'isDailyChallenge': true,
                  });
                },
                isBn: isBn,
                isHi: isHi,
                imagePath: 'assets/icon/arrows3.PNG',
              ),
              const SizedBox(width: 12),
              // Card 3: Math Speed Sprint (Locked)
              _buildChallengeTile(
                context: context,
                isDark: isDark,
                badgeText: isBn ? 'গণিত' : isHi ? 'गणित' : 'MATH',
                title: isBn ? 'গণিত স্প্রিন্ট' : isHi ? 'गणित स्प्रिंट' : 'Math Speed Sprint',
                subtitle: isBn ? 'গতি ও হিসাব পরীক্ষা' : isHi ? 'त्वरित गणना खेल' : 'Mental arithmetic sprint',
                isLocked: true,
                isLive: false,
                onTap: () {},
                isBn: isBn,
                isHi: isHi,
                imagePath: 'assets/icon/mathSpeed2.PNG',
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
  }) {
    final categoryColor = isLive 
        ? AppColors.primary 
        : (badgeText.contains('LOGIC') || badgeText.contains('যুক্তি') || badgeText.contains('तर्क') 
            ? const Color(0xFF00F1FE) 
            : const Color(0xFFECB2FF));

    return GameCard(
      width: 260,
      compact: true,
      coverAspectRatio: 2.6,
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
          ? (isBn ? 'পরবর্তী স্তরে খুলবে' : isHi ? 'अगले स्तर पर अनलॉक' : 'Unlocks next level')
          : (isBn ? 'রিয়াল-টাইম স্কোর' : isHi ? 'वास्तविक समय स्कोर' : 'Live reward active'),
      onTap: onTap,
    );
  }

  Widget _buildProgressCard(double accuracy, bool isBn, bool isHi, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark 
            ? AppColors.cardDark.withValues(alpha: 0.55) 
            : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark 
              ? Colors.white.withValues(alpha: 0.08) 
              : Colors.black.withValues(alpha: 0.06), 
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // SVG Circular Progress simulation
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: accuracy > 0 ? (accuracy / 100) : 0.15,
                  strokeWidth: 7,
                  backgroundColor: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
                  color: AppColors.primary,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                accuracy > 0 ? '${accuracy.toInt()}%' : '-',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBn ? 'আজকের অগ্রগতি' : isHi ? 'आज की प्रगति' : "Today's Accuracy",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isBn ? 'আপনার কুইজের সঠিকতার পরিমাপের গড় স্কোর।' : isHi ? 'पिछले खेलों में आपके सटीकता स्तर की गणना।' : 'Average performance level across recent training logs.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainYourBrainSection(AsyncValue<dynamic> quizAsync, BuildContext context, bool isBn, bool isHi, bool isDark) {
    final dailyProgress = ref.watch(dailyProgressProvider).value ?? const DailyProgress();

    void launchGKQuiz() {
      if (!DailyChallengeAuth.canStart(ref)) {
        DailyChallengeAuth.requireLogin(context, ref);
        return;
      }
      quizAsync.whenData((quiz) {
        if (quiz != null) {
          ref.read(quizSessionProvider.notifier).startQuiz(quiz);
          Navigator.pushNamed(context, '/quiz');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Today's GK challenge is not available yet.")),
          );
        }
      });
    }

    return Column(
      children: [
        _buildTrainYourBrainItem(
          index: 0,
          emoji: '🧠',
          accent: AppColors.primary,
          skillName: isBn ? 'জ্ঞান' : isHi ? 'ज्ञान' : 'Knowledge',
          gameName: isBn ? 'জিকে কুইজ' : isHi ? 'जीके क्विज़' : 'GK Quiz',
          score: dailyProgress.pillarScore(BrainPillar.knowledge),
          isBn: isBn,
          isHi: isHi,
          isDark: isDark,
          onTap: launchGKQuiz,
        ),
        const SizedBox(height: 12),
        _buildTrainYourBrainItem(
          index: 1,
          emoji: '🧩',
          accent: const Color(0xFF00F1FE),
          skillName: isBn ? 'যুক্তি' : isHi ? 'तर्क' : 'Logic',
          gameName: isBn ? 'দিকনির্দেশ ধাঁধা' : isHi ? 'दिशा पहेली' : 'Arrow Puzzle',
          score: dailyProgress.pillarScore(BrainPillar.logic),
          isBn: isBn,
          isHi: isHi,
          isDark: isDark,
          onTap: () {
            if (!DailyChallengeAuth.canStart(ref)) {
              DailyChallengeAuth.requireLogin(context, ref);
              return;
            }
            Navigator.pushNamed(context, '/arrow-puzzle');
          },
        ),
        const SizedBox(height: 12),
        _buildTrainYourBrainItem(
          index: 2,
          emoji: '⚡',
          accent: const Color(0xFFECB2FF),
          skillName: isBn ? 'গতি' : isHi ? 'गति' : 'Speed',
          gameName: isBn ? 'স্ট্রুপ রাশ' : isHi ? 'स्ट्रूप रश' : 'Stroop Rush',
          score: dailyProgress.pillarScore(BrainPillar.speed),
          isBn: isBn,
          isHi: isHi,
          isDark: isDark,
          onTap: () {
            if (!DailyChallengeAuth.canStart(ref)) {
              DailyChallengeAuth.requireLogin(context, ref);
              return;
            }
            Navigator.pushNamed(context, '/stroop-rush');
          },
        ),
      ],
    );
  }

  Widget _buildTrainYourBrainItem({
    required int index,
    required String emoji,
    required Color accent,
    required String skillName,
    required String gameName,
    required int score,
    required bool isBn,
    required bool isHi,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return StaggeredListItem(
      index: index,
      child: AnimatedScaleButton(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF192122).withValues(alpha: 0.75)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.16 : 0.10),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
                ),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          skillName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          gameName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: score / 100,
                        backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      score > 0
                          ? (isBn ? 'স্কোর $score' : isHi ? 'स्कोर $score' : 'Score $score')
                          : (isBn ? 'খেলে শুরু করুন' : isHi ? 'खेलकर शुरू करें' : 'Play to start'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: score > 0 ? accent : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.play_arrow_rounded, color: accent, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementsSection(bool isBn, bool isHi, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isBn ? 'সাম্প্রতিক অর্জন' : isHi ? 'हाल की उपलब्धियां' : 'Recent Achievements',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/achievements'),
                child: Text(
                  isBn ? 'সব দেখুন' : isHi ? 'सभी देखें' : 'View All',
                  style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAchievementBadge(
                  icon: Icons.emoji_events_rounded,
                  title: 'Focus Master',
                  desc: '10 games without error',
                  color: Colors.amber,
                ),
                const SizedBox(width: 12),
                _buildAchievementBadge(
                  icon: Icons.timer_rounded,
                  title: 'Speed Demon',
                  desc: 'Top 1% in Reaction Test',
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                _buildAchievementBadge(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Logic Leap',
                  desc: 'Leveled up to Tier 3',
                  color: Colors.purpleAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementBadge({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiaryDark,
                ),
              ),
            ],
          ),
        ],
      ),
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
      _animation =
          Tween<double>(begin: _animation.value, end: widget.value.toDouble())
              .animate(CurvedAnimation(
                  parent: _controller, curve: Curves.easeOutCubic));
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
