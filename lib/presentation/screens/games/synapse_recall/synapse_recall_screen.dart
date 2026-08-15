// lib/presentation/screens/games/synapse_recall/synapse_recall_screen.dart
// SYNAPSE RECALL — a visual working-memory game.
//
// Flow: INTRO → COUNTDOWN → MEMORIZE → RECALL → FEEDBACK → NEXT ROUND →
//       ... → SESSION COMPLETE → RESULTS.
//
// The player watches a sequence of premium geometric objects, then rebuilds it
// from a tile pool. Difficulty (sequence length + viewing time) always grows.
// The engine is a pure Dart class so future recall modes can plug in cleanly.
//
// Visual language: neon-glass, matching Math Sprint — animated aurora, glowing
// board cards, glass HUD, shared countdown + results system and full sound.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/daily_progress_service.dart';
import '../../../../core/services/game_sfx.dart';
import '../../../../core/theme/app_animations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../games/widgets/countdown_overlay.dart';
import '../../../providers/app_providers.dart';
import '../../../workout/workout_models.dart';
import '../../../workout/workout_progress_banner.dart';
import 'memory_object.dart';
import 'synapse_art.dart';
import 'synapse_config.dart';
import 'synapse_engine.dart';

enum _SynapsePhase {
  intro,
  countdown,
  memorize,
  recall,
  correct,
  incorrect,
  results
}

class SynapseRecallScreen extends ConsumerStatefulWidget {
  const SynapseRecallScreen({super.key});

  @override
  ConsumerState<SynapseRecallScreen> createState() =>
      _SynapseRecallScreenState();
}

class _SynapseRecallScreenState extends ConsumerState<SynapseRecallScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final SynapseRecallEngine _engine;

  _SynapsePhase _phase = _SynapsePhase.intro;
  int _roundNumber = 0;
  SynapseRound? _round;
  List<MemoryObject> _selection = [];
  SynapseRoundResult? _lastResult;

  Timer? _autoAdvanceTimer;

  late final AnimationController _memorize;
  late final AnimationController _shake;
  late final AnimationController _boardIn;

  // Personal bests (persisted).
  int _bestLongestSequence = 0;
  int _bestScore = 0;
  int _bestStreak = 0;
  bool _isNewBest = false;

  WorkoutStep? _workoutStep;
  bool _gameFinished = false;

  bool get _isBn => _lang == 'bn';
  bool get _isHi => _lang == 'hi';
  String get _lang => ref.read(languageProvider);

  String _t(String en, String bn, String hi) => _isBn
      ? bn
      : _isHi
          ? hi
          : en;

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = SynapseRecallEngine();
    _memorize = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed &&
            _phase == _SynapsePhase.memorize) {
          _beginRecall();
        }
      });
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _boardIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _loadBests();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoAdvanceTimer?.cancel();
    _memorize.dispose();
    _shake.dispose();
    _boardIn.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_phase == _SynapsePhase.memorize) _memorize.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (_phase == _SynapsePhase.memorize && !_memorize.isAnimating) {
        _memorize.forward();
      }
    }
  }

  Future<void> _loadBests() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _bestLongestSequence =
          prefs.getInt(SynapseConfig.prefBestLongestSequence) ?? 0;
      _bestScore = prefs.getInt(SynapseConfig.prefBestScore) ?? 0;
      _bestStreak = prefs.getInt(SynapseConfig.prefBestStreak) ?? 0;
    });
  }

  // ── Flow control ────────────────────────────────────────────────────────

  void _startGame() {
    GameSfxService.instance.play(GameSfx.tap);
    HapticFeedback.lightImpact();
    setState(() => _phase = _SynapsePhase.countdown);
  }

  void _onCountdownFinished() {
    if (!mounted) return;
    _startRound(1);
  }

  void _startRound(int number) {
    if (!mounted) return;
    final round = _engine.buildRound(number);
    _roundNumber = number;
    _round = round;
    _selection = [];
    _lastResult = null;
    _boardIn.forward(from: 0);
    setState(() => _phase = _SynapsePhase.memorize);
    _memorize.duration =
        Duration(milliseconds: (round.viewSeconds * 1000).round());
    _memorize.forward(from: 0);
  }

  void _beginRecall() {
    if (!mounted || _phase != _SynapsePhase.memorize) return;
    HapticFeedback.selectionClick();
    setState(() => _phase = _SynapsePhase.recall);
  }

  void _toggleSelection(MemoryObject object) {
    if (_phase != _SynapsePhase.recall) return;
    final round = _round;
    if (round == null) return;
    final index = _selection.indexOf(object);
    GameSfxService.instance.play(GameSfx.tap);
    setState(() {
      if (index >= 0) {
        _selection.removeAt(index);
        HapticFeedback.selectionClick();
      } else if (_selection.length < round.length) {
        _selection.add(object);
        HapticFeedback.selectionClick();
        if (_selection.length == round.length) {
          _evaluate();
        }
      }
    });
  }

  void _evaluate() {
    final round = _round;
    if (round == null) return;
    final result = _engine.submit(round, List.of(_selection));
    _lastResult = result;

    if (result.correct) {
      GameSfxService.instance
          .play(_engine.stats.streak >= 2 ? GameSfx.combo : GameSfx.correct);
      HapticFeedback.lightImpact();
      setState(() => _phase = _SynapsePhase.correct);
      _autoAdvanceTimer?.cancel();
      _autoAdvanceTimer = Timer(SynapseConfig.correctAutoAdvance, () {
        if (mounted) _nextRound();
      });
    } else {
      GameSfxService.instance.play(GameSfx.wrong);
      HapticFeedback.mediumImpact();
      _shake.forward(from: 0);
      setState(() => _phase = _SynapsePhase.incorrect);
    }
  }

  void _nextRound() {
    _autoAdvanceTimer?.cancel();
    GameSfxService.instance.play(GameSfx.tap);
    if (_roundNumber >= SynapseConfig.sessionRounds) {
      _finishSession();
    } else {
      _startRound(_roundNumber + 1);
    }
  }

  /// Replays the current round (same sequence) so the player can solve it.
  void _retryRound() {
    _autoAdvanceTimer?.cancel();
    GameSfxService.instance.play(GameSfx.tap);
    final round = _round;
    if (!mounted || round == null) return;
    setState(() {
      _selection = [];
      _lastResult = null;
      _phase = _SynapsePhase.memorize;
    });
    _boardIn.forward(from: 0);
    _memorize.duration =
        Duration(milliseconds: (round.viewSeconds * 1000).round());
    _memorize.forward(from: 0);
  }

  Future<void> _finishSession() async {
    final stats = _engine.stats;
    GameSfxService.instance.play(GameSfx.gameOver);
    final newBestSeq = stats.longestCorrectSequence > _bestLongestSequence;
    final newBestScore = stats.score > _bestScore;
    final newBestStreak = stats.bestStreak > _bestStreak;
    _isNewBest = newBestSeq || newBestScore || newBestStreak;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (newBestSeq) {
      prefs.setInt(
          SynapseConfig.prefBestLongestSequence, stats.longestCorrectSequence);
    }
    if (newBestScore) {
      prefs.setInt(SynapseConfig.prefBestScore, stats.score);
    }
    if (newBestStreak) {
      prefs.setInt(SynapseConfig.prefBestStreak, stats.bestStreak);
    }

    // Share the session with the BRAINX daily-goal / brain-score system
    // (Memory pillar). Accuracy is the 0-100 performance metric.
    DailyProgressService.instance.recordGameCompletion(
      pillar: BrainPillar.memory,
      scorePct: stats.accuracy,
      gameType: GameType.synapse,
    );
    try {
      ProviderScope.containerOf(context, listen: false)
          .invalidate(dailyProgressProvider);
    } catch (_) {}

    setState(() {
      _gameFinished = true;
      _phase = _SynapsePhase.results;
    });
  }

  void _playAgain() {
    _autoAdvanceTimer?.cancel();
    _memorize.stop();
    GameSfxService.instance.play(GameSfx.tap);
    setState(() {
      _engine.stats
        ..score = 0
        ..streak = 0
        ..bestStreak = 0
        ..correctRounds = 0
        ..totalRounds = 0
        ..longestCorrectSequence = 0
        ..maxLevelReached = 0;
      _gameFinished = false;
      _isNewBest = false;
      _selection = [];
      _round = null;
    });
    _startGame();
  }

  void _exit() {
    GameSfxService.instance.play(GameSfx.tap);
    if (_workoutStep != null) {
      Navigator.pop(context, _engine.stats.workoutScore);
    } else {
      Navigator.pop(context);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppColors.homeBackdropDark
                  : AppColors.homeBackdropGradient,
            ),
            child: Stack(
              children: [
                _buildGlowDots(isDark),
                SafeArea(
                  child: Column(
                    children: [
                      if (_workoutStep != null)
                        WorkoutProgressBanner(step: _workoutStep!),
                      _buildHeader(isDark),
                      if (_phase == _SynapsePhase.memorize ||
                          _phase == _SynapsePhase.recall)
                        _buildStatsRow(isDark),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 380),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: switch (_phase) {
                            _SynapsePhase.memorize =>
                              _buildMemorizeBoard(isDark),
                            _SynapsePhase.recall => _buildRecallArea(isDark),
                            _ => const SizedBox.shrink(),
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_phase == _SynapsePhase.intro) _buildIntroOverlay(isDark),
          if (_phase == _SynapsePhase.countdown)
            CountdownOverlay(
              onFinished: _onCountdownFinished,
              goLabel: _t('GO!', 'শুরু!', 'शुरू!'),
            ),
          if (_phase == _SynapsePhase.correct) _buildCorrectOverlay(isDark),
          if (_phase == _SynapsePhase.incorrect) _buildIncorrectOverlay(isDark),
          if (_phase == _SynapsePhase.results) _buildResultsOverlay(isDark),
        ],
      ),
    );
  }

  Widget _buildGlowDots(bool isDark) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: _GlowOrb(
              size: 240,
              color: AppColors.primary,
              alpha: isDark ? 0.14 : 0.08,
            ),
          ),
          Positioned(
            bottom: 60,
            left: -80,
            child: _GlowOrb(
              size: 220,
              color: const Color(0xFFB388FF),
              alpha: isDark ? 0.14 : 0.06,
            ),
          ),
          Positioned(
            top: 220,
            right: 20,
            child: _GlowOrb(
              size: 170,
              color: const Color(0xFF00F1FE),
              alpha: isDark ? 0.10 : 0.05,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final subtle =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06);
    final playing =
        _phase == _SynapsePhase.memorize || _phase == _SynapsePhase.recall;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              GameSfxService.instance.play(GameSfx.tap);
              if (_gameFinished && _workoutStep != null) {
                Navigator.pop(context, _engine.stats.workoutScore);
              } else {
                Navigator.pop(context);
              }
            },
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(backgroundColor: subtle),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: isDark
                        ? [AppColors.primary, const Color(0xFF00F1FE)]
                        : [AppColors.primaryDark, const Color(0xFF0369A1)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ).createShader(bounds),
                  child: Text(
                    'SYNAPSE RECALL',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.3 : 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  _t(
                      'Remember. Rebuild. Repeat.',
                      'মনে রাখুন। পুনর্গঠন করুন। পুনরাবৃত্তি করুন।',
                      'याद रखें। दोबारा बनाएँ। दोहराएँ।'),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
          ),
          if (playing) ...[
            _buildChip(
              Icons.local_fire_department_rounded,
              '${_engine.stats.streak}',
              const Color(0xFFF97316),
              isDark,
            ),
            const SizedBox(width: 8),
          ],
          _buildChip(
            Icons.psychology_rounded,
            '$_bestLongestSequence',
            isDark ? AppColors.primary : AppColors.primaryDark,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _buildStatBox(
              _t('ROUND', 'রাউন্ড', 'राउंड'),
              '${_roundNumber.toString().padLeft(2, '0')} / ${SynapseConfig.sessionRounds}',
              Icons.tag_rounded,
              const Color(0xFF00F1FE),
              isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _buildStatBox(
              _t('SCORE', 'স্কোর', 'स्कोर'),
              '${_engine.stats.score}',
              Icons.bolt_rounded,
              AppColors.primary,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(
    String label,
    String value,
    IconData icon,
    Color accent,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.03)
                ]
              : [
                  Colors.white.withValues(alpha: 0.96),
                  Colors.white.withValues(alpha: 0.80)
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.10 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
              shape: BoxShape.circle,
              border:
                  Border.all(color: accent.withValues(alpha: 0.35), width: 1),
            ),
            child: Icon(icon, size: 11, color: accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Memorize board ──────────────────────────────────────────────────────

  Widget _buildMemorizeBoard(bool isDark) {
    final round = _round;
    if (round == null) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          '${_t('ROUND', 'রাউন্ড', 'राउंड')} ${round.number.toString().padLeft(2, '0')}',
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _t('MEMORIZE', 'মনে রাখুন', 'याद करें'),
          style: GoogleFonts.montserrat(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _t('Remember the pattern', 'প্যাটার্নটি মনে রাখুন',
              'पैटर्न याद रखें'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: _buildBoardSurface(
                    isDark,
                    constraints.maxWidth,
                    round,
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 8, 48, 12),
          child: _MemorizeProgress(controller: _memorize, isDark: isDark),
        ),
      ],
    );
  }

  Widget _buildBoardSurface(bool isDark, double maxWidth, SynapseRound round) {
    final length = round.sequence.length;
    const gap = 14.0;
    final maxObj =
        math.min(74.0, (maxWidth - 36 - (length - 1) * gap) / length);
    final objSize = maxObj.clamp(38.0, 74.0);

    return AnimatedBuilder(
      animation: _boardIn,
      builder: (context, _) {
        final t = _boardIn.value;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF1B2426).withValues(alpha: 0.85),
                      const Color(0xFF0E1415).withValues(alpha: 0.75),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.92),
                      const Color(0xFFEAF0F5).withValues(alpha: 0.92),
                    ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Opacity(
            opacity: t,
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < round.sequence.length; i++)
                  ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.3,
                      end: 1.0,
                    ).animate(CurvedAnimation(
                      parent: _boardIn,
                      curve: Interval(
                        (i / length).clamp(0.0, 0.9),
                        1.0,
                        curve: Curves.easeOutBack,
                      ),
                    )),
                    child: MemoryObjectView(
                      object: round.sequence[i],
                      size: objSize,
                      glow: isDark,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Recall area ─────────────────────────────────────────────────────────

  Widget _buildRecallArea(bool isDark) {
    final round = _round;
    if (round == null) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          _t('RECALL', 'মনে করুন', 'याद करें'),
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _t('Rebuild the sequence', 'ধারাটি পুনর্গঠন করুন',
              'अनुक्रम दोबारा बनाएँ'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
        ),
        const SizedBox(height: 12),
        _buildProgressDots(round, isDark),
        const SizedBox(height: 8),
        Text(
          '${_selection.length} / ${round.length}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const cols = 4;
                const gap = 10.0;
                final tile = ((constraints.maxWidth - (cols - 1) * gap) / cols)
                    .clamp(56.0, 96.0);
                return SingleChildScrollView(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final object in round.candidates)
                        _RecallTile(
                          object: object,
                          size: tile,
                          selectedIndex: _selection.indexOf(object),
                          isDark: isDark,
                          shake: _shake,
                          onTap: () => _toggleSelection(object),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _t(
                'Tap a tile to add it · tap again to remove',
                'টাইল ট্যাপ করে যোগ করুন · আবার ট্যাপে মুছুন',
                'टाइल टैप करके जोड़ें · फिर टैप करके हटाएँ'),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressDots(SynapseRound round, bool isDark) {
    final placed = _selection;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < round.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < placed.length
                    ? AppColors.primary
                    : (isDark ? Colors.white12 : Colors.black12),
                border: Border.all(
                  color: i < placed.length
                      ? AppColors.primary
                      : (isDark ? Colors.white24 : Colors.black12),
                  width: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Intro overlay ───────────────────────────────────────────────────────

  Widget _buildIntroOverlay(bool isDark) {
    final textPrimary = isDark ? Colors.white : AppColors.textPrimaryLight;
    final textTertiary =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: ColoredBox(
          color: (isDark ? const Color(0xFF0B0E14) : const Color(0xFFF8FAFC))
              .withValues(alpha: isDark ? 0.92 : 0.94),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildIntroChip(
                          Icons.timer_outlined, '~2–4 min', textTertiary),
                      const SizedBox(width: 8),
                      _buildIntroChip(Icons.psychology_rounded,
                          _t('MEMORY', 'স্মৃতি', 'स्मृति'), AppColors.primary),
                    ],
                  ),
                  const Spacer(),
                  BounceInWidget(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary
                            .withValues(alpha: isDark ? 0.06 : 0.04),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary
                                .withValues(alpha: isDark ? 0.14 : 0.08),
                            blurRadius: 40,
                          ),
                        ],
                      ),
                      child: const SynapseNetworkArt(),
                    ),
                  ),
                  const SizedBox(height: 26),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: isDark
                          ? [AppColors.primary, const Color(0xFF00F1FE)]
                          : [AppColors.primaryDark, const Color(0xFF0369A1)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(bounds),
                    child: Text(
                      'SYNAPSE RECALL',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t(
                        'Remember. Rebuild. Repeat.',
                        'মনে রাখুন। পুনর্গঠন করুন। পুনরাবৃত্তি করুন।',
                        'याद रखें। दोबारा बनाएँ। दोहराएँ।'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: textTertiary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    _t(
                        'Remember the pattern.\nRebuild it in the correct order.',
                        'প্যাটার্নটি মনে রাখুন।\nসঠিক ক্রমে সাজান।',
                        'पैटर्न याद रखें।\nसही क्रम में बनाएँ।'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  AnimatedScaleButton(
                    onTap: _startGame,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD4FF50), Color(0xFF9BFF3F)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary
                                .withValues(alpha: isDark ? 0.4 : 0.2),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _t('START', 'শুরু করুন', 'शुरू करें'),
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Correct overlay ─────────────────────────────────────────────────────

  Widget _buildCorrectOverlay(bool isDark) {
    final result = _lastResult;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimaryLight;
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: isDark ? 0.7 : 0.45),
          child: Center(
            child: BounceInWidget(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 36),
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.success.withValues(alpha: isDark ? 0.22 : 0.14),
                      (isDark ? const Color(0xFF151D1E) : Colors.white)
                          .withValues(alpha: 0.98),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.5),
                      width: 1.4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.35),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success.withValues(alpha: 0.16),
                        border: Border.all(color: AppColors.success, width: 2),
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: AppColors.success, size: 34),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _t('PERFECT RECALL', 'নিখুঁত স্মরণ', 'सटीक याद'),
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '+${result?.scoreGained ?? 0}',
                      style: GoogleFonts.montserrat(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    if (_engine.stats.streak >= 2) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              color: Color(0xFFF97316), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${_t('Streak', 'স্ট্রিক', 'स्ट्रीक')} ${_engine.stats.streak}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFF97316),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Incorrect overlay ───────────────────────────────────────────────────

  Widget _buildIncorrectOverlay(bool isDark) {
    final round = _round;
    final result = _lastResult;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimaryLight;
    final textTertiary =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: isDark ? 0.72 : 0.5),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ShakeWidget(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [const Color(0xFF1C2425), AppColors.cardDark]
                          : [Colors.white, const Color(0xFFF1F5F9)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 34,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.warning.withValues(alpha: 0.14),
                          border:
                              Border.all(color: AppColors.warning, width: 2),
                        ),
                        child: const Icon(Icons.refresh_rounded,
                            color: AppColors.warning, size: 30),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _t('Not quite.', 'প্রায় হয়েছে।', 'बिल्कुल सही नहीं।'),
                        style: GoogleFonts.montserrat(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _t(
                            'You remembered: ${result?.remembered ?? 0} / ${round?.length ?? 0}',
                            'আপনি মনে রেখেছেন: ${result?.remembered ?? 0} / ${round?.length ?? 0}',
                            'आपने याद रखा: ${result?.remembered ?? 0} / ${round?.length ?? 0}'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textTertiary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _t('Correct sequence', 'সঠিক ধারা', 'सही अनुक्रम'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 10,
                        children: [
                          for (var i = 0;
                              i < (round?.sequence.length ?? 0);
                              i++) ...[
                            if (i > 0)
                              const Icon(Icons.arrow_forward_rounded,
                                  size: 14, color: Colors.white38),
                            MemoryObjectView(
                              object: round!.sequence[i],
                              size: 34,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),
                      AnimatedScaleButton(
                        onTap: _retryRound,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD4FF50), Color(0xFF9BFF3F)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _t('TRY AGAIN', 'আবার চেষ্টা করুন',
                                  'फिर से प्रयास करें'),
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      AnimatedScaleButton(
                        onTap: _nextRound,
                        child: SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: Center(
                            child: Text(
                              _t('Skip → next round', 'স্কিপ → পরের রাউন্ড',
                                  'छोड़ें → अगला राउंड'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: textTertiary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Results overlay ─────────────────────────────────────────────────────

  Widget _buildResultsOverlay(bool isDark) {
    final stats = _engine.stats;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimaryLight;
    final textTertiary =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: isDark ? 0.76 : 0.5),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [const Color(0xFF1C2425), AppColors.cardDark]
                        : [Colors.white, Colors.white.withValues(alpha: 0.98)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 34,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BounceInWidget(
                      child: Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.12),
                          border:
                              Border.all(color: AppColors.primary, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 26,
                            ),
                          ],
                        ),
                        child: const SynapseNetworkArt(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'SYNAPSE RECALL',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _t('SESSION COMPLETE', 'সেশন সম্পন্ন', 'सत्र पूर्ण'),
                      style: GoogleFonts.montserrat(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_isNewBest)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.4, end: 1),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFBBF24)
                                    .withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            _t(
                                '🎉 NEW PERSONAL BEST!',
                                '🎉 নতুন ব্যক্তিগত রেকর্ড!',
                                '🎉 नया व्यक्तिगत रिकॉर्ड!'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildResultStat(
                                  _t('MEMORY LEVEL', 'স্মৃতি স্তর',
                                      'स्मृति स्तर'),
                                  '${stats.maxLevelReached}',
                                  Icons.psychology_rounded,
                                  AppColors.primary,
                                  isDark,
                                ),
                              ),
                              Expanded(
                                child: _buildResultStat(
                                  _t('ACCURACY', 'সঠিকতা', 'सटीकता'),
                                  '${stats.accuracy}%',
                                  Icons.ads_click_rounded,
                                  const Color(0xFF3B82F6),
                                  isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Divider(
                            height: 1,
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.08),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildResultStat(
                                  _t('BEST STREAK', 'সেরা স্ট্রিক',
                                      'सर्वश्रेष्ठ स्ट्रीक'),
                                  '${stats.bestStreak}',
                                  Icons.local_fire_department_rounded,
                                  const Color(0xFFF97316),
                                  isDark,
                                ),
                              ),
                              Expanded(
                                child: _buildResultStat(
                                  _t('LONGEST SEQUENCE', 'দীর্ঘতম ধারা',
                                      'सबसे लंबा अनुक्रम'),
                                  '${stats.longestCorrectSequence} '
                                  '${_t('items', 'টি আইটেম', 'आइटम')}',
                                  Icons.hub_rounded,
                                  const Color(0xFF00F1FE),
                                  isDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${stats.score}',
                          style: GoogleFonts.montserrat(
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            _t('SCORE', 'স্কোর', 'स्कोर'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_workoutStep == null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: FilledButton.icon(
                                onPressed: _exit,
                                icon: const Icon(Icons.close_rounded, size: 18),
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      (isDark ? Colors.white : Colors.black)
                                          .withValues(alpha: 0.06),
                                  foregroundColor: textPrimary,
                                  side: BorderSide(
                                    color:
                                        (isDark ? Colors.white : Colors.black)
                                            .withValues(alpha: 0.15),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                label: Text(
                                  _t('DONE', 'সম্পন্ন', 'पूर्ण'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: FilledButton.icon(
                                onPressed: _playAgain,
                                icon:
                                    const Icon(Icons.refresh_rounded, size: 18),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                label: Text(
                                  _t('PLAY AGAIN', 'আবার খেলুন',
                                      'फिर से खेलें'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _exit,
                          icon:
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          label: Text(
                            _t('CONTINUE', 'চালিয়ে যান', 'जारी रखें'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultStat(
      String label, String value, IconData icon, Color accent, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 5),
            Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
        ),
      ],
    );
  }
}

// ── Memorize progress bar ─────────────────────────────────────────────────

class _MemorizeProgress extends StatelessWidget {
  final AnimationController controller;
  final bool isDark;

  const _MemorizeProgress({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final remaining = (1 - controller.value).clamp(0.0, 1.0);
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: remaining,
            minHeight: 6,
            backgroundColor:
                (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation<Color>(
              remaining > 0.3
                  ? AppColors.primary
                  : AppColors.warning.withValues(alpha: 0.9),
            ),
          ),
        );
      },
    );
  }
}

// ── Recall tile ───────────────────────────────────────────────────────────

class _RecallTile extends StatelessWidget {
  final MemoryObject object;
  final double size;
  final int selectedIndex; // -1 when not selected
  final bool isDark;
  final AnimationController shake;
  final VoidCallback onTap;

  const _RecallTile({
    required this.object,
    required this.size,
    required this.selectedIndex,
    required this.isDark,
    required this.shake,
    required this.onTap,
  });

  static String _circle(int n) {
    if (n >= 1 && n <= 10) {
      return const [
        '①',
        '②',
        '③',
        '④',
        '⑤',
        '⑥',
        '⑦',
        '⑧',
        '⑨',
        '⑩',
      ][n - 1];
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final selected = selectedIndex >= 0;
    const accent = AppColors.primary;

    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? [
                  accent.withValues(alpha: isDark ? 0.24 : 0.16),
                  accent.withValues(alpha: isDark ? 0.06 : 0.04),
                ]
              : isDark
                  ? [const Color(0xFF1B2426), const Color(0xFF141B1C)]
                  : [Colors.white, const Color(0xFFEAF0F5)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? accent.withValues(alpha: 0.9)
              : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10),
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          if (selected)
            BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: shake,
            builder: (context, child) {
              final t = shake.value;
              final dx =
                  t <= 0 ? 0.0 : math.sin(t * math.pi * 12) * 10 * (1 - t);
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: MemoryObjectView(
              object: object,
              size: size * 0.52,
              glow: selected || isDark,
            ),
          ),
          if (selected)
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  _circle(selectedIndex + 1),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    height: 1.3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return AnimatedScaleButton(onTap: onTap, child: tile);
  }
}

// ── Glow orb helper (mirrors the BRAINX glassmorphism atmosphere) ─────────

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double alpha;

  const _GlowOrb(
      {required this.size, required this.color, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: alpha), Colors.transparent],
        ),
      ),
    );
  }
}
