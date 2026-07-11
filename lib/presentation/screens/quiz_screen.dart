// lib/presentation/screens/quiz_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../widgets/quiz/question_card.dart';
import '../widgets/quiz/quiz_timer_bar.dart';
import '../widgets/quiz/quiz_progress_stepper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_animations.dart';
import '../../core/constants/app_constants.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});
  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  Timer? _answerDelayTimer;
  int _totalTimeTaken = 0;
  late AnimationController _timerController;
  late AnimationController _questionFadeController;
  late AnimationController _pulseController;
  late AnimationController _correctAnimationController;
  late AnimationController _wrongAnimationController;
  bool _isDark = false;
  int? _selectedAnswerForFeedback;
  bool? _isAnswerCorrect;
  bool _lifeline5050Used = false;
  bool _lifelineExtraTimeUsed = false;
  String _currentLang = 'en';
  Set<int> _5050VisibleIndices = {};
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: AppConstants.questionTimerSeconds),
      value: 1.0,
    )..reverse();

    _questionFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _correctAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _wrongAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _startTimer();
  }

  List<int> get5050Indices() {
    if (_lifeline5050Used) return [];
    final session = ref.read(quizSessionProvider);
    if (session == null) return [];
    final question = session.quiz.questions[session.currentIndex];
    final correct = question.correctIndex;
    final totalOptions = question.getOptions(_currentLang).length;

    if (totalOptions < 4) return [];

    final allWrong = List.generate(totalOptions, (i) => i)..remove(correct);
    allWrong.shuffle();

    final toRemove = allWrong.take(2).toList();
    final visibleIndices = {correct, toRemove[0]};

    setState(() {
      _lifeline5050Used = true;
      _5050VisibleIndices = visibleIndices;
    });

    return visibleIndices.toList();
  }

  void useExtraTime() {
    if (_lifelineExtraTimeUsed) return;
    setState(() => _lifelineExtraTimeUsed = true);
    ref.read(quizSessionProvider.notifier).setRemainingSeconds(
          ref.read(quizSessionProvider)!.remainingSeconds + 15,
        );
    _startTimer();
  }

  void _startTimer() {
    _timerController.value = 1.0;
    _resumeTimer();
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });

    if (_isPaused) {
      _timer?.cancel();
      _timerController.stop();
    } else {
      _resumeTimer();
    }
  }

  void _resumeTimer() {
    _timer?.cancel();
    _timerController.reverse();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _totalTimeTaken++;

      final session = ref.read(quizSessionProvider);
      if (session == null) return;

      final newSeconds = session.remainingSeconds - 1;
      if (newSeconds <= 0) {
        ref.read(quizSessionProvider.notifier).nextQuestion();
        _onQuestionAdvanced();
      } else {
        ref.read(quizSessionProvider.notifier).setRemainingSeconds(newSeconds);
      }
    });
  }

  void _onQuestionAdvanced() {
    final session = ref.read(quizSessionProvider);
    if (session == null) return;

    if (session.isComplete) {
      _timer?.cancel();
      _submitQuiz();
    } else {
      _questionFadeController.reset();
      _questionFadeController.forward();
      _timer?.cancel();
      _lifeline5050Used = false;
      _lifelineExtraTimeUsed = false;
      _5050VisibleIndices = {};
      _startTimer();
    }
  }

  Future<void> _submitQuiz() async {
    try {
      await ref.read(quizSessionProvider.notifier).submitQuiz(_totalTimeTaken);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/result');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onAnswerSelected(int qIndex, int aIndex) {
    final session = ref.read(quizSessionProvider);
    if (session == null) return;

    final question = session.quiz.questions[qIndex];
    final isCorrect = aIndex == question.correctIndex;

    ref.read(quizSessionProvider.notifier).selectAnswer(qIndex, aIndex);

    setState(() {
      _selectedAnswerForFeedback = aIndex;
      _isAnswerCorrect = isCorrect;
      if (isCorrect) {
        _correctAnimationController.forward(from: 0);
      } else {
        _wrongAnimationController.forward(from: 0);
      }
    });

    _timer?.cancel();
    _answerDelayTimer?.cancel();
    _answerDelayTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _selectedAnswerForFeedback = null;
        _isAnswerCorrect = null;
      });
      ref.read(quizSessionProvider.notifier).nextQuestion();
      _onQuestionAdvanced();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _answerDelayTimer?.cancel();
    _timerController.dispose();
    _questionFadeController.dispose();
    _pulseController.dispose();
    _correctAnimationController.dispose();
    _wrongAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(quizSessionProvider);
    final lang = ref.watch(languageProvider);
    _currentLang = lang;
    _isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    if (session == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    size: 48, color: AppColors.error),
              ),
              const SizedBox(height: 16),
              Text(
                'No quiz loaded. Please go back and try again.',
                style: TextStyle(color: _isDark ? Colors.white70 : Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (session.isComplete) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                isBn
                    ? 'ফলাফল লোড হচ্ছে...'
                    : isHi
                        ? 'परिणाम लोड हो रहा है...'
                        : 'Loading results...',
                style: TextStyle(color: _isDark ? Colors.white70 : Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    final question = session.quiz.questions[session.currentIndex];
    final examMode = session.quiz.examMode;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _showExitDialog(context);
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isDark
                  ? [
                      AppColors.bgDark,
                      Color.alphaBlend(
                        AppColors.examModeColor(examMode).withValues(alpha: 0.12),
                        AppColors.bgDark,
                      ),
                    ]
                  : [
                      Colors.white,
                      Color.alphaBlend(
                        AppColors.examModeColor(examMode).withValues(alpha: 0.06),
                        const Color(0xFFF8FAFC),
                      ),
                    ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      // Sleek Quiz AppBar Header
                      _buildHeaderBar(session, lang),
                      
                      // Question and Options Card
                      Expanded(
                        child: FadeTransition(
                          opacity: _questionFadeController,
                          child: QuestionCard(
                            question: question,
                            lang: lang,
                            selectedAnswer: session.selectedAnswers[session.currentIndex],
                            onAnswerSelected: (i) => _onAnswerSelected(session.currentIndex, i),
                            isDark: _isDark,
                            visibleOptions: _lifeline5050Used && _5050VisibleIndices.isNotEmpty
                                ? _5050VisibleIndices
                                : null,
                            correctAnimationController: _correctAnimationController,
                            wrongAnimationController: _wrongAnimationController,
                            selectedForFeedback: _selectedAnswerForFeedback,
                            isCorrectFeedback: _isAnswerCorrect,
                          ),
                        ),
                      ),
                  
                  // Lifelines
                  _buildLifelinesRow(lang),
                  
                  // Skip button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSkipButton(lang),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isPaused) _buildPauseOverlay(lang),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildPauseOverlay(String lang) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _isDark ? const Color(0xFF1E1E2F) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pause_circle_filled_rounded,
                  color: AppColors.primary,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isBn ? 'কুইজ বিরতি দেওয়া হয়েছে' : isHi ? 'क्विज़ रोक दिया गया है' : 'Quiz Paused',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isBn
                    ? 'একটু বিশ্রাম নিন। আপনি প্রস্তুত হলে আবার শুরু করুন।'
                    : isHi
                        ? 'थोड़ा आराम करें। जब आप तैयार हों, तब जारी रखें।'
                        : 'Take a breath. Press resume when you are ready to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _togglePause,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    isBn ? 'কুইজ পুনরায় শুরু করুন' : isHi ? 'क्विज़ जारी रखें' : 'Resume Quiz',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBar(QuizSessionState session, String lang) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Exit button
              GestureDetector(
                onTap: () => _showExitDialog(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(AppIcons.close, color: AppColors.error, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              // Pause button
              GestureDetector(
                onTap: _togglePause,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.pause_rounded, color: AppColors.primary, size: 20),
                ),
              ),
              const SizedBox(width: 16),
              // Stepper
              Expanded(
                child: QuizProgressStepper(
                  current: session.currentIndex + 1,
                  total: session.quiz.questionCount,
                  lang: lang,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Timer bar
          QuizTimerBar(
            animation: _timerController,
            remainingSeconds: session.remainingSeconds,
          ),
        ],
      ),
    );
  }

  Widget _buildLifelinesRow(String lang) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 50:50 Lifeline
          _lifelineButton(
            icon: AppIcons.halfHalf,
            label: '50:50',
            used: _lifeline5050Used,
            onTap: () {
              final indices = get5050Indices();
              if (indices.isNotEmpty && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isBn
                        ? '২টি ভুল উত্তর সরানো হয়েছে!'
                        : isHi
                            ? '2 गलत उत्तर हटाए गए!'
                            : '2 wrong options removed!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 16),
          // +15s Extra Time Lifeline
          _lifelineButton(
            icon: Icons.add_alarm_rounded,
            label: isBn
                ? '+15সে'
                : isHi
                    ? '+15से'
                    : '+15s',
            used: _lifelineExtraTimeUsed,
            onTap: () {
              useExtraTime();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isBn
                      ? '15 সেকেন্ড যোগ করা হয়েছে!'
                      : isHi
                          ? '15 सेकंड जोड़े गए!'
                      : '15 seconds added!'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _lifelineButton({
    required IconData icon,
    required String label,
    required bool used,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: used ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: used ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: used
                ? (_isDark ? Colors.grey.shade800 : Colors.grey.shade300)
                : AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: used
                  ? Colors.grey
                  : AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: used ? Colors.grey : AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: used ? Colors.grey : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton(String lang) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    return AnimatedScaleButton(
      onTap: () {
        _timer?.cancel();
        ref.read(quizSessionProvider.notifier).nextQuestion();
        _onQuestionAdvanced();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              AppIcons.skip,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              isBn
                  ? 'এড়িয়ে যান'
                  : isHi
                      ? 'छोड़ें'
                      : 'Skip',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundDecorations() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.08),
                      AppColors.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -120,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.secondary.withValues(alpha: 0.06),
                      AppColors.secondary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    final nav = Navigator.of(context);
    final lang = ref.read(languageProvider);
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _isDark ? AppColors.cardDark : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.exit_to_app_rounded,
                  color: AppColors.warning, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              isBn
                  ? 'পরীক্ষা ছেড়ে যান?'
                  : isHi
                      ? 'परीक्षा छोड़ें?'
                      : 'Exit Quiz?',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _isDark ? Colors.white : null,
              ),
            ),
          ],
        ),
        content: Text(
          isBn
              ? 'এই কুইজে আপনার অগ্রগতি হারাবে।'
              : isHi
                  ? 'इस क्विज पर आपकी प्रगति खो जाएगी।'
                  : 'Your progress on this quiz will be lost.',
          style: TextStyle(
            color: _isDark ? Colors.white70 : Colors.grey.shade600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(isBn ? 'চালিয়ে যান' : isHi ? 'जारी रखें' : 'Continue'),
          ),
          ElevatedButton(
            onPressed: () {
              _timer?.cancel();
              _answerDelayTimer?.cancel();
              ref.read(quizSessionProvider.notifier).reset();
              Navigator.of(dialogContext).pop();
              if (nav.mounted) nav.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(isBn ? 'প্রস্থান' : isHi ? 'बाहर निकलें' : 'Exit'),
          ),
        ],
      ),
    );
  }
}
