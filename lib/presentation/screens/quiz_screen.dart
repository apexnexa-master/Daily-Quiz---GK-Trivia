// lib/presentation/screens/quiz_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../../data/models/firestore_models.dart';
import '../../core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: AppConstants.questionTimerSeconds),
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

  List<int> get _5050WrongOptions {
    final session = ref.read(quizSessionProvider);
    if (session == null) return [];
    final question = session.quiz.questions[session.currentIndex];
    final correct = question.correctIndex;
    final allOptions =
        List.generate(question.getOptions(_currentLang).length, (i) => i);
    allOptions.remove(correct);
    allOptions.shuffle();
    return allOptions.take(2).toList();
  }

  List<int> get5050Indices() {
    if (_lifeline5050Used) return [];
    final session = ref.read(quizSessionProvider);
    if (session == null) return [];
    final question = session.quiz.questions[session.currentIndex];
    final correct = question.correctIndex;
    final totalOptions = question.getOptions(_currentLang).length;

    // Can't do 50:50 with less than 4 options
    if (totalOptions < 4) return [];

    // Get all wrong option indices
    final allWrong = List.generate(totalOptions, (i) => i)..remove(correct);
    allWrong.shuffle();

    // Remove 2 wrong options, show 2 options (correct + 1 wrong)
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
    _timer?.cancel();
    _timerController.value = 1.0;
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
            backgroundColor: AppTheme.errorColor,
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
        backgroundColor: _isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline,
                    size: 48, color: AppTheme.errorColor),
              ),
              const SizedBox(height: 16),
              Text('No quiz loaded. Please go back and try again.',
                  style: TextStyle(
                      color: _isDark ? Colors.white70 : Colors.grey.shade600)),
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
        backgroundColor: _isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                lang == 'bn'
                    ? 'ফলাফল লোড হচ্ছে...'
                    : lang == 'hi'
                        ? 'परिणाम लोड हो रहा है...'
                        : 'Loading results...',
                style: TextStyle(
                    color: _isDark ? Colors.white70 : Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    final question = session.quiz.questions[session.currentIndex];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _showExitDialog(context);
      },
      child: Scaffold(
        backgroundColor: _isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        body: Stack(
          children: [
            _buildBackgroundDecorations(_isDark),
            SafeArea(
              child: Column(
                children: [
                  _QuizHeader(
                    current: session.currentIndex + 1,
                    total: session.quiz.questionCount,
                    timerAnimation: _timerController,
                    pulseAnimation: _pulseController,
                    remainingSeconds: session.remainingSeconds,
                    onExit: () => _showExitDialog(context),
                    isDark: _isDark,
                    lang: lang,
                  ),
                  Expanded(
                    child: FadeTransition(
                      opacity: _questionFadeController,
                      child: _QuestionCard(
                        question: question,
                        lang: lang,
                        selectedAnswer:
                            session.selectedAnswers[session.currentIndex],
                        onAnswerSelected: (i) =>
                            _onAnswerSelected(session.currentIndex, i),
                        isDark: _isDark,
                        visibleOptions:
                            _lifeline5050Used && _5050VisibleIndices.isNotEmpty
                                ? _5050VisibleIndices
                                : null,
                        correctAnimationController: _correctAnimationController,
                        wrongAnimationController: _wrongAnimationController,
                        selectedForFeedback: _selectedAnswerForFeedback,
                        isCorrectFeedback: _isAnswerCorrect,
                      ),
                    ),
                  ),
                  _buildLifelinesRow(lang, _isDark),
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
          ],
        ),
      ),
    );
  }

  Widget _buildLifelinesRow(String lang, bool isDark) {
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _lifelineButton(
            icon: Icons.filter_5,
            label: isBn
                ? '50:50'
                : isHi
                    ? '50:50'
                    : '50:50',
            used: _lifeline5050Used,
            onTap: () {
              final indices = get5050Indices();
              if (indices.isNotEmpty && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isBn
                        ? '2টি ভুল উত্তর সরানো হয়েছে!'
                        : isHi
                            ? '2 गलत उत्तर हटाए गए!'
                            : '2 wrong options removed!'),
                    backgroundColor: AppTheme.successColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            isDark: isDark,
          ),
          const SizedBox(width: 16),
          _lifelineButton(
            icon: Icons.timer,
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
                  backgroundColor: AppTheme.successColor,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            isDark: isDark,
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
    required bool isDark,
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
                ? (isDark ? Colors.grey.shade800 : Colors.grey.shade300)
                : AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: used
                  ? Colors.grey
                  : AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18, color: used ? Colors.grey : AppTheme.primaryColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: used ? Colors.grey : AppTheme.primaryColor,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _timer?.cancel();
          ref.read(quizSessionProvider.notifier).nextQuestion();
          _onQuestionAdvanced();
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.skip_next_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isBn
                    ? 'এড়িয়ে যান'
                    : isHi
                        ? 'छोड़ें'
                        : 'Skip',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundDecorations(bool isDark) {
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
                      AppTheme.primaryColor.withValues(alpha: 0.08),
                      AppTheme.primaryColor.withValues(alpha: 0.0),
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
                      AppTheme.secondaryColor.withValues(alpha: 0.06),
                      AppTheme.secondaryColor.withValues(alpha: 0.0),
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
        backgroundColor: _isDark ? AppTheme.cardDark : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.exit_to_app_rounded,
                  color: AppTheme.warningColor, size: 20),
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
                  ? 'इस क्विज पर आপনার প্রগতি खो जाएगी।'
                  : 'Your progress on this quiz will be lost.',
          style: TextStyle(
            color: _isDark ? Colors.white70 : Colors.grey.shade600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(isBn
                ? 'চালিয়ে যান'
                : isHi
                    ? 'जारी रखें'
                    : 'Continue'),
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
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: Text(isBn
                ? 'প্রস্থান'
                : isHi
                    ? 'बाहर निकलें'
                    : 'Exit'),
          ),
        ],
      ),
    );
  }
}

// ── Quiz Header ───────────────────────────────────────────────
class _QuizHeader extends StatelessWidget {
  final int current;
  final int total;
  final AnimationController timerAnimation;
  final AnimationController pulseAnimation;
  final int remainingSeconds;
  final VoidCallback onExit;
  final bool isDark;
  final String lang;

  const _QuizHeader({
    required this.current,
    required this.total,
    required this.timerAnimation,
    required this.pulseAnimation,
    required this.remainingSeconds,
    required this.onExit,
    required this.isDark,
    required this.lang,
  });

  Color _timerColor(int s) {
    if (s > 20) return AppTheme.successColor;
    if (s > 10) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  @override
  Widget build(BuildContext context) {
    final progress = current / total;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        gradient:
            isDark ? AppTheme.primaryGradientDark : AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onExit,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBn
                            ? 'প্রশ্ন $current এর $total'
                            : isHi
                                ? 'प्रश्न $current का $total'
                                : 'Question $current of $total',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 6,
                            width: MediaQuery.of(context).size.width *
                                progress *
                                0.45,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                AnimatedBuilder(
                  animation: pulseAnimation,
                  builder: (_, __) {
                    final scale = 1.0 +
                        (remainingSeconds <= 5
                            ? 0.05 * pulseAnimation.value
                            : 0.0);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: CircularProgressIndicator(
                                value: timerAnimation.value,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.2),
                                valueColor: AlwaysStoppedAnimation(
                                    _timerColor(remainingSeconds)),
                                strokeWidth: 3,
                              ),
                            ),
                            Text(
                              '$remainingSeconds',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: _timerColor(remainingSeconds),
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatefulWidget {
  final QuestionModel question;
  final String lang;
  final int? selectedAnswer;
  final ValueChanged<int> onAnswerSelected;
  final bool isDark;
  final Set<int>? visibleOptions;
  final AnimationController? correctAnimationController;
  final AnimationController? wrongAnimationController;
  final int? selectedForFeedback;
  final bool? isCorrectFeedback;

  const _QuestionCard({
    required this.question,
    required this.lang,
    required this.selectedAnswer,
    required this.onAnswerSelected,
    required this.isDark,
    this.visibleOptions,
    this.correctAnimationController,
    this.wrongAnimationController,
    this.selectedForFeedback,
    this.isCorrectFeedback,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  @override
  Widget build(BuildContext context) {
    final questionText = widget.question.getText(widget.lang);
    final options = widget.question.getOptions(widget.lang);
    final isBengali = widget.lang == 'bn';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: BoxDecoration(
              gradient: widget.isDark
                  ? LinearGradient(
                      colors: [
                        AppTheme.cardDark,
                        AppTheme.surfaceElevatedDark.withValues(alpha: 0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white,
                        const Color(0xFFF8FAFC),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (widget.isDark ? Colors.black : AppTheme.primaryColor)
                      .withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.question.category.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _difficultyColor(widget.question.difficulty)
                            .withValues(alpha: widget.isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _difficultyColor(widget.question.difficulty)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        widget.question.difficulty.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _difficultyColor(widget.question.difficulty),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  questionText,
                  style: isBengali
                      ? AppTheme.bengaliStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)
                      : Theme.of(context).textTheme.titleLarge?.copyWith(
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...options.asMap().entries.map((entry) {
            final i = entry.key;
            if (widget.visibleOptions != null &&
                !widget.visibleOptions!.contains(i)) {
              return const SizedBox.shrink();
            }
            final text = entry.value;
            final isSelected = widget.selectedAnswer == i;
            return _OptionTile(
              index: i,
              text: text,
              isSelected: isSelected,
              isBengali: isBengali,
              isDark: widget.isDark,
              onTap: widget.selectedAnswer == null
                  ? () => widget.onAnswerSelected(i)
                  : null,
              isCorrectFeedback: widget.selectedForFeedback == i
                  ? widget.isCorrectFeedback
                  : null,
              correctAnimation: widget.correctAnimationController,
              wrongAnimation: widget.wrongAnimationController,
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Color _difficultyColor(String d) {
    switch (d) {
      case 'easy':
        return AppTheme.successColor;
      case 'hard':
        return AppTheme.errorColor;
      default:
        return AppTheme.warningColor;
    }
  }
}

class _OptionTile extends StatelessWidget {
  final int index;
  final String text;
  final bool isSelected;
  final bool isBengali;
  final bool isDark;
  final VoidCallback? onTap;
  final bool? isCorrectFeedback;
  final AnimationController? correctAnimation;
  final AnimationController? wrongAnimation;

  const _OptionTile({
    required this.index,
    required this.text,
    required this.isSelected,
    required this.isBengali,
    required this.isDark,
    this.onTap,
    this.isCorrectFeedback,
    this.correctAnimation,
    this.wrongAnimation,
  });

  static const _labels = ['A', 'B', 'C', 'D'];
  static const _colors = [
    Color(0xFF6366F1),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];

  Color get _optionColor => _colors[index];

  @override
  Widget build(BuildContext context) {
    Widget container = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    _optionColor,
                    _optionColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color:
              isSelected ? null : (isDark ? AppTheme.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.withValues(alpha: 0.15)),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _optionColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.3),
                          Colors.white.withValues(alpha: 0.1),
                        ],
                      )
                    : null,
                color: isSelected
                    ? null
                    : (isDark
                        ? AppTheme.surfaceElevatedDark
                        : const Color(0xFFF1F5F9)),
                border: Border.all(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.5)
                      : _optionColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _labels[index],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : _optionColor,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: isBengali
                    ? AppTheme.bengaliStyle(
                        fontSize: 15,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white : null))
                    : Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white : null),
                          fontWeight: FontWeight.w500,
                        ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded,
                  color: Colors.white.withValues(alpha: 0.9), size: 22),
          ],
        ),
      ),
    );

    if (isCorrectFeedback != null &&
        (correctAnimation != null || wrongAnimation != null)) {
      if (isCorrectFeedback == true && correctAnimation != null) {
        return AnimatedBuilder(
          animation: correctAnimation!,
          builder: (context, child) {
            final value = Curves.elasticOut.transform(correctAnimation!.value);
            return Transform.scale(
              scale: 1.0 + (0.2 * value),
              child: child,
            );
          },
          child: container,
        );
      } else if (isCorrectFeedback == false && wrongAnimation != null) {
        return AnimatedBuilder(
          animation: wrongAnimation!,
          builder: (context, child) {
            final value = Curves.elasticOut.transform(wrongAnimation!.value);
            final shake = 10.0 *
                (1 - value) *
                (wrongAnimation!.value < 0.5
                    ? (wrongAnimation!.value * 4).floor() % 2 == 0
                        ? 1
                        : -1
                    : -((wrongAnimation!.value * 4).floor() % 2 == 0 ? 1 : -1));
            return Transform.translate(
              offset: Offset(shake * (1 - value), 0),
              child: child,
            );
          },
          child: container,
        );
      }
    }

    return container;
  }
}
