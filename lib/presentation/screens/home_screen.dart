// lib/presentation/screens/home_screen.dart
import 'dart:async';
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
import '../utils/daily_challenge_auth.dart';
import '../utils/account_linker.dart';
import '../../routes/app_router.dart';

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
    QuizSchedulerService.instance.refreshTiming(force: true).then((_) {
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
    // Guests are play-first users: they still see their local stats, and get a
    // secondary prompt to link an account so their progress is backed up.
    final isGuest = currentUser?.isAnonymous ?? true;
    // Gamification stats drive the XP matrix (level + total XP).
    final gamificationStats = ref.watch(gamificationNotifierProvider).value;
    final xp = gamificationStats?.xp ?? 0;
    final level = gamificationStats?.level ?? 1;

    return Scaffold(
      body: Stack(
        children: [
          // Solid matte backdrop — modular tiles supply the structure now.
          Positioned.fill(
            child: ColoredBox(
              color: isDark ? AppColors.bgDark : AppColors.bgLight,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Custom Header Bar matching BrainX branding
                _buildTopAppBar(context, streak, dailyProgress,
                    brainStatsAsync.value, xp, level, isBn, isHi),
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
                              // Guests get a compact save-progress prompt; the
                              // full metrics live in the header pills and sheet.
                              if (isGuest) ...[
                                _buildGuestLoginCard(
                                    context, isBn, isHi, isDark),
                                const SizedBox(height: 16),
                              ],

                              // Daily Brain Workout — the one-tap hero action.
                              _buildSectionHeader(
                                icon: Icons.bolt_rounded,
                                accent: AppColors.neonLime,
                                title: isBn
                                    ? 'দৈনিক ব্রেন প্র্যাকটিস'
                                    : isHi
                                        ? 'दैनिक ब्रेन प्रैक्टिस'
                                        : 'DAILY BRAIN PRACTICE',
                                isDark: isDark,
                              ),
                              const SizedBox(height: 12),
                              QuickBrainWorkoutCard(lang: lang),
                              const SizedBox(height: 24),

                              // Recommended Games — standalone quick-play games
                              _buildRecommendedGamesSection(
                                  context, isBn, isHi, isDark),
                              const SizedBox(height: 24),

                              // Today's Challenge — daily quiz, kept last so the
                              // quick workout and recommendations lead the page.
                              _buildWorkoutCard(context, isBn, isHi, isDark),
                              const SizedBox(height: 24),

                              const SizedBox(height: 12),
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

  Widget _buildTopAppBar(
    BuildContext context,
    int streak,
    DailyProgress dailyProgress,
    BrainStatsBundle? brainStats,
    int xp,
    int level,
    bool isBn,
    bool isHi,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final engineScore = brainStats?.brain.score ?? 0;
    final brainScore =
        engineScore > 0 ? engineScore : dailyProgress.brainScore.clamp(0, 100);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // Streak pill — fire symbol + number only; tap to learn how it grows.
          _buildHeaderPill(
            isDark: isDark,
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFF97316),
            value: '$streak',
            onTap: () => _showStreakDialog(context, streak,
                dailyProgress.longestStreak, isBn, isHi, isDark),
          ),
          const SizedBox(width: 8),
          // Brain pill — single glanceable score; tap opens the full summary.
          _buildHeaderPill(
            isDark: isDark,
            icon: Icons.psychology_rounded,
            iconColor: isDark ? AppColors.primary : AppColors.primaryDark,
            value: '$brainScore',
            onTap: () => _showBrainSkillsSheet(
              context,
              dailyProgress,
              brainStats,
              xp,
              level,
              isBn,
              isHi,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPill({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black)
              .withValues(alpha: isDark ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? iconColor.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ],
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
            child: const Icon(Icons.link_rounded,
                color: AppColors.warning, size: 22),
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
            // Link the anonymous account so the player keeps their streak and
            // stats instead of starting over on a fresh Google account.
            onPressed: () => AccountLinker.linkAccount(context, ref),
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
                  ? 'সংরক্ষণ'
                  : isHi
                      ? 'सहेजें'
                      : 'Save',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showStreakDialog(BuildContext context, int streak, int bestStreak,
      bool isBn, bool isHi, bool isDark) {
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
              isBn
                  ? 'দিনের ধারা'
                  : isHi
                      ? 'दिन की स्ट्रीक'
                      : 'Day Streak',
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
                  isBn
                      ? 'বর্তমান ধারা'
                      : isHi
                          ? 'वर्तमान स्ट्रीक'
                          : 'Current Streak',
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
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      size: 14,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isBn
                          ? 'সর্বোচ্চ ধারা'
                          : isHi
                              ? 'सर्वश्रेष्ठ स्ट्रीक'
                              : 'Best Streak',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$bestStreak',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF59E0B),
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

  void _showBrainSkillsSheet(
    BuildContext context,
    DailyProgress progress,
    BrainStatsBundle? brainStats,
    int xp,
    int level,
    bool isBn,
    bool isHi,
    bool isDark,
  ) {
    final engine = brainStats?.brain.score ?? 0;
    final brainScore = engine > 0 ? engine : progress.brainScore.clamp(0, 100);
    final gamesCompleted =
        progress.dailyGamesCompleted.clamp(0, progress.dailyGoal);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.of(sheetContext).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary
                          .withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.insights_rounded,
                      size: 18,
                      color: isDark ? AppColors.primary : AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBn
                              ? 'মস্তিষ্ক ও দক্ষতা'
                              : isHi
                                  ? 'मस्तिष्क और कौशल'
                                  : 'Brain Skills',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        Text(
                          isBn
                              ? 'আপনার অগ্রগতির সারাংশ'
                              : isHi
                                  ? 'आपकी प्रगति का सारांश'
                                  : 'Your progress at a glance',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    _buildMetricItem(
                      icon: Icons.gps_fixed_rounded,
                      iconColor: const Color(0xFF10B981),
                      label: isBn
                          ? 'দৈনিক লক্ষ্য'
                          : isHi
                              ? 'दैनिक लक्ष्य'
                              : 'Daily Goal',
                      value: '$gamesCompleted/${progress.dailyGoal}',
                      isDark: isDark,
                      onTap: () => _showDailyGoalDialog(
                          context, progress, isBn, isHi, isDark),
                    ),
                    const SizedBox(width: 8),
                    _buildMetricItem(
                      icon: Icons.psychology_rounded,
                      iconColor:
                          isDark ? AppColors.primary : AppColors.primaryDark,
                      label: isBn
                          ? 'মস্তিষ্ক স্কোর'
                          : isHi
                              ? 'मस्तिष्क स्कोर'
                              : 'Brain Score',
                      value: '$brainScore',
                      isDark: isDark,
                      onTap: () => _showBrainScoreDialog(
                          context, progress, brainStats, isBn, isHi, isDark),
                    ),
                    const SizedBox(width: 8),
                    _buildMetricItem(
                      icon: Icons.bolt_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      label: isBn
                          ? 'XP · লেভেল $level'
                          : isHi
                              ? 'XP · लेवल $level'
                              : 'XP · LV $level',
                      value: '$xp',
                      isDark: isDark,
                      onTap: () =>
                          _showXpDialog(context, xp, level, isBn, isHi, isDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    ref.invalidate(brainStatsProvider);
                    ref.invalidate(myWeeklyRankProvider);
                    Navigator.pushNamed(context, '/stats');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDark ? AppColors.primary : AppColors.primaryDark,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.view_agenda_rounded, size: 18),
                  label: Text(
                    isBn
                        ? 'সব দেখুন'
                        : isHi
                            ? 'सभी देखें'
                            : 'View All',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
    final score =
        (engine?.score ?? 0) > 0 ? engine!.score : progress.brainScore;

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
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary),
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

  void _showXpDialog(BuildContext context, int xp, int level, bool isBn,
      bool isHi, bool isDark) {
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
              isBn
                  ? 'অভিজ্ঞতা (XP)'
                  : isHi
                      ? 'एक्सपी (XP)'
                      : 'XP',
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
                  isBn
                      ? 'মোট XP'
                      : isHi
                          ? 'कुल XP'
                          : 'Total XP',
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
                  isBn
                      ? 'স্তর'
                      : isHi
                          ? 'स्तर'
                          : 'Level',
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
              isBn
                  ? 'XP কী?'
                  : isHi
                      ? 'XP क्या है?'
                      : 'What is XP?',
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
              isBn
                  ? 'কীভাবে পান?'
                  : isHi
                      ? 'कैसे कमाएँ?'
                      : 'How to earn?',
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
              isBn
                  ? 'কী কাজে লাগে?'
                  : isHi
                      ? 'इसका उपयोग?'
                      : 'What is it useful for?',
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

  Widget _buildWorkoutCard(
      BuildContext context, bool isBn, bool isHi, bool isDark) {
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
          icon: Icons.emoji_events_rounded,
          accent: AppColors.coin,
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
              // Card 1: Arrow Puzzle daily challenge (one official attempt).
              _buildChallengeTile(
                context: context,
                isDark: isDark,
                badgeText: isBn
                    ? 'এরো'
                    : isHi
                        ? 'एरो'
                        : 'ARROWS',
                title: isBn
                    ? 'এরো পাজল'
                    : isHi
                        ? 'एरो पज़ल'
                        : 'Arrow Puzzle',
                subtitle: isBn
                    ? 'আজকের তীর পাজল'
                    : isHi
                        ? 'आज की एरो पहेली'
                        : "Today's silhouette puzzle",
                timeLeft: timeLeftStr,
                isLocked: false,
                isLive: true,
                onTap: () {
                  if (!DailyChallengeAuth.canStart(ref)) {
                    DailyChallengeAuth.requireLogin(context, ref);
                    return;
                  }
                  Navigator.pushNamed(
                    context,
                    AppRouter.introArrowSilhouette,
                    arguments: {'isDailyChallenge': true},
                  );
                },
                isBn: isBn,
                isHi: isHi,
                icon: Icons.alt_route_rounded,
                emblemPath: 'assets/covers/arrow_maze_emblem.svg',
                footerText: isBn
                    ? 'এস্কেপ পাজল'
                    : isHi
                        ? 'एस्केप पहेली'
                        : 'Escape puzzle',
              ),
              const SizedBox(width: 12),
              // Card 2: Stroop Rush daily challenge (one official attempt).
              _buildChallengeTile(
                context: context,
                isDark: isDark,
                badgeText: isBn
                    ? 'স্ট্রুপ'
                    : isHi
                        ? 'स्ट्रूप'
                        : 'STROOP',
                title: isBn
                    ? 'স্ট্রুপ রাশ'
                    : isHi
                        ? 'स्ट्रूप रश'
                        : 'Stroop Rush',
                subtitle: isBn
                    ? 'আজকের ফোকাস স্প্রিন্ট'
                    : isHi
                        ? 'आज की फोकस स्प्रिंट'
                        : "Today's focus sprint",
                timeLeft: timeLeftStr,
                isLocked: false,
                isLive: true,
                onTap: () {
                  if (!DailyChallengeAuth.canStart(ref)) {
                    DailyChallengeAuth.requireLogin(context, ref);
                    return;
                  }
                  Navigator.pushNamed(
                    context,
                    AppRouter.introStroopRush,
                    arguments: {'isDailyChallenge': true},
                  );
                },
                isBn: isBn,
                isHi: isHi,
                icon: Icons.palette_rounded,
                emblemPath: 'assets/covers/stroop_rush_emblem.svg',
                footerText: isBn
                    ? 'ফোকাস ও প্রতিক্রিয়া'
                    : isHi
                        ? 'फोकस और प्रतिक्रिया'
                        : 'Focus & reaction',
              ),
              const SizedBox(width: 12),
              // Card 3: Math Speed Sprint (login-gated).
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
                timeLeft: timeLeftStr,
                isLocked: false,
                isLive: false,
                onTap: () {
                  if (!DailyChallengeAuth.canStart(ref)) {
                    DailyChallengeAuth.requireLogin(context, ref);
                    return;
                  }
                  Navigator.pushNamed(
                    context,
                    AppRouter.introMathSprint,
                    arguments: {'isDailyChallenge': true},
                  );
                },
                isBn: isBn,
                isHi: isHi,
                icon: Icons.calculate_rounded,
                emblemPath: 'assets/covers/math_sprint_emblem.svg',
                footerText: null,
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
    required IconData icon,
    String? emblemPath,
    String? footerText,
  }) {
    final categoryColor = isLive
        ? AppColors.primary
        : (badgeText.contains('LOGIC') ||
                badgeText.contains('যুক্তি') ||
                badgeText.contains('तर्क')
            ? AppColors.gamingCyan
            : AppColors.gamingViolet);

    return GameCard(
      width: 148,
      compact: true,
      coverAspectRatio: 1.0,
      icon: icon,
      emblemPath: emblemPath,
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
    final iconColor = isDark ? accent : Color.lerp(accent, Colors.black, 0.30)!;
    final lineColor = (isDark ? Colors.white : Colors.black)
        .withValues(alpha: isDark ? 0.07 : 0.06);
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.14 : 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: isDark
                ? Colors.white.withValues(alpha: 0.85)
                : Colors.grey.shade800,
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
          icon: Icons.star_rounded,
          accent: accentPurple,
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
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 148,
          ),
          children: [
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
                  ? 'এরো পাজল'
                  : isHi
                      ? 'एरो पज़ल'
                      : 'Arrow Puzzle',
              subtitle: isBn
                  ? 'তীর দিয়ে আকৃতি ভেঙে পালান'
                  : isHi
                      ? 'तीरों की आकृति तोड़कर बचें'
                      : 'Escape arrows from silhouettes',
              accent: accentCyan,
              icon: Icons.alt_route_rounded,
              emblemPath: 'assets/covers/arrow_maze_emblem.svg',
              isNew: true,
              footer: isBn
                  ? 'পাজল'
                  : isHi
                      ? 'पहेली'
                      : 'Escape puzzle',
              onTap: () =>
                  Navigator.pushNamed(context, AppRouter.introArrowSilhouette),
            ),
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
              icon: Icons.water_drop_rounded,
              emblemPath: 'assets/covers/flow_free_emblem.svg',
              footer: isBn
                  ? 'পাইপ পাজল'
                  : isHi
                      ? 'पाइप पहेली'
                      : 'Pipe puzzle',
              onTap: () =>
                  Navigator.pushNamed(context, AppRouter.introFlowFree),
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
              icon: Icons.calculate_rounded,
              emblemPath: 'assets/covers/math_sprint_emblem.svg',
              footer: isBn
                  ? 'মানসিক গণিত'
                  : isHi
                      ? 'मानसिक गणित'
                      : 'Mental math',
              onTap: () =>
                  Navigator.pushNamed(context, AppRouter.introMathSprint),
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
              icon: Icons.palette_rounded,
              emblemPath: 'assets/covers/stroop_rush_emblem.svg',
              footer: isBn
                  ? 'ফোকাস ও প্রতিক্রিয়া'
                  : isHi
                      ? 'फोकस व प्रतिक्रिया'
                      : 'Focus & reaction',
              onTap: () =>
                  Navigator.pushNamed(context, AppRouter.introStroopRush),
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
    IconData? icon,
    String? emblemPath,
    String? imagePath,
    Widget? cover,
    bool isNew = false,
  }) {
    return GameCard(
      fillHeight: true,
      compact: true,
      coverHeight: 116,
      icon: icon,
      emblemPath: emblemPath,
      imagePath: imagePath,
      cover: cover,
      accent: accent,
      badge: badgeText,
      isLive: true,
      isNew: isNew,
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
