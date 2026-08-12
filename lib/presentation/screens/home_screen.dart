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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    // Retrieve username and photo from currentUserProvider
    final currentUser = ref.watch(currentUserProvider).value;
    final username = currentUser?.displayName ?? _savedUsername;
    final photoUrl = currentUser?.photoUrl ?? _savedPhotoUrl;

    // Daily progress metrics (streak, daily goal, brain score)
    final dailyProgress = dailyProgressAsync.value ?? const DailyProgress();
    final streak = dailyProgress.currentStreak;
    // Metrics are hidden for guests and logged-out users.
    final isGuest = currentUser?.isAnonymous ?? true;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.homeBackdropDark : AppColors.homeBackdropGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Custom Header Bar matching BrainX branding
              _buildTopAppBar(photoUrl, context),
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

                             // 1v1 Battle Arena Bento Card
                             _buildBattleBentoCard(context, isBn, isHi, isDark),
                             const SizedBox(height: 24),

                            // Pillars title
                            Text(
                              isBn ? 'মানসিক দক্ষতার স্তম্ভসমূহ' : isHi ? 'संज्ञानात्मक कौशल के स्तंभ' : 'Pillars of Cognitive Fitness',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Pillars Grid
                             _buildPillarsGrid(context, isBn, isHi, isDark),
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
      ),
    );
  }

  Widget _buildTopAppBar(String photoUrl, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDark : AppColors.bgLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.outlineVariant.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.primary.withValues(alpha: 0.5) : AppColors.primaryDark.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    image: photoUrl.isNotEmpty
                        ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                        : null,
                  ),
                  child: photoUrl.isEmpty
                      ? Icon(
                          Icons.person_rounded,
                          color: isDark ? AppColors.primary : AppColors.primaryDark,
                          size: 20,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'BRAINX',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/leaderboard'),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceElevatedDark.withValues(alpha: 0.5) : AppColors.surfaceElevatedLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.outlineVariant : Colors.black12,
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
        ],
      ),
    );
  }

  Widget _buildMetricsBentoBox(int streak, DailyProgress dailyProgress, bool isBn, bool isHi, bool isDark) {
    final brainScore = dailyProgress.brainScore;
    final gamesCompleted = dailyProgress.dailyGamesCompleted.clamp(0, dailyProgress.dailyGoal);
    final dailyGoal = dailyProgress.dailyGoal;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFF151D1E).withValues(alpha: 0.25) 
                : Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.1) 
                  : Colors.black.withValues(alpha: 0.05),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : AppColors.primary).withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
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

  Widget _buildBattleBentoCard(BuildContext context, bool isBn, bool isHi, bool isDark) {
    const neonCyan = Color(0xFF00F1FE);

    return GameCard(
      width: double.infinity,
      compact: true,
      coverHeight: 110,
      imagePath: 'assets/icon/battle2.PNG',
      accent: neonCyan,
      badge: isBn ? 'মাল্টিপ্লেয়ার' : isHi ? 'मल्टीप्लेयर' : 'MULTIPLAYER',
      isLive: true,
      meta: isBn ? '৫ মিনিট' : isHi ? '5 मिनट' : '~5 min',
      metaIcon: Icons.access_time_rounded,
      title: isBn ? '১ বনাম ১ যুদ্ধ অ্যারেনা' : isHi ? '1 बनाम 1 युद्ध एरिना' : '1v1 Battle Arena',
      subtitle: isBn
          ? 'লাইভ দ্বৈরথ বা বট প্রশিক্ষণ'
          : isHi
              ? 'लाइव दोस्त या बॉट से खेलें'
              : 'Duel friends live or train vs bot',
      footer: isBn ? 'অনলাইন ও অফলাইন মোড' : isHi ? 'ऑनलाइन और ऑफ़लाइन मोड' : 'Online & offline modes',
      onTap: () => Navigator.pushNamed(context, '/battle'),
    );
  }

  Widget _buildPillarsGrid(BuildContext context, bool isBn, bool isHi, bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cellWidth = (screenWidth - 32 - 12) / 2;
    const coverRatio = 1.9;
    const infoReserve = 60.0;
    final aspectRatio = cellWidth / (cellWidth / coverRatio + infoReserve);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: aspectRatio,
      children: [
        _buildPillarItem(
          index: 0,
          accent: AppColors.primary,
          icon: Icons.menu_book_rounded,
          title: isBn ? 'জ্ঞান' : isHi ? 'ज्ञान' : 'Knowledge',
          subtitle: isBn ? 'সাধারণ বুদ্ধি' : isHi ? 'सामान्य ज्ञान' : 'General fluid intelligence',
          onTap: () {
            Navigator.pushNamed(context, '/game-placeholder', arguments: {
              'title': isBn ? 'জিকে প্র্যাকটিস অ্যারেনা' : isHi ? 'जीके अभ्यास एरिना' : 'GK Practice Arena',
              'description': isBn
                  ? 'ইতিহাস, ভূগোল, বিজ্ঞান এবং রাষ্ট্রনীতির মতো গুরুত্বপূর্ণ সিলেবাস ভিত্তিক বিষয়গুলি বেছে নিয়ে নিয়মিত অনুশীলন করুন।'
                  : isHi
                      ? 'इतिहास, भूगोल, विज्ञान और राजनीति जैसे महत्वपूर्ण विषयों को चुनकर नियमित अभ्यास करें।'
                      : 'Select core syllabus topics like History, Geography, Science, and Polity to begin structured cognitive training.',
            });
          },
          isBn: isBn,
          isHi: isHi,
        ),
        _buildPillarItem(
          index: 1,
          accent: const Color(0xFF00F1FE),
          icon: Icons.bolt_rounded,
          title: isBn ? 'গতি' : isHi ? 'गति' : 'Speed',
          subtitle: isBn ? 'প্রতিক্রিয়া গতি' : isHi ? 'त्वरित गणना' : 'Reaction & calculation',
          onTap: () {
            Navigator.pushNamed(context, '/game-placeholder', arguments: {
              'title': 'Math Speed Sprint',
              'description': 'A 60-second mental arithmetic sprint to sharpen focus and operational cognitive processing.',
            });
          },
          isBn: isBn,
          isHi: isHi,
        ),
        _buildPillarItem(
          index: 2,
          accent: const Color(0xFFECB2FF),
          icon: Icons.account_tree_rounded,
          title: isBn ? 'যুক্তি' : isHi ? 'तर्क' : 'Logic',
          subtitle: isBn ? 'প্যাটার্ন খোঁজা' : isHi ? 'तार्किक भूलभुलैया' : 'Directional orientation',
          onTap: () {
            Navigator.pushNamed(context, '/arrow-puzzle');
          },
          isBn: isBn,
          isHi: isHi,
        ),
        _buildPillarItem(
          index: 3,
          accent: const Color(0xFFFF2D95),
          icon: Icons.psychology_rounded,
          title: isBn ? 'স্মৃতিশক্তি' : isHi ? 'स्मृति' : 'Memory',
          subtitle: isBn ? 'সক্রিয় স্মরণ' : isHi ? 'ग्रिड विजुअल रिकॉल' : 'Active recall performance',
          onTap: () {
            Navigator.pushNamed(context, '/game-placeholder', arguments: {
              'title': 'Synapse Recall',
              'description': 'Memorize the flashing green pattern on the grid matrix. Recreate it accurately as grid size expands.',
            });
          },
          isBn: isBn,
          isHi: isHi,
        ),
      ],
    );
  }

  Widget _buildPillarItem({
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required int index,
    required bool isBn,
    required bool isHi,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StaggeredListItem(
      index: index,
      child: GameCard(
        compact: true,
        fillHeight: true,
        coverAspectRatio: 1.9,
        accent: accent,
        cover: _buildPillarCover(icon, accent, isDark),
        title: title,
        subtitle: subtitle,
        footer: isBn ? 'খেলুন' : isHi ? 'खेलें' : 'Play now',
        onTap: onTap,
      ),
    );
  }

  Widget _buildPillarCover(IconData icon, Color accent, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: isDark ? 0.28 : 0.22),
            accent.withValues(alpha: isDark ? 0.08 : 0.06),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.16 : 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: GameCard.accentForeground(accent, isDark),
            size: 22,
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
