// lib/presentation/screens/result_screen.dart
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_providers.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/question_tracking_service.dart';
import '../../core/services/quiz_scheduler_service.dart';
import '../../core/services/gamification_service.dart';
import '../../core/theme/app_theme.dart';

class ConfettiOverlay extends StatefulWidget {
  final bool show;

  const ConfettiOverlay({super.key, required this.show});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Confetti> _confetti = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.show) {
      _initConfetti();
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _initConfetti();
      _controller.forward(from: 0);
    }
  }

  void _initConfetti() {
    _confetti.clear();
    for (int i = 0; i < 50; i++) {
      _confetti.add(_Confetti(
        x: _random.nextDouble(),
        y: _random.nextDouble() * 0.3 - 0.3,
        size: _random.nextDouble() * 8 + 4,
        speed: _random.nextDouble() * 0.3 + 0.2,
        angle: _random.nextDouble() * math.pi * 2,
        rotationSpeed: _random.nextDouble() * 10 - 5,
        color: [
          AppTheme.primaryColor,
          AppTheme.secondaryColor,
          AppTheme.successColor,
          AppTheme.warningColor,
          Colors.pink,
          Colors.cyan,
        ][_random.nextInt(6)],
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _ConfettiPainter(
            confetti: _confetti,
            progress: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Confetti {
  double x;
  double y;
  double size;
  double speed;
  double angle;
  double rotationSpeed;
  Color color;

  _Confetti({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.angle,
    required this.rotationSpeed,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Confetti> confetti;
  final double progress;

  _ConfettiPainter({required this.confetti, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (var c in confetti) {
      final paint = Paint()
        ..color = c.color.withValues(alpha: 1.0 - progress * 0.5)
        ..style = PaintingStyle.fill;

      final y = (c.y + progress * c.speed) * size.height;
      final x = c.x * size.width + math.sin(y * 0.02 + c.angle) * 30;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(c.angle + progress * c.rotationSpeed);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: c.size, height: c.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key});
  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _scoreRingController;
  late AnimationController _entranceController;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;
  bool _hasUpdatedStats = false;
  QuizRewards? _rewards;

  @override
  void initState() {
    super.initState();

    _scoreRingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _entranceFade =
        CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _entranceSlide =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entranceController, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) AdService.instance.showInterstitial();
    });
  }

  @override
  void dispose() {
    _scoreRingController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(quizSessionProvider);
    final lang = ref.watch(languageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    if (session?.result == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final result = session!.result!;
    final total = session.quiz.questionCount;
    int score = result.score;
    final totalTimeTaken = session.totalTimeTaken > 0 ? session.totalTimeTaken : 30 * total;

    // Calculate actual score for local quizzes
    if (session.quiz.quizId.startsWith('local_')) {
      score = 0;
      for (int i = 0; i < session.quiz.questions.length; i++) {
        if (i < session.selectedAnswers.length &&
            session.selectedAnswers[i] ==
                session.quiz.questions[i].correctIndex) {
          score++;
        }
      }
    }

    final pct = total > 0 ? score / total : 0.0;

    // Update per-mode stats and achievements
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_hasUpdatedStats) {
        _hasUpdatedStats = true;

        // Update per-mode stats
        final examMode = session.quiz.examMode;
        final trackingService = QuestionTrackingService.instance;

        // Mark questions as answered
        final questionIds = session.quiz.questions.map((q) => q.id).toList();
        await trackingService.markQuestionsAnswered(examMode, questionIds);

        // Update mode stats
        await trackingService.updateModeStats(
            examMode, score, total, totalTimeTaken);

        // Update achievements
        final streak = await ref.read(localStatsProvider).getStreak();
        final totalQuizzes =
            await ref.read(localStatsProvider).getTotalQuizzes();
        final personalBest =
            await ref.read(localStatsProvider).getPersonalBest();
        final modeStats = await trackingService.getAllModeStats();

        final modeScores = <String, int>{};
        for (final entry in modeStats.entries) {
          modeScores[entry.key] = entry.value.averageScore;
        }

        await trackingService.checkAndUnlockAchievements(
          totalQuizzes: totalQuizzes,
          currentStreak: streak.currentStreak,
          bestScore: personalBest.percentage,
          modeScores: modeScores,
        );

        // Calculate and apply gamification rewards
        try {
          final rewards = await ref.read(gamificationServiceProvider).calculateQuizRewards(
            score: score,
            totalQuestions: total,
            timeTaken: totalTimeTaken,
          );
          if (mounted) {
            setState(() {
              _rewards = rewards;
            });
          }
        } catch (_) {}

        // Sync local stats to cloud
        try {
          await ref.read(cloudSyncServiceProvider).syncStatsToCloud();
        } catch (_) {}

        // Refresh gamification stats notifier
        try {
          await ref.read(gamificationNotifierProvider.notifier).refresh();
        } catch (_) {}

        // Refresh providers
        ref.invalidate(localStreakProvider);
        ref.invalidate(localLeaderboardProvider);
        ref.invalidate(localPersonalBestProvider);
        ref.invalidate(totalQuizzesProvider);
        ref.invalidate(achievementsProvider);
        ref.invalidate(modeStatsProvider);
        ref.invalidate(userStatsProvider);
      }
    });

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SafeArea(
            child: FadeTransition(
              opacity: _entranceFade,
              child: SlideTransition(
                position: _entranceSlide,
                child: Column(
                  children: [
                    _buildScoreHero(
                        score, total, pct, lang, isDark, isBn, isHi),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildActionButtons(context, ref, session, score,
                                lang, isDark, isBn, isHi),
                            const SizedBox(height: 20),
                            _buildRewardsCard(isDark, isBn, isHi),
                            _buildStatsRow(
                                score, total, lang, isDark, isBn, isHi),
                            const SizedBox(height: 20),
                            _buildReviewSection(
                                session, lang, isDark, isBn, isHi),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ConfettiOverlay(show: pct >= 0.8),
        ],
      ),
    );
  }

  Widget _buildScoreHero(int score, int total, double pct, String lang,
      bool isDark, bool isBn, bool isHi) {
    String emoji, message;
    Color ringColor;

    if (pct >= 0.9) {
      emoji = '🏆';
      message = isBn
          ? 'অসাধারণ!'
          : isHi
              ? 'शानदार!'
              : 'Excellent!';
      ringColor = AppTheme.successColor;
    } else if (pct >= 0.7) {
      emoji = '🌟';
      message = isBn
          ? 'দারুণ!'
          : isHi
              ? 'बहुत अच्छा!'
              : 'Great Job!';
      ringColor = AppTheme.primaryColor;
    } else if (pct >= 0.5) {
      emoji = '👍';
      message = isBn
          ? 'মন্দ নয়!'
          : isHi
              ? 'ठीक है!'
              : 'Good Effort!';
      ringColor = AppTheme.warningColor;
    } else {
      emoji = '💪';
      message = isBn
          ? 'আরো চেষ্টা করুন!'
          : isHi
              ? 'कोशिश जारी रखें!'
              : 'Keep Trying!';
      ringColor = AppTheme.errorColor;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        gradient:
            isDark ? AppTheme.primaryGradientDark : AppTheme.primaryGradient,
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 24),
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                    width: 150,
                    height: 150,
                    child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 12,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation(
                            Colors.white.withValues(alpha: 0.15)))),
                AnimatedBuilder(
                  animation: _scoreRingController,
                  builder: (_, __) {
                    final curve = CurvedAnimation(
                        parent: _scoreRingController,
                        curve: Curves.easeOutCubic);
                    return SizedBox(
                      width: 150,
                      height: 150,
                      child: Transform.rotate(
                        angle: -math.pi / 2,
                        child: CircularProgressIndicator(
                          value: curve.value * pct,
                          strokeWidth: 12,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation(ringColor),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                    );
                  },
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _scoreRingController,
                      builder: (_, __) {
                        final curve = CurvedAnimation(
                            parent: _scoreRingController,
                            curve: Curves.easeOutCubic);
                        final displayScore = (curve.value * score).round();
                        return Text('$displayScore',
                            style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.0));
                      },
                    ),
                    Text('out of $total',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context,
      WidgetRef ref,
      QuizSessionState session,
      int score,
      String lang,
      bool isDark,
      bool isBn,
      bool isHi) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            context: context,
            icon: Icons.home_rounded,
            label: isBn
                ? 'হোম'
                : isHi
                    ? 'होम'
                    : 'Home',
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.shade200,
            textColor: isDark ? Colors.white : Colors.black87,
            onTap: () {
              ref.read(quizSessionProvider.notifier).reset();
              Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            context: context,
            icon: Icons.share_rounded,
            label: isBn
                ? 'শেয়ার করুন'
                : isHi
                    ? 'शेयर करें'
                    : 'Share',
            color: AppTheme.primaryColor,
            textColor: Colors.white,
            onTap: () async {
              final percentage =
                  ((score / session.quiz.questionCount) * 100).round();
              final emoji = percentage >= 80
                  ? '🌟'
                  : percentage >= 60
                      ? '👍'
                      : percentage >= 40
                          ? '💪'
                          : '📚';
              await Share.share(
                isBn
                    ? 'GK Quiz-এ আমি ${score}/${session.quiz.questionCount} ($percentage%) $emoji পেয়েছি! 🎯 তুমি পারবে?\n\n#GKQuiz #DailyQuiz #IndiaQuiz'
                    : isHi
                        ? 'मैंने GK Quiz में ${score}/${session.quiz.questionCount} ($percentage%) $emoji स्कोर किया! 🎯 क्या आप कर सकते हैं?\n\n#GKQuiz #DailyQuiz #IndiaQuiz'
                        : 'I scored ${score}/${session.quiz.questionCount} ($percentage%) $emoji on GK Quiz! 🎯\n\nCan you beat me?\n\n#GKQuiz #DailyQuiz #IndiaQuiz',
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            context: context,
            icon: Icons.leaderboard_rounded,
            label: isBn
                ? 'র‌্যাংকিং'
                : isHi
                    ? 'रैंकिंग'
                    : 'Ranking',
            color: AppTheme.secondaryColor,
            textColor: Colors.white,
            onTap: () => Navigator.pushNamed(context, '/leaderboard'),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
      {required BuildContext context,
      required IconData icon,
      required String label,
      required Color color,
      required Color textColor,
      required VoidCallback onTap}) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: textColor, size: 22),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(
      int score, int total, String lang, bool isDark, bool isBn, bool isHi) {
    final wrong = total - score;
    final pct = total > 0 ? (score / total * 100).round() : 0;
    return Row(
      children: [
        _buildStatPill(
            icon: Icons.check_circle_rounded,
            value: '$score',
            label: isBn ? 'সঠিক' : 'Correct',
            color: AppTheme.successColor,
            isDark: isDark),
        const SizedBox(width: 10),
        _buildStatPill(
            icon: Icons.cancel_rounded,
            value: '$wrong',
            label: isBn ? 'ভুল' : 'Wrong',
            color: AppTheme.errorColor,
            isDark: isDark),
        const SizedBox(width: 10),
        _buildStatPill(
            icon: Icons.percent_rounded,
            value: '$pct%',
            label: isBn ? 'শতাংশ' : 'Percent',
            color: AppTheme.primaryColor,
            isDark: isDark),
      ],
    );
  }

  Widget _buildStatPill(
      {required IconData icon,
      required String value,
      required String label,
      required Color color,
      required bool isDark}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection(QuizSessionState session, String lang, bool isDark,
      bool isBn, bool isHi) {
    final scheduler = QuizSchedulerService.instance;
    final canShowAnswers =
        scheduler.canShowAnswers() || !scheduler.isQuizActive();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isBn
                    ? 'প্রশ্ন পর্যালোচনা'
                    : isHi
                        ? 'प्रश्न-वार समीक्षा'
                        : 'Question Review',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87),
              ),
            ),
            if (!canShowAnswers)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 14, color: AppTheme.warningColor),
                    const SizedBox(width: 4),
                    Text(
                      isBn
                          ? 'বন্ধ'
                          : isHi
                              ? 'बंद'
                              : 'Locked',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (!canShowAnswers)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.warningColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: AppTheme.warningColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isBn
                        ? 'উত্তর এবং ব্যাখ্যা কুইজ শেষ হওয়ার পরে দেখা যাবে।'
                        : isHi
                            ? 'उत्तर और स्पष्टीकरण क्विज़ समाप्त होने के बाद दिखाई देंगे।'
                            : 'Answers and explanations will be available after the quiz ends.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (!canShowAnswers) const SizedBox(height: 12),
        ...session.quiz.questions.asMap().entries.map((e) {
          final q = e.value;
          final i = e.key;
          final userAnswer = i < session.selectedAnswers.length
              ? session.selectedAnswers[i]
              : null;
          final isCorrect = userAnswer == q.correctIndex;
          final isSkipped = userAnswer == null || userAnswer == -1;
          final options = q.getOptions(lang);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color:
                  isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: (isCorrect
                          ? AppTheme.successColor
                          : isSkipped
                              ? Colors.grey
                              : AppTheme.errorColor)
                      .withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: (isCorrect
                            ? AppTheme.successColor
                            : isSkipped
                                ? Colors.grey
                                : AppTheme.errorColor)
                        .withValues(alpha: 0.1),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: (isCorrect
                                  ? AppTheme.successColor
                                  : isSkipped
                                      ? Colors.grey
                                      : AppTheme.errorColor)
                              .withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text('${i + 1}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isCorrect
                                    ? AppTheme.successColor
                                    : isSkipped
                                        ? Colors.grey
                                        : AppTheme.errorColor)),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                          isCorrect
                              ? Icons.check_circle
                              : isSkipped
                                  ? Icons.remove_circle_outline
                                  : Icons.cancel,
                          color: isCorrect
                              ? AppTheme.successColor
                              : isSkipped
                                  ? Colors.grey
                                  : AppTheme.errorColor,
                          size: 16),
                      const SizedBox(width: 4),
                      Text(
                          isCorrect
                              ? (isBn
                                  ? '✓ সঠিক'
                                  : isBn
                                      ? '✓ सही'
                                      : 'Correct')
                              : isSkipped
                                  ? (isBn ? 'এড়িয়ে গেছে' : 'Skipped')
                                  : (isBn ? '✗ ভুল' : 'Wrong'),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isCorrect
                                  ? AppTheme.successColor
                                  : isSkipped
                                      ? Colors.grey
                                      : AppTheme.errorColor)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q.getText(lang),
                          style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white : null,
                              height: 1.4)),
                      const SizedBox(height: 10),
                      if (canShowAnswers) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor
                                .withValues(alpha: isDark ? 0.1 : 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppTheme.successColor
                                    .withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: AppTheme.successColor, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                      options.length > q.correctIndex
                                          ? options[q.correctIndex]
                                          : '',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.successColor))),
                            ],
                          ),
                        ),
                        if (!isCorrect &&
                            !isSkipped &&
                            userAnswer >= 0 &&
                            userAnswer < options.length) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor
                                  .withValues(alpha: isDark ? 0.08 : 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppTheme.errorColor
                                      .withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.cancel_rounded,
                                    color: AppTheme.errorColor, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(options[userAnswer],
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.errorColor))),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor
                                .withValues(alpha: isDark ? 0.1 : 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lightbulb_rounded,
                                  color: AppTheme.primaryColor, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(q.getExplanation(lang),
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white70 : null,
                                          height: 1.4))),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRewardsCard(bool isDark, bool isBn, bool isHi) {
    if (_rewards == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF1E1B4B), // Indigo dark
                  const Color(0xFF311042), // Purple dark
                ]
              : [
                  const Color(0xFFEEF2FF), // Indigo light
                  const Color(0xFFFDF2F8), // Pink light
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppTheme.primaryColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isBn
                ? 'কুইজ পুরস্কার অর্জিত! 🎉'
                : isHi
                    ? 'क्विज़ पुरस्कार प्राप्त! 🎉'
                    : 'Quiz Rewards Earned! 🎉',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppTheme.primaryColor,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // XP Reward
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.blue, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '+${_rewards!.xp}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'XP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Vertical Divider
              Container(
                height: 32,
                width: 1,
                color: isDark ? Colors.white12 : Colors.grey[300],
              ),
              // Coins Reward
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '+${_rewards!.coins}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        isBn ? 'কয়েন' : isHi ? 'सिक्के' : 'Coins',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (_rewards!.isPerfect || _rewards!.isSpeedBonus || _rewards!.isStreakBonus) ...[
            const SizedBox(height: 14),
            Divider(color: isDark ? Colors.white12 : Colors.grey[200], height: 1),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                if (_rewards!.isPerfect)
                  _buildBonusChip(
                    icon: Icons.star_rounded,
                    label: isBn ? 'নিখুঁত স্কোর' : isHi ? 'परफेक्ट स्कोर' : 'Perfect Score',
                    color: Colors.purple,
                    isDark: isDark,
                  ),
                if (_rewards!.isSpeedBonus)
                  _buildBonusChip(
                    icon: Icons.speed_rounded,
                    label: isBn ? 'গতি বোনাস' : isHi ? 'स्पीड बोनस' : 'Speed Bonus',
                    color: Colors.orange,
                    isDark: isDark,
                  ),
                if (_rewards!.isStreakBonus)
                  _buildBonusChip(
                    icon: Icons.local_fire_department_rounded,
                    label: isBn ? 'ধারাবাহিকতা বোনাস' : isHi ? 'स्ट्रीक बोनस' : 'Streak Bonus',
                    color: Colors.red,
                    isDark: isDark,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBonusChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
