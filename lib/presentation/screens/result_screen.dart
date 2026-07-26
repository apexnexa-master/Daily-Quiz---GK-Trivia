// lib/presentation/screens/result_screen.dart
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_providers.dart';
import '../widgets/result/score_circle.dart';
import '../widgets/result/xp_breakdown_card.dart';
import '../widgets/result/question_review_card.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/question_tracking_service.dart';
import '../../core/services/quiz_scheduler_service.dart';
import '../../core/services/gamification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final result = session!.result!;
    final total = session.quiz.questionCount;
    int score = result.score;
    final totalTimeTaken = session.totalTimeTaken > 0 ? session.totalTimeTaken : AppConstants.questionTimerSeconds * total;

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
                      _buildStatsRow(score, total, lang, isDark, isBn, isHi),
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
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            context: context,
            icon: AppIcons.home,
            label: isBn ? 'হোম' : isHi ? 'होम' : 'Home',
            gradient: LinearGradient(
              colors: isDark 
                  ? [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.04)]
                  : [Colors.white, Colors.grey.shade100],
            ),
            textColor: isDark ? Colors.white : AppColors.textPrimaryLight,
            shadowColor: Colors.black.withValues(alpha: 0.05),
            borderColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
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
            label: isBn ? 'শেয়ার করুন' : isHi ? 'शेयर करें' : 'Share',
            gradient: AppColors.primaryGradient,
            textColor: Colors.white,
            shadowColor: AppColors.primary.withValues(alpha: 0.3),
            borderColor: Colors.transparent,
            onTap: () async {
              final percentage = ((score / session.quiz.questionCount) * 100).round();
              final emoji = percentage >= 80 ? '🌟' : percentage >= 60 ? '👍' : percentage >= 40 ? '💪' : '📚';
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: textColor, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: textColor)),
          ],
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
            icon: AppIcons.correct,
            value: '$score',
            label: isBn ? 'সঠিক' : 'Correct',
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shadowColor: const Color(0xFF10B981),
            isDark: isDark),
        const SizedBox(width: 10),
        _buildStatPill(
            icon: AppIcons.incorrect,
            value: '$wrong',
            label: isBn ? 'ভুল' : 'Wrong',
            gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shadowColor: const Color(0xFFEF4444),
            isDark: isDark),
        const SizedBox(width: 10),
        _buildStatPill(
            icon: Icons.percent_rounded,
            value: '$pct%',
            label: isBn ? 'শতাংশ' : 'Percent',
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shadowColor: const Color(0xFF3B82F6),
            isDark: isDark),
      ],
    );
  }

  Widget _buildStatPill(
      {required IconData icon,
      required String value,
      required String label,
      required LinearGradient gradient,
      required Color shadowColor,
      required bool isDark}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withValues(alpha: isDark ? 0.3 : 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection(QuizSessionState session, String lang, bool isDark,
      bool isBn, bool isHi) {
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
}
