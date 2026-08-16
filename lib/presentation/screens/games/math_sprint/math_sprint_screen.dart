// lib/presentation/screens/games/math_sprint/math_sprint_screen.dart
// MATH SPEED SPRINT — a 60-second mental-arithmetic game.
//
// Flow: INTRO → COUNTDOWN → RUN (60s) → RESULTS.
// The run state machine lives in [MathSprintEngine] (pure Dart, unit-tested);
// this screen only renders it and provides timing + game feel (sound, haptics,
// fast feedback, no dead input locks).
//
// Visual language: neon-glass. An animated aurora backdrop, gradient-ring
// problem card, per-tile accent answer buttons and a glowing HUD. All visual
// animations are opacity/transform based (GPU friendly) — no full-screen blurs.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/daily_progress_service.dart';
import '../../../../core/services/game_sfx.dart';
import '../../../../core/theme/app_animations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../games/widgets/countdown_overlay.dart';
import '../../../games/widgets/game_results_panel.dart';
import '../../../games/widgets/game_scaffold.dart';
import '../../../games/widgets/game_top_bar.dart';
import '../../../providers/app_providers.dart';
import '../../../workout/workout_models.dart';
import '../../../workout/workout_progress_banner.dart';
import 'math_sprint_engine.dart';

const String _bestScoreKey = 'math_sprint_best';

enum _Phase { intro, playing, finished }

class MathSprintScreen extends ConsumerStatefulWidget {
  const MathSprintScreen({super.key});

  @override
  ConsumerState<MathSprintScreen> createState() => _MathSprintScreenState();
}

class _MathSprintScreenState extends ConsumerState<MathSprintScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final MathSprintEngine _engine = MathSprintEngine();

  /// Accent hue for each of the four answer tiles (cyan, violet, lime, pink).
  static const List<Color> _tileAccents = [
    Color(0xFF00F1FE),
    Color(0xFFA78BFA),
    Color(0xFFD4FF50),
    Color(0xFFFF5FA8),
  ];

  static const LinearGradient _scoreGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD4FF50), Color(0xFF00F1FE)],
  );

  _Phase _phase = _Phase.intro;
  bool _showCountdown = false;
  bool _paused = false;
  bool _answering = false;
  bool _isNewBest = false;

  /// Bumped on every start/replay so stale async callbacks from an earlier
  /// run (answer feedback, problem timers) can never touch a newer run.
  int _runId = 0;

  AnswerOutcome? _feedback;
  int _lastTappedIndex = -1;
  bool _showLevelBanner = false;
  int _remainingSeconds = 0;
  int _best = 0;
  int _workoutScore = 0;

  late final AnimationController _runTimer;
  late final AnimationController _shake;
  late final AnimationController _problemPop;
  late final AnimationController _levelBanner;
  late final AnimationController _introSpin;
  late final AnimationController _problemRing;

  Timer? _clockTimer;
  Timer? _problemTimer;
  final Stopwatch _problemWatch = Stopwatch();

  final List<_FloatingScore> _floaters = [];
  WorkoutStep? _workoutStep;

  bool get _isBn => _lang == 'bn';
  bool get _isHi => _lang == 'hi';
  String get _lang => ref.read(languageProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runTimer = AnimationController(
      vsync: this,
      duration: Duration(seconds: _engine.runSeconds),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finishRun();
      });
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _problemPop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _levelBanner = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _problemRing = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _introSpin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _loadBest();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final step = args?['workoutStep'];
    if (step is WorkoutStep && _workoutStep == null) {
      _workoutStep = step;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _problemTimer?.cancel();
    _runTimer.dispose();
    _shake.dispose();
    _problemPop.dispose();
    _levelBanner.dispose();
    _introSpin.dispose();
    _problemRing.dispose();
    for (final floater in _floaters) {
      floater.controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_phase == _Phase.playing && !_paused && !_answering) {
        _pauseRun();
      }
    }
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _best = prefs.getInt(_bestScoreKey) ?? 0);
  }

  String _t(String en, String bn, String hi) => _isBn
      ? bn
      : _isHi
          ? hi
          : en;

  // ── Flow control ──────────────────────────────────────────────────────

  void _startPressed() {
    GameSfxService.instance.play(GameSfx.tap);
    setState(() => _showCountdown = true);
  }

  void _beginRun() {
    if (_phase == _Phase.playing) return;
    _runId++;
    setState(() {
      _showCountdown = false;
      _phase = _Phase.playing;
      _remainingSeconds = _engine.runSeconds;
      _answering = false;
      _lastTappedIndex = -1;
      _feedback = null;
    });
    _engine.next();
    _problemPop.forward(from: 0);
    _runTimer.forward(from: 0);
    _startProblemClock();
    _startClock();
  }

  void _startProblemClock() {
    if (_phase != _Phase.playing || _paused) return;
    _problemTimer?.cancel();
    _problemWatch
      ..reset()
      ..start();
    final budget = _engine.currentTimeBudgetSeconds;
    _problemRing
      ..duration = Duration(milliseconds: (budget * 1000).round())
      ..forward(from: 0);
    _problemTimer = Timer(
        Duration(milliseconds: (budget * 1000).round()), _onProblemTimeout);
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _phase != _Phase.playing || _paused) return;
      final remaining = _remainingSeconds - 1;
      if (remaining == 3 || remaining == 2 || remaining == 1) {
        GameSfxService.instance.play(GameSfx.countdown);
      }
      setState(() => _remainingSeconds = remaining);
      if (remaining <= 0) {
        timer.cancel();
        _finishRun();
      }
    });
  }

  void _onOptionTap(int index) {
    if (_phase != _Phase.playing || _answering || _paused) return;
    _answering = true;
    _problemTimer?.cancel();
    _problemRing.stop();
    final budget = _engine.currentTimeBudgetSeconds;
    final elapsed = _problemWatch.elapsedMilliseconds / (budget * 1000);
    final outcome = _engine.submitAnswer(index, elapsedFraction: elapsed);
    _handleOutcome(outcome, index: index);
  }

  void _onProblemTimeout() {
    if (_phase != _Phase.playing || _answering || _paused) return;
    _answering = true;
    _problemRing.stop();
    final outcome = _engine.submitTimeout();
    _handleOutcome(outcome, index: -1);
  }

  void _handleOutcome(AnswerOutcome outcome, {required int index}) {
    if (outcome.correct) {
      GameSfxService.instance
          .play(outcome.comboMultiplier > 1 ? GameSfx.combo : GameSfx.correct);
      HapticFeedback.lightImpact();
      _spawnFloater(
        '+${outcome.points}',
        outcome.comboMultiplier > 1
            ? const Color(0xFFFBBF24)
            : AppColors.success,
      );
    } else {
      GameSfxService.instance.play(GameSfx.wrong);
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
    }
    if (outcome.leveledUp) {
      GameSfxService.instance.play(GameSfx.levelUp);
      setState(() => _showLevelBanner = true);
      Future<void>.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) setState(() => _showLevelBanner = false);
      });
    }

    setState(() {
      _feedback = outcome;
      _lastTappedIndex = index;
    });

    final delay = outcome.correct
        ? const Duration(milliseconds: 240)
        : const Duration(milliseconds: 360);
    final runId = _runId;
    Future<void>.delayed(delay, () {
      if (!mounted || runId != _runId) return;
      setState(() => _feedback = null);
      if (outcome.gameOver) {
        _finishRun();
        return;
      }
      if (_phase == _Phase.playing) _advance();
    });
  }

  void _advance() {
    if (_phase != _Phase.playing) return;
    _answering = false;
    _problemPop.forward(from: 0);
    _engine.next();
    setState(() {});
    _startProblemClock();
  }

  void _pauseRun() {
    _runTimer.stop();
    _clockTimer?.cancel();
    _problemTimer?.cancel();
    _problemWatch.stop();
    _problemRing.stop();
    setState(() => _paused = true);
  }

  void _resumeRun() {
    GameSfxService.instance.play(GameSfx.tap);
    setState(() => _paused = false);
    _runTimer.forward(from: _runTimer.value);
    _startClock();
    _problemTimer?.cancel();
    final budget = _engine.currentTimeBudgetSeconds * 1000;
    final remaining = budget - _problemWatch.elapsedMilliseconds;
    _problemWatch.start();
    _problemRing
      ..duration = Duration(milliseconds: remaining.clamp(50, budget).round())
      ..forward(from: 0);
    _problemTimer = Timer(
      Duration(milliseconds: remaining.clamp(50, budget).round()),
      _onProblemTimeout,
    );
  }

  void _finishRun() {
    if (_phase != _Phase.playing) return;
    _clockTimer?.cancel();
    _problemTimer?.cancel();
    _problemWatch.stop();
    _runTimer.stop();
    _problemRing.stop();

    final isNewBest = _engine.score > _best;
    if (isNewBest) {
      _best = _engine.score;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt(_bestScoreKey, _engine.score);
      });
    }

    GameSfxService.instance.play(GameSfx.gameOver);
    _workoutScore = _engine.accuracy;
    DailyProgressService.instance.recordGameCompletion(
      pillar: BrainPillar.speed,
      scorePct: _workoutScore,
      gameType: GameType.math,
    );
    try {
      ProviderScope.containerOf(context, listen: false)
          .invalidate(dailyProgressProvider);
    } catch (_) {}

    setState(() {
      _phase = _Phase.finished;
      _isNewBest = isNewBest;
    });
  }

  void _playAgain() {
    GameSfxService.instance.play(GameSfx.tap);
    _runId++;
    _engine.reset();
    _clockTimer?.cancel();
    _problemTimer?.cancel();
    _problemWatch.stop();
    _problemRing.stop();
    _runTimer.stop();
    _runTimer.value = 0;
    setState(() {
      _feedback = null;
      _lastTappedIndex = -1;
      _answering = false;
      _showLevelBanner = false;
      _isNewBest = false;
      _showCountdown = true;
    });
  }

  Future<void> _shareScore() async {
    final text = '''
🧠 **Math Sprint**

🔥 I scored **${_engine.score}** points in 60 seconds!
⚡ Level: ${_engine.level} | Accuracy: ${_engine.accuracy}%
🎯 Best streak: ${_engine.bestStreak}

Can you beat me? 🚀
''';
    try {
      await Share.share(text, subject: 'My Math Sprint Score!');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_t('Sharing is not available right now.',
                'এখন শেয়ার করা যাচ্ছে না।', 'अभी साझा करना संभव नहीं है।'))),
      );
    }
  }

  void _exitGame() {
    if (_workoutStep != null) {
      Navigator.pop(context, _workoutScore);
    } else {
      Navigator.pop(context);
    }
  }

  void _spawnFloater(String text, Color color) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    final floater = _FloatingScore(controller, text, color);
    setState(() => _floaters.add(floater));
    controller.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _floaters.remove(floater));
      controller.dispose();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GameScaffold(
      child: Stack(
        children: [
          const _AuroraBackground(),
          Column(
            children: [
              GameTopBar(
                title: _t('MATH SPRINT', 'ম্যাথ স্প্রিন্ট', 'मैथ स्प्रिंट'),
                subtitle: _t('Crunch numbers. Beat the clock.',
                    'দ্রুত গণিত সমাধান করুন।', 'तेज़ गति से गणित हल करें।'),
                trailing: _buildLivesIndicator(isDark),
              ),
              if (_workoutStep != null)
                WorkoutProgressBanner(step: _workoutStep!),
              _buildScoreRow(isDark),
              _buildTimerBar(isDark),
              Expanded(child: _buildProblemArea(isDark)),
              _buildAnswerArea(isDark),
              const SizedBox(height: 20),
            ],
          ),
          _buildFloaters(),
          if (_showLevelBanner) _buildLevelBanner(isDark),
          if (_phase == _Phase.intro) _buildIntro(isDark),
          if (_phase == _Phase.finished) _buildResults(isDark),
          if (_paused) _buildPauseOverlay(isDark),
          if (_showCountdown)
            CountdownOverlay(
              onFinished: _beginRun,
              goLabel: _t('GO!', 'শুরু!', 'शुरू!'),
            ),
        ],
      ),
    );
  }

  // ── HUD ───────────────────────────────────────────────────────────────

  Widget _buildLivesIndicator(bool isDark) {
    final dim = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: _glass(isDark, const Color(0xFFFF4D6D)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < MathSprintEngine.maxLives; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: AnimatedScale(
                scale: i < _engine.lives ? 1 : 0.82,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Icon(
                  Icons.favorite_rounded,
                  size: 15,
                  color: i < _engine.lives ? const Color(0xFFFF4D6D) : dim,
                  shadows: i < _engine.lives
                      ? const [
                          Shadow(
                            color: Color(0x99FF4D6D),
                            blurRadius: 9,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
      child: Row(
        children: [
          _buildLevelChip(isDark),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) {
                  final scale = Tween<double>(begin: 1.18, end: 1.0).animate(
                    CurvedAnimation(
                        parent: animation, curve: Curves.easeOutBack),
                  );
                  return ScaleTransition(
                    scale: scale,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: ShaderMask(
                  key: ValueKey('score-${_engine.score}'),
                  shaderCallback: (bounds) =>
                      _scoreGradient.createShader(bounds),
                  child: Text(
                    '${_engine.score}',
                    style: GoogleFonts.montserrat(
                      fontSize: 42,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          color: Color(0x66D4FF50),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _t('SCORE', 'স্কোর', 'स्कोर'),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
            ],
          ),
          const Spacer(),
          _buildStreakChip(isDark),
        ],
      ),
    );
  }

  Widget _buildLevelChip(bool isDark) {
    final progress = _engine.totalCorrect % 5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: _glass(isDark, AppColors.level),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stairs_rounded,
                  size: 13, color: AppColors.level),
              const SizedBox(width: 4),
              Text(
                '${_t('LVL', 'স্তর', 'স্তর')} ${_engine.level}',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: i < progress
                          ? AppColors.level
                          : (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakChip(bool isDark) {
    final combo = _engine.streak >= 4
        ? MathSprintEngine.comboMultiplierFor(_engine.streak)
        : 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: _glass(isDark, AppColors.streak),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 14,
            color: AppColors.streak,
            shadows: [
              Shadow(color: Color(0x99F97316), blurRadius: 8),
            ],
          ),
          const SizedBox(width: 4),
          Text(
            '${_engine.streak}',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          if (combo > 1) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.streak.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'x$combo',
                style: GoogleFonts.montserrat(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: AppColors.streak,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimerBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
      child: AnimatedBuilder(
        animation: _runTimer,
        builder: (context, _) {
          final remaining = (1 - _runTimer.value).clamp(0.0, 1.0);
          final color = remaining > 0.5
              ? AppColors.success
              : remaining > 0.25
                  ? AppColors.warning
                  : AppColors.error;

          return ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.08),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: constraints.maxWidth * remaining,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [color, color.withValues(alpha: 0.45)],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Problem + answers ────────────────────────────────────────────────

  Widget _buildProblemArea(bool isDark) {
    final problem = _engine.currentProblem;
    final exprGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD4FF50), Color(0xFF00F1FE)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3F6212), Color(0xFF0E7490)],
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _problemPop,
            builder: (context, child) {
              final scale = Tween<double>(begin: 0.92, end: 1.0).animate(
                CurvedAnimation(parent: _problemPop, curve: Curves.easeOutBack),
              );
              return ScaleTransition(scale: scale, child: child);
            },
            child: AnimatedBuilder(
              animation: _problemRing,
              builder: (context, _) {
                final elapsedMs =
                    _problemRing.lastElapsedDuration?.inMilliseconds ?? 0;
                final remaining = (1 - _problemRing.value).clamp(0.0, 1.0);
                final inDanger = remaining <= 0.25;
                final pulse =
                    inDanger ? 0.5 + 0.5 * sin(elapsedMs / 180 * pi) : 0.0;
                final glow = inDanger
                    ? const Color(0xFFFF4D6D)
                        .withValues(alpha: 0.25 + 0.5 * pulse)
                    : AppColors.primary.withValues(alpha: 0.30);
                return Transform.scale(
                  scale: 1 + 0.012 * pulse,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _GradientRingCard(
                        key: ValueKey('problem-${_engine.totalAttempts}'),
                        radius: AppSpacing.rXxl,
                        ringColors: const [
                          Color(0xFF00F1FE),
                          Color(0xFF8B5CF6),
                          Color(0xFFFF5FA8)
                        ],
                        glow: glow,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 26),
                        child: Column(
                          children: [
                            if (problem != null)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: ShaderMask(
                                  shaderCallback: (bounds) =>
                                      exprGradient.createShader(bounds),
                                  child: Text(
                                    problem.expression,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 62,
                                      height: 1.1,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 2),
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  exprGradient.createShader(bounds),
                              child: Text(
                                '= ?',
                                style: GoogleFonts.montserrat(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: -16,
                        right: -8,
                        child: _ProblemTimerRing(
                          controller: _problemRing,
                          budgetSeconds: _engine.currentTimeBudgetSeconds,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 13,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
              const SizedBox(width: 4),
              Text(
                _t('Tap the correct answer', 'সঠিক উত্তর ট্যাপ করুন',
                    'सही उत्तर पर टैप करें'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerArea(bool isDark) {
    final problem = _engine.currentProblem;
    final enabled = _phase == _Phase.playing && !_answering && !_paused;
    if (problem == null) return const SizedBox.shrink();

    final correctIndex = problem.options.indexWhere((o) => o == problem.answer);

    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx = t <= 0 ? 0.0 : sin(t * pi * 10) * 12 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(
          children: [
            for (var row = 0; row < 2; row++) ...[
              if (row > 0) const SizedBox(height: 12),
              Row(
                children: [
                  for (var col = 0; col < 2; col++) ...[
                    if (col > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _buildOptionButton(
                        index: row * 2 + col,
                        value: problem.options[row * 2 + col],
                        accent: _tileAccents[row * 2 + col],
                        isDark: isDark,
                        enabled: enabled,
                        isCorrect:
                            _feedback != null && row * 2 + col == correctIndex,
                        isTapped: _feedback != null &&
                            row * 2 + col == _lastTappedIndex &&
                            !_feedback!.correct,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required int index,
    required int value,
    required Color accent,
    required bool isDark,
    required bool enabled,
    required bool isCorrect,
    required bool isTapped,
  }) {
    final Color borderColor;
    final List<Color> bgGradient;
    final Color numberColor;
    final Color glowColor;
    final double glowBlur;
    var opacity = 1.0;

    if (_feedback != null) {
      if (isCorrect) {
        borderColor = AppColors.successLight;
        bgGradient = const [Color(0xFF10B981), Color(0xFF059669)];
        numberColor = Colors.white;
        glowColor = AppColors.success;
        glowBlur = 22;
      } else if (isTapped) {
        borderColor = AppColors.errorLight;
        bgGradient = const [Color(0xFFEF4444), Color(0xFFB91C1C)];
        numberColor = Colors.white;
        glowColor = AppColors.error;
        glowBlur = 22;
      } else {
        borderColor =
            (isDark ? Colors.white : Colors.black).withValues(alpha: 0.07);
        bgGradient = isDark
            ? [
                Colors.white.withValues(alpha: 0.03),
                Colors.white.withValues(alpha: 0.015)
              ]
            : [
                Colors.white.withValues(alpha: 0.5),
                Colors.white.withValues(alpha: 0.3)
              ];
        numberColor = accent.withValues(alpha: 0.35);
        glowColor = Colors.transparent;
        glowBlur = 0;
        opacity = 0.35;
      }
    } else {
      borderColor = accent.withValues(alpha: isDark ? 0.55 : 0.45);
      bgGradient = [
        accent.withValues(alpha: isDark ? 0.14 : 0.10),
        accent.withValues(alpha: isDark ? 0.05 : 0.04),
      ];
      numberColor = isDark ? Colors.white : AppColors.textPrimaryLight;
      glowColor = accent;
      glowBlur = 14;
    }

    final button = Opacity(
      opacity: opacity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 88,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bgGradient,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.rLg),
          border: Border.all(
            color: borderColor,
            width: isCorrect || isTapped ? 2.2 : 1.4,
          ),
          boxShadow: glowBlur > 0
              ? [
                  BoxShadow(
                    color: glowColor.withValues(
                        alpha: isCorrect || isTapped ? 0.45 : 0.30),
                    blurRadius: glowBlur,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 0,
              left: 10,
              right: 10,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.22),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Text(
              '$value',
              style: GoogleFonts.montserrat(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: numberColor,
                shadows: glowBlur > 0 && !isCorrect && !isTapped
                    ? [
                        Shadow(
                          color: glowColor.withValues(alpha: 0.45),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );

    return AnimatedScaleButton(
      onTap: enabled ? () => _onOptionTap(index) : null,
      child: button,
    );
  }

  // ── Overlays ──────────────────────────────────────────────────────────

  Widget _buildIntro(bool isDark) {
    return Positioned.fill(
      child: Material(
        color: (isDark ? const Color(0xFF05080E) : Colors.white)
            .withValues(alpha: isDark ? 0.95 : 0.97),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeroOrb(),
                  AppSpacing.vXxl,
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        _scoreGradient.createShader(bounds),
                    child: Text(
                      _t('MATH SPRINT', 'ম্যাথ স্প্রিন্ট', 'मैथ स्प्रिंट'),
                      style: GoogleFonts.montserrat(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Color(0x55D4FF50), blurRadius: 26),
                        ],
                      ),
                    ),
                  ),
                  AppSpacing.vSm,
                  Text(
                    _t(
                      'Crunch numbers. Beat the clock.',
                      'দ্রুত গণিত সমাধান করুন।',
                      'तेज़ गति से गणित हल करें।',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  AppSpacing.vXxl,
                  _buildRuleRow(
                    icon: Icons.timer_rounded,
                    color: AppColors.info,
                    text: _t(
                      '60 seconds. 3 lives. Answer fast.',
                      '৬০ সেকেন্ড, ৩টি জীবন। দ্রুত উত্তর দিন।',
                      '60 सेकंड, 3 जीवन। तेज़ी से उत्तर दें।',
                    ),
                    isDark: isDark,
                  ),
                  AppSpacing.vMd,
                  _buildRuleRow(
                    icon: Icons.trending_up_rounded,
                    color: AppColors.success,
                    text: _t(
                      'Every 5 correct answers levels you up.',
                      'প্রতি ৫টি সঠিক উত্তরে লেভেল বাড়ে।',
                      'हर 5 सही उत्तर पर स्तर बढ़ता है।',
                    ),
                    isDark: isDark,
                  ),
                  AppSpacing.vMd,
                  _buildRuleRow(
                    icon: Icons.local_fire_department_rounded,
                    color: AppColors.streak,
                    text: _t(
                      'Combo streaks multiply your points.',
                      'কম্বো স্ট্রিক পয়েন্ট গুণ করে।',
                      'कॉम्बो स्ट्रीक अंक कई गुना बढ़ाते हैं।',
                    ),
                    isDark: isDark,
                  ),
                  if (_best > 0) ...[
                    AppSpacing.vXl,
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: _glass(isDark, AppColors.coin),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events_rounded,
                              size: 14, color: AppColors.coin),
                          const SizedBox(width: 6),
                          Text(
                            _t('Best: $_best', 'সেরা: $_best',
                                'सर्वश्रेष्ठ: $_best'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  AppSpacing.vXxl,
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD4FF50), Color(0xFF00E7A0)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(AppSpacing.rLg),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _startPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.rLg),
                          ),
                        ),
                        child: Text(
                          _t('START', 'শুরু করুন', 'शुरू करें'),
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.vMd,
                  TextButton(
                    onPressed: _exitGame,
                    child: Text(
                      _t('BACK', 'ফিরে যান', 'वापस जाएं'),
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroOrb() {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: 34,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.calculate_rounded,
              size: 50,
              color: Colors.black,
            ),
          ),
          AnimatedBuilder(
            animation: _introSpin,
            builder: (context, _) {
              final angle = _introSpin.value * 2 * pi;
              return Transform.rotate(
                angle: angle,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _orbitSymbol(
                        '+', const Offset(64, 0), const Color(0xFF00F1FE)),
                    _orbitSymbol(
                        '−', const Offset(-64, 0), const Color(0xFFFF5FA8)),
                    _orbitSymbol(
                        '×', const Offset(0, 64), const Color(0xFFD4FF50)),
                    _orbitSymbol(
                        '÷', const Offset(0, -64), const Color(0xFFA78BFA)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _orbitSymbol(String symbol, Offset offset, Color color) {
    return Transform.translate(
      offset: offset,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12),
          ],
        ),
        child: Text(
          symbol,
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildRuleRow({
    required IconData icon,
    required Color color,
    required String text,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.rLg),
        border: Border.all(
          color: color.withValues(alpha: 0.30),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelBanner(bool isDark) {
    return Positioned(
      top: 130,
      left: 0,
      right: 0,
      child: Center(
        child: IgnorePointer(
          child: BounceInWidget(
            duration: const Duration(milliseconds: 500),
            child: _GradientRingCard(
              radius: AppSpacing.rRound,
              ringColors: const [Color(0xFFCF5CFF), Color(0xFF8B5CF6)],
              glow: AppColors.level.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 7),
                  Text(
                    _t('LEVEL ${_engine.level}!', 'স্তর ${_engine.level}!',
                        'स्तर ${_engine.level}!'),
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPauseOverlay(bool isDark) {
    return Positioned.fill(
      child: Material(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.62),
        child: Center(
          child: _GradientRingCard(
            radius: AppSpacing.rXxl,
            ringColors: const [
              Color(0xFF00F1FE),
              Color(0xFF8B5CF6),
              Color(0xFFFF5FA8)
            ],
            glow: const Color(0xFF00F1FE).withValues(alpha: 0.3),
            padding: const EdgeInsets.fromLTRB(32, 30, 32, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.pause_rounded,
                  size: 54,
                  color: (isDark ? Colors.white : Colors.white)
                      .withValues(alpha: 0.92),
                ),
                AppSpacing.vLg,
                Text(
                  _t('PAUSED', 'বিরতি', 'विराम'),
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Colors.white,
                  ),
                ),
                AppSpacing.vXxl,
                SizedBox(
                  width: 190,
                  height: 52,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD4FF50), Color(0xFF00E7A0)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.rLg),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _resumeRun,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.rLg),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow_rounded, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            _t('RESUME', 'চালিয়ে যান', 'जारी रखें'),
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AppSpacing.vMd,
                TextButton(
                  onPressed: () {
                    GameSfxService.instance.play(GameSfx.tap);
                    _exitGame();
                  },
                  child: Text(
                    _t('QUIT', 'প্রস্থান', 'छोड़ें'),
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults(bool isDark) {
    final streakStat = GameResultStat(
      label: _t('BEST STREAK', 'সেরা স্ট্রিক', 'सर्वश्रेष्ठ स्ट्रीक'),
      value: '${_engine.bestStreak}',
      icon: Icons.local_fire_department_rounded,
      color: AppColors.streak,
    );
    final levelStat = GameResultStat(
      label: _t('LEVEL', 'স্তর', 'স্তর'),
      value: '${_engine.level}',
      icon: Icons.stairs_rounded,
      color: AppColors.level,
    );
    final accuracyStat = GameResultStat(
      label: _t('ACCURACY', 'সঠিকতা', 'सटीकता'),
      value: '${_engine.accuracy}%',
      icon: Icons.verified_rounded,
      color: AppColors.success,
    );
    final solvedStat = GameResultStat(
      label: _t('SOLVED', 'সমাধান', 'हल किए'),
      value: '${_engine.totalCorrect}',
      icon: Icons.check_circle_rounded,
      color: AppColors.info,
    );

    return GameResultsPanel(
      title: _t("TIME'S UP!", 'সময় শেষ!', 'समय समाप्त!'),
      subtitle: _t(
        'Math sprint complete.',
        'গণিত স্প্রিন্ট সম্পন্ন।',
        'গণিত স্প্রিন্ট সম্পন্ন।',
      ),
      score: _engine.score,
      isNewBest: _isNewBest,
      stats: [solvedStat, accuracyStat, streakStat, levelStat],
      playAgainLabel: _t('PLAY AGAIN', 'আবার খেলুন', 'फिर से खेलें'),
      shareLabel: _t('SHARE SCORE', 'স্কোর শেয়ার করুন', 'स्कोर साझा करें'),
      exitLabel: _t('EXIT', 'ফেরত যান', 'बाहर जाएं'),
      footerHint: _t('Best: $_best', 'সেরা: $_best', 'सर्वश्रेष्ठ: $_best'),
      onPlayAgain: _playAgain,
      onShare: _shareScore,
      onExit: _exitGame,
      continueLabel: _workoutStep != null
          ? _t('CONTINUE', 'চালিয়ে যান', 'जारी रखें')
          : null,
      onContinue: _workoutStep != null ? _exitGame : null,
    );
  }

  Widget _buildFloaters() {
    if (_floaters.isEmpty) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            for (final floater in _floaters)
              Align(
                alignment: const Alignment(0, -0.1),
                child: AnimatedBuilder(
                  animation: floater.controller,
                  builder: (context, _) {
                    final t =
                        Curves.easeOut.transform(floater.controller.value);
                    return Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, -40 * t),
                        child: Text(
                          floater.text,
                          style: GoogleFonts.montserrat(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: floater.color,
                            shadows: [
                              Shadow(
                                color: floater.color.withValues(alpha: 0.55),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _glass(bool isDark, Color accent, {double alpha = 0.05}) {
    return BoxDecoration(
      color: (isDark ? Colors.white : Colors.black).withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(AppSpacing.rLg),
      border: Border.all(
        color: accent.withValues(alpha: isDark ? 0.40 : 0.35),
        width: 1,
      ),
    );
  }
}

// ── Decorative background ───────────────────────────────────────────────

/// Slowly drifting radial-gradient glows that sit behind the whole game. Pure
/// opacity/transform work on the GPU — no `BackdropFilter`, so it stays smooth
/// even on low-end devices.
class _AuroraBackground extends StatefulWidget {
  const _AuroraBackground();

  @override
  State<_AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<_AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 26))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value * 2 * pi;
              final w = size.width;
              final h = size.height;
              return Stack(
                children: [
                  _blob(
                    center: Offset(w * (0.12 + 0.10 * sin(t)),
                        h * (0.16 + 0.08 * cos(t + 1))),
                    radius: w * 0.55,
                    color: const Color(0xFF00F1FE),
                  ),
                  _blob(
                    center: Offset(w * (0.88 + 0.10 * cos(t + 2)),
                        h * (0.30 + 0.08 * sin(t + 3))),
                    radius: w * 0.50,
                    color: const Color(0xFF8B5CF6),
                  ),
                  _blob(
                    center: Offset(w * (0.5 + 0.12 * sin(t + 4)),
                        h * (0.78 + 0.10 * cos(t + 5))),
                    radius: w * 0.55,
                    color: const Color(0xFFFF5FA8),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _blob(
      {required Offset center, required double radius, required Color color}) {
    return Positioned(
      left: center.dx - radius,
      top: center.dy - radius,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.16),
              color.withValues(alpha: 0.0)
            ],
          ),
        ),
      ),
    );
  }
}

// ── Gradient ring card ──────────────────────────────────────────────────

/// A glass card wrapped in a thin gradient ring with a soft glow. Used for the
/// problem card, pause panel and level-up pill so every surface shares the
/// same neon-glass language.
class _GradientRingCard extends StatelessWidget {
  final double radius;
  final List<Color> ringColors;
  final Color glow;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _GradientRingCard({
    super.key,
    required this.radius,
    required this.ringColors,
    required this.glow,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: ringColors,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: glow,
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(max(radius - 2, 0)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF0D1117), Color(0xFF161E2E)]
                : const [Colors.white, Color(0xFFF1F5F9)],
          ),
        ),
        child: child,
      ),
    );
  }
}

class _FloatingScore {
  final AnimationController controller;
  final String text;
  final Color color;

  _FloatingScore(this.controller, this.text, this.color);
}

// ── Per-problem countdown ring ──────────────────────────────────────────

/// Circular countdown badge pinned to the problem card's corner. Drains as the
/// per-question time budget runs out, turns green -> yellow -> red, and shows
/// the whole seconds remaining in the middle.
class _ProblemTimerRing extends StatelessWidget {
  final AnimationController controller;
  final double budgetSeconds;

  const _ProblemTimerRing({
    required this.controller,
    required this.budgetSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final remaining = (1 - controller.value).clamp(0.0, 1.0);
        final seconds = (remaining * budgetSeconds).ceil();
        final color = remaining > 0.5
            ? AppColors.success
            : remaining > 0.25
                ? AppColors.warning
                : AppColors.error;
        return Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (isDark ? const Color(0xFF0D1117) : Colors.white)
                .withValues(alpha: 0.92),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: remaining,
                  strokeWidth: 3,
                  strokeCap: StrokeCap.round,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Text(
                '$seconds',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
