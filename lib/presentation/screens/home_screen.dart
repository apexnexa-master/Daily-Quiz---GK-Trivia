// lib/presentation/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../widgets/quiz_cta_card.dart';
import '../widgets/gamification_bar.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/quiz_scheduler_service.dart';
import '../../core/theme/app_theme.dart';

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
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                      Color(0xFF0F172A),
                      Color(0xFF1E1B4B),
                      Color(0xFF0F172A)
                    ])
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                      Color(0xFFF8FAFC),
                      Color(0xFFEEF2FF),
                      Color(0xFFF8FAFC)
                    ]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context, ref, lang, isDark, isBn, isHi),
              Expanded(
                child: RefreshIndicator(
                  color: AppTheme.primaryColor,
                  onRefresh: () async {
                    ref.invalidate(todayQuizProvider);
                    ref.invalidate(localStreakProvider);
                    ref.invalidate(localLeaderboardProvider);
                    ref.invalidate(localPersonalBestProvider);
                    ref.invalidate(totalQuizzesProvider);
                    ref.invalidate(totalScoreProvider);
                    ref.invalidate(gamificationNotifierProvider);
                    ref.invalidate(dailyChallengesProvider);
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildGreeting(context, lang, isDark),
                            const SizedBox(height: 12),
                            _buildCountdownTimer(lang, isDark),
                            const SizedBox(height: 12),
                            const GamificationBar(),
                            const SizedBox(height: 8),
                            const DailyRewardBanner(),
                            const SizedBox(height: 4),
                            const QuickActionsBar(),
                            const SizedBox(height: 12),
                            _buildStatsCards(context, ref, isDark, isBn, isHi),
                            const SizedBox(height: 16),
                            _buildExamModeSelector(context, ref, isDark),
                            const SizedBox(height: 16),
                            quizAsync.when(
                              data: (quiz) =>
                                  QuizCtaCard(quiz: quiz, lang: lang, ref: ref),
                              loading: () => _buildShimmer(180, isDark),
                              error: (e, _) =>
                                  _buildErrorCard(e.toString(), isDark),
                            ),
                            const SizedBox(height: 16),
                            const DailyChallengesCard(),
                            const SizedBox(height: 16),
                            _buildLeaderboardPreview(
                                context, ref, lang, isDark),
                            const SizedBox(height: 100),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              isProAsync.when(
                data: (isPro) =>
                    isPro ? const SizedBox.shrink() : const BannerAdWidget(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, WidgetRef ref, String lang,
      bool isDark, bool isBn, bool isHi) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppTheme.primaryGradientDark
                  : AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child:
                const Icon(Icons.quiz_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Daily GK',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.primaryColor)),
              Text(
                  isBn
                      ? 'আপনার দৈনিক কুইজ'
                      : isHi
                          ? 'आज का क्विज़'
                          : 'Your Daily Quiz',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.grey)),
            ],
          ),
          const Spacer(),
          _LanguageButton(ref: ref, lang: lang),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppTheme.primaryGradientDark
                    : AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
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
    return Text(greeting,
        style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87));
  }

  Widget _buildCountdownTimer(String lang, bool isDark) {
    final scheduler = QuizSchedulerService.instance;
    final isQuizActive = scheduler.isQuizActive();
    final countdownStr = scheduler.getCountdownString();
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    Color statusColor;
    IconData statusIcon;

    if (isQuizActive) {
      statusColor = AppTheme.successColor;
      statusIcon = Icons.play_circle_filled;
    } else {
      final now = DateTime.now();
      final startHour = scheduler.quizStartHour;
      if (now.hour >= startHour) {
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.schedule;
      } else {
        statusColor = AppTheme.primaryColor;
        statusIcon = Icons.timer;
      }
    }

    return GestureDetector(
      onTap: () => _onCountdownTapped(context, isQuizActive, lang),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              statusColor.withValues(alpha: isDark ? 0.2 : 0.15),
              statusColor.withValues(alpha: isDark ? 0.1 : 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(statusIcon, color: statusColor, size: 24),
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
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    countdownStr,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
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
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
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
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

Widget _buildStatsCards(
    BuildContext context, WidgetRef ref, bool isDark, bool isBn, bool isHi) {
  final streakAsync = ref.watch(localStreakProvider);
  final bestAsync = ref.watch(localPersonalBestProvider);
  final totalAsync = ref.watch(totalQuizzesProvider);
  final totalScoreAsync = ref.watch(totalScoreProvider);

  return Row(
    children: [
      Expanded(
          child: streakAsync.when(
        data: (s) => _buildStatCard(context,
            icon: Icons.local_fire_department_rounded,
            value: '${s.currentStreak}',
            label: isBn
                ? 'ধারাবাহিকতা'
                : isHi
                    ? 'स्ट्रीक'
                    : 'Streak',
            color: Colors.orange,
            isDark: isDark,
            iconBg: Colors.orange),
        loading: () => _buildShimmer(80, isDark),
        error: (_, __) => _buildStatCard(context,
            icon: Icons.local_fire_department_rounded,
            value: '0',
            label: isBn
                ? 'ধারাবাহিকতা'
                : isHi
                    ? 'स्ट्रीक'
                    : 'Streak',
            color: Colors.orange,
            isDark: isDark,
            iconBg: Colors.orange),
      )),
      const SizedBox(width: 12),
      Expanded(
          child: bestAsync.when(
        data: (b) => _buildStatCard(context,
            icon: Icons.emoji_events_rounded,
            value: b.totalQuestions > 0 ? '${b.percentage}%' : '--',
            label: isBn
                ? 'সেরা স্কোর'
                : isHi
                    ? 'सर्वश्रेष्ठ'
                    : 'Best',
            color: AppTheme.primaryColor,
            isDark: isDark,
            iconBg: AppTheme.primaryColor),
        loading: () => _buildShimmer(80, isDark),
        error: (_, __) => _buildStatCard(context,
            icon: Icons.emoji_events_rounded,
            value: '--',
            label: isBn
                ? 'সেরা স্কোর'
                : isHi
                    ? 'सर्वश्रेष्ठ'
                    : 'Best',
            color: AppTheme.primaryColor,
            isDark: isDark,
            iconBg: AppTheme.primaryColor),
      )),
      const SizedBox(width: 12),
      Expanded(
          child: totalAsync.when(
        data: (t) => totalScoreAsync.when(
          data: (s) => _buildStatCard(context,
              icon: Icons.analytics_rounded,
              value: '$t',
              label: isBn
                  ? 'কুইজ'
                  : isHi
                      ? 'क्विज़'
                      : 'Quizzes',
              color: AppTheme.successColor,
              isDark: isDark,
              iconBg: AppTheme.successColor,
              subtitle: '+$s pts'),
          loading: () => _buildShimmer(80, isDark),
          error: (_, __) => _buildStatCard(context,
              icon: Icons.analytics_rounded,
              value: '$t',
              label: isBn
                  ? 'কুইজ'
                  : isHi
                      ? 'क्विज़'
                      : 'Quizzes',
              color: AppTheme.successColor,
              isDark: isDark,
              iconBg: AppTheme.successColor),
        ),
        loading: () => _buildShimmer(80, isDark),
        error: (_, __) => _buildShimmer(80, isDark),
      )),
    ],
  );
}

Widget _buildStatCard(BuildContext context,
    {required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
    Color? iconBg,
    String? subtitle}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.1)),
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4))
            ],
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: (iconBg ?? color).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconBg ?? color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87)),
        if (subtitle != null)
          Text(subtitle,
              style: TextStyle(
                  fontSize: 9,
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w600)),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: isDark ? Colors.white54 : Colors.grey)),
      ],
    ),
  );
}

Widget _buildExamModeSelector(
    BuildContext context, WidgetRef ref, bool isDark) {
  final current = ref.watch(examModeProvider);
  final modes = [
    ('GENERAL', '📚'),
    ('WBPSC', '🏛️'),
    ('SSC', '📝'),
    ('UPSC', '🎯'),
    ('BANK', '💰')
  ];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Select Exam',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.grey)),
      const SizedBox(height: 10),
      SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: modes.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final mode = modes[i].$1;
            final emoji = modes[i].$2;
            final selected = mode == current;
            return GestureDetector(
              onTap: () {
                ref.read(examModeProvider.notifier).state = mode;
                ref.invalidate(todayQuizProvider);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          : Colors.white),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.2))),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text('$emoji $mode',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black54))),
              ),
            );
          },
        ),
      ),
    ],
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
          Icon(Icons.leaderboard_rounded,
              size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(
              isBn
                  ? "আজকের শীর্ষ"
                  : isHi
                      ? "आज के शीर्ष"
                      : "Today's Top",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87)),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/leaderboard'),
            child: Text(isBn ? 'সব দেখুন →' : 'See all →',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      const SizedBox(height: 8),
      leaderboardAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(24),
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
                          : 'Be the first to attempt!',
                      style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey))),
            );
          }
          return Container(
            decoration: BoxDecoration(
              color:
                  isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: entries.take(5).toList().asMap().entries.map((e) {
                final entry = e.value;
                final rank = e.key + 1;
                final medals = {1: '🥇', 2: '🥈', 3: '🥉'};
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: e.key < entries.length - 1
                        ? Border(
                            bottom: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.withValues(alpha: 0.08)))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Text(rank <= 3 ? medals[rank]! : '#$rank',
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 12),
                      CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              AppTheme.primaryColor.withValues(alpha: 0.15),
                          child: Text(entry.playerName[0],
                              style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(entry.playerName,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark ? Colors.white : Colors.black87))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getScoreColor(entry.score)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${entry.score}/10',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _getScoreColor(entry.score))),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
        loading: () => _buildShimmer(120, isDark),
        error: (_, __) => _buildShimmer(120, isDark),
      ),
    ],
  );
}

Color _getScoreColor(int score) {
  if (score >= 8) return AppTheme.successColor;
  if (score >= 5) return AppTheme.warningColor;
  return AppTheme.errorColor;
}

Widget _buildShimmer(double height, bool isDark) {
  return Container(
    height: height,
    decoration: BoxDecoration(
      color: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.grey.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
    ),
  );
}

Widget _buildErrorCard(String msg, bool isDark) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.errorColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppTheme.errorColor),
        const SizedBox(width: 8),
        Expanded(
            child:
                Text(msg, style: const TextStyle(color: AppTheme.errorColor))),
      ],
    ),
  );
}

class _LanguageButton extends StatelessWidget {
  final WidgetRef ref;
  final String lang;
  const _LanguageButton({required this.ref, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langs = [
      ('en', Icons.language, 'English'),
      ('hi', Icons.language, 'हिंदी'),
      ('bn', Icons.language, 'বাংলা'),
    ];
    final currentLang =
        langs.firstWhere((e) => e.$1 == lang, orElse: () => langs[0]);
    return PopupMenuButton<String>(
      initialValue: lang,
      onSelected: (l) => ref.read(languageProvider.notifier).setLanguage(l),
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF6366F1).withValues(alpha: 0.2),
              const Color(0xFF8B5CF6).withValues(alpha: 0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(currentLang.$2, size: 16, color: const Color(0xFF6366F1)),
            const SizedBox(width: 4),
            Text(lang.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6366F1))),
          ],
        ),
      ),
      itemBuilder: (_) => langs
          .map((l) => PopupMenuItem(
                value: l.$1,
                child: Row(
                  children: [
                    Icon(l.$2, size: 20, color: const Color(0xFF6366F1)),
                    const SizedBox(width: 12),
                    Text(l.$3,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
