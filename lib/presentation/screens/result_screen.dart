// lib/presentation/screens/result_screen.dart
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_providers.dart';
import '../providers/scoring_providers.dart';
import '../widgets/result/score_circle.dart';
import '../widgets/result/question_review_card.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/quiz_service.dart';
import '../../core/services/question_tracking_service.dart';
import '../../core/services/daily_progress_service.dart';
import '../../core/scoring/brain_score.dart';
import '../../core/scoring/daily_challenge_service.dart';
import '../../core/scoring/game_performance.dart';
import '../../core/scoring/progression_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_animations.dart';
import '../../core/services/quiz/practice_quiz_service.dart';
import '../../data/models/gamification_models.dart';

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
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _isCompleted = true;
          });
        }
      }
    });
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
      setState(() {
        _isCompleted = false;
      });
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
          AppColors.primary,
          AppColors.secondary,
          AppColors.success,
          AppColors.warning,
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
    if (_isCompleted || !widget.show) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
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
      ),
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
        ..color = c.color.withValues(alpha: (1.0 - progress).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      final y = (c.y + progress * (c.speed * 3.5)) * size.height;
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
  SessionOutcome? _outcome;

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
    final streakAsync = ref.watch(localStreakProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    if (session?.result == null) {
      return Scaffold(
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final result = session!.result!;
    final total = session.quiz.questionCount;
    int score = result.score;
    final totalTimeTaken = session.totalTimeTaken > 0 ? session.totalTimeTaken : AppConstants.questionTimerSeconds * total;
    final streak = streakAsync.value?.currentStreak ?? 0;

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

        // Track daily goal, streak & brain score through the progression engine
        final isPractice = session.quiz.quizId.startsWith('practice_');
        final outcome = await ProgressionService.instance.recordSession(
          SessionRecord(
            gameId: 'quiz',
            mode: isPractice
                ? SessionMode.practice
                : SessionMode.dailyChallenge,
            gameType: isPractice ? GameType.quiz : GameType.challenge,
            primaryPillar: BrainPillar.knowledge,
            performance: QuizPerformanceInput(
              correct: score,
              total: total,
              timeTakenSeconds: totalTimeTaken,
              avgDifficulty: _averageQuizDifficulty(session),
            ),
            isDailyChallenge: !isPractice,
            challengeId: 'gk_challenge',
            playerName: ref.read(authServiceProvider).currentUser?.displayName,
            durationSeconds: totalTimeTaken,
          ),
        );
        if (mounted) {
          setState(() {
            _outcome = outcome;
          });
        }
        ref.invalidate(dailyProgressProvider);

        // Push the normalized challenge score (0-1000) to the global
        // leaderboard. Only the standalone daily challenge does this —
        // workout quizzes never reach this screen, and raw per-game points
        // are never uploaded anywhere.
        final user = ref.read(authServiceProvider).currentUser;
        if (!isPractice && user != null && outcome.challengeScore > 0) {
          unawaited(
            QuizService().submitScoreToLeaderboard(
              playerName: user.displayName ?? 'You',
              score: outcome.challengeScore,
              timeTaken: totalTimeTaken,
              challengeId: DailyChallengeService.todaysChallengeId('quiz'),
            ),
          );
        }

        // Mark questions as answered
        final questionIds = session.quiz.questions.map((q) => q.id).toList();
        await trackingService.markQuestionsAnswered(examMode, questionIds);

        // Update mode stats
        await trackingService.updateModeStats(
            examMode, score, total, totalTimeTaken);

        // Update practice question statistics
        if (session.quiz.quizId.startsWith('practice_')) {
          for (int i = 0; i < session.quiz.questions.length; i++) {
            final q = session.quiz.questions[i];
            final isCorrect = i < session.selectedAnswers.length &&
                session.selectedAnswers[i] == q.correctIndex;
            await PracticeQuizService.instance.recordAnswer(
              questionId: q.id,
              isCorrect: isCorrect,
            );
          }
        }

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
            awardXp: false,
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

        // Prompt guest user to link account on high score (pct >= 0.8) or 3+ day streak
        try {
          final authService = ref.read(authServiceProvider);
          final streakData = await ref.read(localStatsProvider).getStreak();
          if (authService.isAnonymous && (pct >= 0.8 || streakData.currentStreak >= 3) && mounted) {
            _showLinkAccountPrompt(context, lang);
          }
        } catch (_) {}
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
            size: 20,
          ),
          onPressed: () {
            ref.read(quizSessionProvider.notifier).reset();
            Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
          },
        ),
        title: Text(
          isBn ? 'ফলাফল' : isHi ? 'परिणाम' : 'Quiz Result',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: FadeTransition(
              opacity: _entranceFade,
              child: SlideTransition(
                position: _entranceSlide,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      _buildScoreCard(score, total, pct, lang, isDark, isBn, isHi),
                      const SizedBox(height: 20),
                      _buildActionButtons(context, ref, session, score, lang, isDark, isBn, isHi),
                      const SizedBox(height: 20),
                      _buildStatsRow(score, total, totalTimeTaken, streak, _rewards, lang, isDark, isBn, isHi),
                      const SizedBox(height: 20),
                      _buildProgressionCard(lang, isDark, isBn, isHi),
                      const SizedBox(height: 24),
                      _buildReviewSection(session, lang, isDark, isBn, isHi),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ConfettiOverlay(show: pct >= 0.8),
        ],
      ),
    );
  }

  /// Average question difficulty 0-100 (easy 40 / medium 70 / hard 90),
  /// falling back to medium when the quiz has no difficulty metadata.
  double _averageQuizDifficulty(QuizSessionState session) {
    final questions = session.quiz.questions;
    if (questions.isEmpty) return 70;
    var sum = 0.0;
    for (final q in questions) {
      final d = q.difficulty.toLowerCase();
      sum += d == 'hard'
          ? 90
          : d == 'easy'
              ? 40
              : 70;
    }
    return sum / questions.length;
  }

  Widget _buildScoreCard(int score, int total, double pct, String lang,
      bool isDark, bool isBn, bool isHi) {
    String emoji, message;
    Color shadowColor;

    if (pct >= 0.9) {
      emoji = '🏆';
      message = isBn ? 'অসাধারণ!' : isHi ? 'शानदार!' : 'Excellent!';
      shadowColor = AppColors.success;
    } else if (pct >= 0.7) {
      emoji = '🌟';
      message = isBn ? 'দারুণ!' : isHi ? 'बहुत अच्छा!' : 'Great Job!';
      shadowColor = AppColors.primary;
    } else if (pct >= 0.5) {
      emoji = '👍';
      message = isBn ? 'মন্দ নয়!' : isHi ? 'ঠিক है!' : 'Good Effort!';
      shadowColor = AppColors.warning;
    } else {
      emoji = '💪';
      message = isBn ? 'আরো চেষ্টা করুন!' : isHi ? 'कोशिश जारी रखें!' : 'Keep Trying!';
      shadowColor = AppColors.error;
    }

    final cardGradient = LinearGradient(
      colors: isDark 
          ? [const Color(0xFF1E1B4B), const Color(0xFF3B0764)]
          : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: shadowColor.withValues(alpha: isDark ? 0.3 : 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 10),
          Text(message,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5)),
          const SizedBox(height: 24),
          ScoreCircle(
            score: score,
            total: total,
            percentage: pct,
            animation: _scoreRingController,
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
    final isPractice = session.quiz.quizId.startsWith('practice_');

    return Column(
      children: [
        // Primary Call-To-Action: Play Again / Practice Again
        AnimatedScaleButton(
          onTap: () async {
            if (isPractice) {
              final count = session.quiz.questionCount;
              final difficulty = session.quiz.questions.isNotEmpty 
                  ? session.quiz.questions.first.difficulty 
                  : 'medium';

              ref.read(quizSessionProvider.notifier).reset();

              try {
                PracticeQuizService.instance.syncWithFirestore();
                final practiceQuiz = await PracticeQuizService.instance.fetchPracticeQuiz(
                  questionCount: count,
                  difficulty: difficulty == 'All' ? null : difficulty.toLowerCase(),
                );
                if (context.mounted) {
                  ref.read(quizSessionProvider.notifier).startQuiz(practiceQuiz);
                  Navigator.pushReplacementNamed(context, '/quiz');
                }
              } catch (_) {}
            } else {
              // Retake daily quiz
              final originalQuiz = session.quiz;
              ref.read(quizSessionProvider.notifier).reset();
              ref.read(quizSessionProvider.notifier).startQuiz(originalQuiz);
              Navigator.pushReplacementNamed(context, '/quiz');
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.replay_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Play Again / Practice Again',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Secondary Row: Home & Share
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context: context,
                icon: AppIcons.home,
                label: isBn ? 'হোম' : isHi ? 'होम' : 'Home',
                gradient: LinearGradient(
                  colors: isDark 
                      ? [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.03)]
                      : [Colors.white, Colors.grey.shade50],
                ),
                textColor: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                shadowColor: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                borderColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15),
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
                icon: AppIcons.share,
                label: isBn ? 'শেয়ার' : isHi ? 'शेयर' : 'Share',
                gradient: LinearGradient(
                  colors: isDark 
                      ? [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.03)]
                      : [Colors.white, Colors.grey.shade50],
                ),
                textColor: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                shadowColor: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                borderColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15),
                onTap: () async {
                  final percentage = ((score / session.quiz.questionCount) * 100).round();
                  final emoji = percentage >= 80 ? '🌟' : percentage >= 60 ? '👍' : percentage >= 40 ? '💪' : '📚';
                   await Share.share(
                     isBn
                         ? '${AppConstants.appName}-এ আমি ${score}/${session.quiz.questionCount} ($percentage%) $emoji পেয়েছি! 🎯 তুমি পারবে?\n\n#${AppConstants.appName} #DailyQuiz #IndiaQuiz'
                         : isHi
                             ? 'मैंने ${AppConstants.appName} में ${score}/${session.quiz.questionCount} ($percentage%) $emoji स्कोर किया! 🎯 क्या आप कर सकते हैं?\n\n#${AppConstants.appName} #DailyQuiz #IndiaQuiz'
                             : 'I scored ${score}/${session.quiz.questionCount} ($percentage%) $emoji on ${AppConstants.appName}! 🎯\n\nCan you beat me?\n\n#${AppConstants.appName} #DailyQuiz #IndiaQuiz',
                   );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
      {required BuildContext context,
      required IconData icon,
      required String label,
      required LinearGradient gradient,
      required Color textColor,
      required Color shadowColor,
      required Color borderColor,
      required VoidCallback onTap}) {
    return AnimatedScaleButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(
      int score,
      int total,
      int timeTaken,
      int streak,
      QuizRewards? rewards,
      String lang,
      bool isDark,
      bool isBn,
      bool isHi) {
    final wrong = total - score;
    final pct = total > 0 ? (score / total * 100).round() : 0;

    final min = timeTaken ~/ 60;
    final sec = timeTaken % 60;
    final timeStr = min > 0 ? '${min}m ${sec}s' : '${sec}s';

    final accuracyColor = pct >= 80
        ? AppColors.success
        : pct >= 50
            ? AppColors.primary
            : AppColors.error;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Accuracy Circular Card
        Expanded(
          flex: 12,
          child: Container(
            padding: const EdgeInsets.all(16),
            height: 165,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151D30) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.02),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 8,
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                      ),
                      CircularProgressIndicator(
                        value: pct / 100,
                        strokeWidth: 8,
                        color: accuracyColor,
                        strokeCap: StrokeCap.round,
                      ),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isBn ? 'সঠিকতা' : isHi ? 'सटीकता' : 'Accuracy',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isBn ? '$score সঠিক • $wrong ভুল' : isHi ? '$score सही • $wrong गलत' : '$score Correct • $wrong Incorrect',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white30 : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Right: Mini Stat Pills
        Expanded(
          flex: 13,
          child: SizedBox(
            height: 165,
            child: Column(
              children: [
                _buildMiniStatPill(
                  icon: AppIcons.xp,
                  iconColor: Colors.amber,
                  value: '+${_outcome?.xp.granted ?? rewards?.xp ?? (score * 10)} XP',
                  label: isBn ? 'অর্জিত এক্সপি' : isHi ? 'एक्सपी प्राप्त' : 'XP Gained',
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildMiniStatPill(
                  icon: AppIcons.streak,
                  iconColor: Colors.orange,
                  value: '$streak Days',
                  label: isBn ? 'বর্তমান স্ট্রিক' : isHi ? 'दैनिक स्ट्रीक' : 'Current Streak',
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildMiniStatPill(
                  icon: Icons.timer_outlined,
                  iconColor: Colors.cyan,
                  value: timeStr,
                  label: isBn ? 'সময় লেগেছে' : isHi ? 'कुल समय' : 'Time Taken',
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatPill({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151D30) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.01),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white30 : Colors.grey.shade400,
                      height: 1.1,
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

  Widget _buildProgressionCard(String lang, bool isDark, bool isBn, bool isHi) {
    final outcome = _outcome;
    if (outcome == null) return const SizedBox.shrink();
    final rankAsync = ref.watch(myWeeklyRankProvider);

    final skillNames = <String, String>{
      BrainPillar.knowledge:
          isBn ? 'জ্ঞান' : isHi ? 'ज्ञान' : 'Knowledge',
      BrainPillar.logic: isBn ? 'যুক্তি' : isHi ? 'तर्क' : 'Logic',
      BrainPillar.memory: isBn ? 'স্মৃতি' : isHi ? 'स्मृति' : 'Memory',
      BrainPillar.speed: isBn ? 'গতি' : isHi ? 'गति' : 'Speed',
      BrainPillar.reaction:
          isBn ? 'ফোকাস' : isHi ? 'फोकस' : 'Focus',
    };

    final deltas = outcome.skillDeltas.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    final showChallenge = outcome.challengeScore > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D30) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_alt_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                isBn ? 'প্রগ্রেশন' : isHi ? 'प्रगति' : 'Progression',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              const Spacer(),
              if (showChallenge) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${isBn ? 'চ্যালেঞ্জ' : isHi ? 'चुनौती' : 'Challenge'}: ${outcome.challengeScore}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (rankAsync.value case final rank? when rank.rank > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      rank.pointsToNext > 0
                          ? '#${rank.rank} · +${rank.pointsToNext}'
                          : '#${rank.rank}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppColors.warning : AppColors.warningDark,
                      ),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (deltas.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final delta in deltas)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: delta.value >= 0
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.error.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${skillNames[delta.key] ?? delta.key} '
                      '${delta.value >= 0 ? '+' : ''}${delta.value.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: delta.value >= 0
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildProgressionMiniStat(
                  label: isBn ? 'ব্রেন স্কোর' : isHi ? 'ब्रेन स्कोर' : 'Brain Score',
                  value: '${outcome.brain.score}',
                  sub: outcome.brain.weeklyChange >= 0
                      ? '+${outcome.brain.weeklyChange} ${isBn ? 'এই সপ্তাহ' : isHi ? 'इस सप्ताह' : 'this week'}'
                      : '${outcome.brain.weeklyChange} ${isBn ? 'এই সপ্তাহ' : isHi ? 'इस सप्ताह' : 'this week'}',
                  icon: Icons.auto_awesome_rounded,
                  iconColor: AppColors.primary,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildProgressionMiniStat(
                  label: isBn ? 'অবস্থা' : isHi ? 'स्थिति' : 'Status',
                  value: outcome.brain.status == BrainScoreStatus.established
                      ? (isBn ? 'স্থিতিশীল' : isHi ? 'स्थापित' : 'Established')
                      : (isBn ? 'প্রোফাইল তৈরি হচ্ছে' : isHi ? 'प्रोफ़ाइल बन रही है' : 'Building profile'),
                  sub: outcome.dailyGoalComplete
                      ? (isBn ? 'দৈনিক লক্ষ্য সম্পন্ন' : isHi ? 'दैनिक लक्ष्य पूरा' : 'Daily goal complete')
                      : '${outcome.dailyGoalProgress}/${outcome.dailyGoalTotal}',
                  icon: Icons.flag_rounded,
                  iconColor: AppColors.warning,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressionMiniStat({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2338) : const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
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
            sub,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(QuizSessionState session, String lang,
      bool isDark, bool isBn, bool isHi) {
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
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...session.quiz.questions.asMap().entries.map((e) {
          final q = e.value;
          final i = e.key;
          final userAnswer = i < session.selectedAnswers.length ? session.selectedAnswers[i] : null;
          final isCorrect = userAnswer == q.correctIndex;
          final isSkipped = userAnswer == null || userAnswer == -1;
          final options = q.getOptions(lang);

          return QuestionReviewCard(
            question: q,
            index: i,
            userAnswer: userAnswer,
            isCorrect: isCorrect,
            isSkipped: isSkipped,
            options: options,
            lang: lang,
            isDark: isDark,
          );
        }),
      ],
    );
  }

  Future<void> _showLinkAccountPrompt(BuildContext context, String lang) async {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cloud_upload_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              isBn
                  ? 'আপনার প্রগতি সংরক্ষণ করুন!'
                  : isHi
                      ? 'अपनी प्रगति सहेजें!'
                      : 'Save Your Progress!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
        content: Text(
          isBn
              ? 'বিশ্বব্যাপী লিডারবোর্ডে আপনার স্থান সংরক্ষণ করতে এখনই লগইন করুন।'
              : isHi
                  ? 'वैश्विक लीडरबोर्ड पर अपना रैंक सुरक्षित करने के लिए अभी लॉगिन करें।'
                  : 'Login now to save your achievements and rank on the global leaderboard!',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              isBn ? 'পরে' : isHi ? 'बाद में' : 'Later',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
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
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
