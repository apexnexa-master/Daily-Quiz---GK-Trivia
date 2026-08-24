// lib/presentation/workout/workout_screen.dart
// Quick Brain Workout orchestration layer.
//
// The screen drives a preset-driven sequence of the existing games. It keeps
// the current position, launches each game through its normal route (passing a
// `WorkoutStep`), waits for the popped 0-100 score, then shows a short
// transition before the next game and a final results summary with Brain Points.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_animations.dart';
import '../../core/services/daily_progress_service.dart';
import '../../core/services/quiz/practice_quiz_service.dart';
import '../../core/scoring/progression_service.dart';
import '../../data/models/firestore_models.dart';
import '../providers/app_providers.dart';
import '../screens/games/arrow_puzzle/engine/data/campaign_data.dart';
import 'workout_models.dart';

class WorkoutScreen extends ConsumerStatefulWidget {
  final String presetId;
  const WorkoutScreen({super.key, this.presetId = WorkoutPresets.balancedId});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

enum _WorkoutPhase { pick, intro, transition, results }

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  WorkoutPreset? _preset;
  _WorkoutPhase _phase = _WorkoutPhase.pick;
  final List<WorkoutGameResult> _results = [];
  int _currentIndex = 0;
  bool _awardedPoints = false;
  int _pointsGained = 0;
  bool _wasDailyGoalCompleteBefore = false;

  int? _arrowLevelId;
  bool _arrowReady = false;
  Future<QuizModel?>? _quizPreloadFuture;
  bool _quizReady = false;

  @override
  void initState() {
    super.initState();
    _checkInitialDailyGoal();
  }

  /// Pre-warms the next game while the current phase is visible so that
  /// switching feels instant: the arrow-puzzle level is generated on a
  /// background isolate and the GK quiz session is fetched ahead of time.
  void _prewarmGame(int index) {
    final game = _preset!.games[index];
    switch (game.id) {
      case WorkoutGameId.arrowPuzzle:
        _arrowLevelId = Random().nextInt(CampaignCatalog().totalLevels) + 1;
        _arrowReady = false;
        CampaignCatalog.generateInBackground(_arrowLevelId!)
            .then((_) {
              if (mounted && !_arrowReady) setState(() => _arrowReady = true);
            })
            .catchError((_) {
              if (mounted && !_arrowReady) setState(() => _arrowReady = true);
            });
        break;
      case WorkoutGameId.gkQuiz:
        _quizReady = false;
        _ensureQuiz().then((_) {
          if (mounted && !_quizReady) setState(() => _quizReady = true);
        });
        break;
      case WorkoutGameId.stroopRush:
      case WorkoutGameId.synapseRecall:
      case WorkoutGameId.mathSprint:
        break;
    }
  }

  Future<QuizModel?> _ensureQuiz() {
    return _quizPreloadFuture ??= _fetchQuiz();
  }

  /// Whether the upcoming game is prepared enough to launch. Arrow levels are
  /// generated on a background isolate and GK quiz sessions are fetched ahead
  /// of time; the transition's Continue button stays disabled until ready.
  bool get _nextReady {
    final game = _preset!.games[_currentIndex];
    switch (game.id) {
      case WorkoutGameId.arrowPuzzle:
        return _arrowReady;
      case WorkoutGameId.gkQuiz:
        return _quizReady;
      case WorkoutGameId.stroopRush:
      case WorkoutGameId.synapseRecall:
      case WorkoutGameId.mathSprint:
        return true;
    }
  }

  Future<QuizModel?> _fetchQuiz() async {
    try {
      await PracticeQuizService.instance.init();
      return await PracticeQuizService.instance
          .fetchPracticeQuiz(questionCount: 5);
    } catch (_) {
      return null;
    }
  }

  Future<void> _checkInitialDailyGoal() async {
    final progress = await DailyProgressService.instance.getProgress();
    if (mounted) {
      setState(() {
        _wasDailyGoalCompleteBefore = progress.isDailyGoalComplete;
      });
    }
  }

  String get _lang => ref.read(languageProvider);

  bool get _isBn => _lang == 'bn';
  bool get _isHi => _lang == 'hi';

  Future<bool> _onWillPop() async {
    if (_phase == _WorkoutPhase.results) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      return true;
    }
    final shouldQuit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.cardDark
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.exit_to_app_rounded,
                color: AppColors.warning, size: 22),
            const SizedBox(width: 8),
            Text(
              _isBn
                  ? 'ওয়ার্কআউট ত্যাগ করবেন?'
                  : _isHi
                      ? 'वर्कआउट छोड़ें?'
                      : 'Quit Workout?',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
        content: Text(
          _isBn
              ? 'আপনি ওয়ার্কআউট ছেড়ে গেলে বর্তমান অগ্রগতি সংরক্ষিত হবে না।'
              : _isHi
                  ? 'यदि आप वर्कआउट छोड़ते हैं तो वर्तमान प्रगति सहेजी नहीं जाएगी।'
                  : 'Your progress in this workout session will be lost.',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : Colors.grey.shade600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_isBn
                ? 'থাকুন'
                : _isHi
                    ? 'रुकें'
                    : 'Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(_isBn
                ? 'প্রস্থান'
                : _isHi
                    ? 'बाहर निकलें'
                    : 'Quit'),
          ),
        ],
      ),
    );
    if (shouldQuit == true) {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      }
    }
    return false;
  }

  Future<void> _launchGame(int index) async {
    final game = _preset!.games[index];
    final step =
        WorkoutStep(game: game, index: index, total: _preset!.games.length);

    // GK Quiz needs a prepared quiz session before the quiz screen loads.
    if (game.id == WorkoutGameId.gkQuiz) {
      final quiz = await _ensureQuiz();
      if (quiz != null) {
        ref.read(quizSessionProvider.notifier).startQuiz(quiz);
      } else {
        // No quiz available — treat as skipped so the workout still flows.
        _recordResult(game, null);
        await _afterGame(index);
        return;
      }
    }

    final args = <String, dynamic>{
      'workoutStep': step,
      if (game.id == WorkoutGameId.arrowPuzzle) 'isDailyChallenge': true,
      if (game.id == WorkoutGameId.arrowPuzzle && _arrowLevelId != null)
        'preparedLevelId': _arrowLevelId,
    };

    final result =
        await Navigator.pushNamed(context, step.route, arguments: args) as int?;
    if (!mounted) return;

    _recordResult(game, result);
    await _afterGame(index);
  }

  void _recordResult(WorkoutGameDef game, int? score) {
    _results.add(WorkoutGameResult(game: game, score: score));
    // Refresh the shared daily-goal / brain-score data used by the results.
    ref.invalidate(dailyProgressProvider);
  }

  Future<void> _afterGame(int index) async {
    setState(() {
      _currentIndex = index + 1;
      if (_currentIndex >= _preset!.games.length) {
        _phase = _WorkoutPhase.results;
      } else {
        _phase = _WorkoutPhase.transition;
        _prewarmGame(_currentIndex);
      }
    });
    if (_currentIndex >= _preset!.games.length) {
      await _awardPointsIfNeeded();
    }
  }

  Future<void> _awardPointsIfNeeded() async {
    if (_awardedPoints) return;
    _awardedPoints = true;
    // Component games hand back normalized 0-100 scores; the workout is
    // rewarded once by the central XPService (config + daily cap).
    final scores = _results
        .where((r) => r.completed && r.score! > 0)
        .map((r) => r.score!)
        .toList();
    final overall =
        scores.isEmpty ? 0 : (scores.reduce((a, b) => a + b) ~/ scores.length);
    final award = await ProgressionService.instance.awardWorkout(
      overallScore: overall,
      completedCount: scores.length,
      plannedCount: _results.length,
    );
    if (mounted) {
      setState(() {
        _pointsGained = award.granted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dailyProgress =
        ref.watch(dailyProgressProvider).value ?? const DailyProgress();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onWillPop();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: Theme.of(context).brightness == Brightness.dark
                ? AppColors.homeBackdropDark
                : AppColors.homeBackdropGradient,
          ),
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: switch (_phase) {
                _WorkoutPhase.pick => _WorkoutGamePicker(
                    key: const ValueKey('picker'),
                    lang: _lang,
                    overridePreset: widget.presetId != WorkoutPresets.balancedId
                        ? WorkoutPresets.byId(widget.presetId)
                        : null,
                    onPicked: (preset) {
                      setState(() {
                        _preset = preset;
                        _phase = _WorkoutPhase.intro;
                      });
                      _prewarmGame(0);
                    },
                    onBack: () async => await _onWillPop(),
                  ),
                _WorkoutPhase.intro => _WorkoutIntro(
                    key: const ValueKey('intro'),
                    preset: _preset!,
                    progress: dailyProgress,
                    lang: _lang,
                    onStart: () => _launchGame(0),
                    onBack: () async => await _onWillPop(),
                  ),
                _WorkoutPhase.transition => _WorkoutTransition(
                    key: ValueKey('transition-$_currentIndex'),
                    completed: _results[_currentIndex - 1].game,
                    completedScore: _results[_currentIndex - 1].score,
                    next: _preset!.games[_currentIndex],
                    index: _currentIndex + 1,
                    total: _preset!.games.length,
                    lang: _lang,
                    nextReady: _nextReady,
                    onContinue: () => _launchGame(_currentIndex),
                  ),
                _WorkoutPhase.results => _WorkoutResults(
                    key: const ValueKey('results'),
                    session:
                        WorkoutSessionResult(preset: _preset!, games: _results),
                    isBn: _isBn,
                    isHi: _isHi,
                    pointsGained: _pointsGained,
                    wasDailyGoalCompleteBefore: _wasDailyGoalCompleteBefore,
                    onDone: () => Navigator.pushNamedAndRemoveUntil(
                        context, '/home', (_) => false),
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Game-picking gimmick
// ─────────────────────────────────────────────────────────────────────────────
class _WorkoutGamePicker extends StatefulWidget {
  final String lang;
  final WorkoutPreset? overridePreset;
  final void Function(WorkoutPreset preset) onPicked;
  final Future<void> Function() onBack;

  const _WorkoutGamePicker({
    super.key,
    required this.lang,
    this.overridePreset,
    required this.onPicked,
    required this.onBack,
  });

  @override
  State<_WorkoutGamePicker> createState() => _WorkoutGamePickerState();
}

class _WorkoutGamePickerState extends State<_WorkoutGamePicker> {
  final List<int> _reelIndex = [0, 1, 2];
  final List<bool> _locked = [false, false, false];
  List<WorkoutGameDef>? _picked;
  Timer? _ticker;
  final List<Timer?> _settleTimers = [null, null, null];
  Timer? _revealTimer;

  bool get isBn => widget.lang == 'bn';
  bool get isHi => widget.lang == 'hi';

  @override
  void initState() {
    super.initState();
    final pool = List<WorkoutGameDef>.of(WorkoutPresets.allGames)..shuffle();
    _picked = widget.overridePreset?.games ??
        WorkoutPresets.fromGames(pool.take(3).toList()).games;

    // Advance every unlocked reel with a per-reel offset so the spin looks
    // organic instead of marching in lock-step.
    _ticker = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _reelIndex.length; i++) {
          if (_locked[i]) continue;
          _reelIndex[i] =
              (_reelIndex[i] + 1 + i) % WorkoutPresets.allGames.length;
        }
      });
    });

    // Lock the reels one at a time onto their picked game, then reveal.
    const settleDelays = [
      Duration(milliseconds: 1500),
      Duration(milliseconds: 1900),
      Duration(milliseconds: 2300)
    ];
    for (int i = 0; i < settleDelays.length; i++) {
      _settleTimers[i] = Timer(settleDelays[i], () => _settleReel(i));
    }
    _revealTimer = Timer(const Duration(milliseconds: 2500), _revealPick);
  }

  void _settleReel(int reel) {
    if (!mounted || _picked == null) return;
    setState(() {
      _reelIndex[reel] = WorkoutPresets.allGames.indexOf(_picked![reel]);
      _locked[reel] = true;
    });
  }

  void _revealPick() {
    _ticker?.cancel();
    if (!mounted || _picked == null) return;
    widget.onPicked(WorkoutPresets.fromGames(_picked!));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final t in _settleTimers) {
      t?.cancel();
    }
    _revealTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          IconButton(
            onPressed: () => widget.onBack(),
            style: IconButton.styleFrom(
              backgroundColor: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.06),
            ),
            icon: Icon(
              Icons.close_rounded,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const Spacer(),
          Center(
            child: PulseWidget(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.18),
                      AppColors.secondary
                          .withValues(alpha: isDark ? 0.12 : 0.08),
                    ],
                  ),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.6),
                      width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary
                          .withValues(alpha: isDark ? 0.3 : 0.15),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: const Icon(Icons.casino_rounded,
                    color: AppColors.primary, size: 38),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              isBn
                  ? 'গেম বাছাই হচ্ছে…'
                  : isHi
                      ? 'गेम चुन रहे हैं…'
                      : 'CHOOSING GAMES…',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              isBn
                  ? 'আপনার জন্য ৩টি গেম বেছে নেওয়া হচ্ছে'
                  : isHi
                      ? 'आपके लिए 3 गेम चुने जा रहे हैं'
                      : 'Choosing 3 games for you',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                _GameReel(
                  game: WorkoutPresets.allGames[_reelIndex[i]],
                  number: i + 1,
                  locked: _locked[i],
                  isDark: isDark,
                  lang: widget.lang,
                ),
              ],
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _GameReel extends StatelessWidget {
  final WorkoutGameDef game;
  final int number;
  final bool locked;
  final bool isDark;
  final String lang;
  const _GameReel({
    required this.game,
    required this.number,
    required this.locked,
    required this.isDark,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final accent = game.skill.accent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedScale(
          scale: locked ? 1.0 : 0.96,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 96,
            height: 124,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: locked
                    ? [
                        accent.withValues(alpha: isDark ? 0.30 : 0.22),
                        accent.withValues(alpha: isDark ? 0.12 : 0.06),
                      ]
                    : [
                        (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: isDark ? 0.06 : 0.04),
                        (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: isDark ? 0.03 : 0.02),
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accent.withValues(alpha: locked ? 0.95 : 0.3),
                width: locked ? 2 : 1.2,
              ),
              boxShadow: locked
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: isDark ? 0.5 : 0.35),
                        blurRadius: 22,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        game.skill.emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          game.title(lang),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: locked
                                ? accent
                                : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (locked)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                      ),
                      child: const Icon(Icons.lock_rounded,
                          size: 13, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: locked ? 1 : 0.5,
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: locked
                  ? accent
                  : (isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Intro
// ─────────────────────────────────────────────────────────────────────────────
class _WorkoutIntro extends StatelessWidget {
  final WorkoutPreset preset;
  final DailyProgress progress;
  final String lang;
  final VoidCallback onStart;
  final Future<void> Function() onBack;

  const _WorkoutIntro({
    super.key,
    required this.preset,
    required this.progress,
    required this.lang,
    required this.onStart,
    required this.onBack,
  });

  bool get isBn => lang == 'bn';
  bool get isHi => lang == 'hi';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final skills = preset.games.map((g) => g.skill).toSet().toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          IconButton(
            onPressed: () => onBack(),
            style: IconButton.styleFrom(
              backgroundColor: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.06),
            ),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const Spacer(),
          BounceInWidget(
            child: Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.10),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary
                          .withValues(alpha: isDark ? 0.25 : 0.12),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: AppColors.primary, size: 42),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Text(
              isBn
                  ? 'দ্রুত ব্রেন ওয়ার্কআউট'
                  : isHi
                      ? 'क्विक ब्रेन वर्कआउट'
                      : 'QUICK BRAIN WORKOUT',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              isBn
                  ? 'একটি সেশনে ${skills.length}টি দক্ষতা প্রশিক্ষণ দিন'
                  : isHi
                      ? 'एक सेशन में ${skills.length} कौशल प्रशिक्षित करें'
                      : 'Train ${skills.length} skills in one session',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Chip(
                  icon: Icons.sports_esports_rounded,
                  label: isBn
                      ? '${preset.games.length}টি গেম'
                      : isHi
                          ? '${preset.games.length} गेम'
                          : '${preset.games.length} games',
                ),
                const SizedBox(width: 8),
                _Chip(
                  icon: Icons.schedule_rounded,
                  label: isBn
                      ? '~৫–৭ মিনিট'
                      : isHi
                          ? '~5–7 मिनट'
                          : '~5–7 min',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Visibility(
            visible: !progress.isDailyGoalComplete,
            child: _DailyGoalMini(progress: progress, isBn: isBn, isHi: isHi),
          ),
          const SizedBox(height: 24),
          Text(
            isBn
                ? 'আপনি যা প্রশিক্ষণ দেবেন'
                : isHi
                    ? 'आप प्रशिक्षण लेंगे'
                    : "You'll train",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          for (final game in preset.games) ...[
            _GameRow(game: game, lang: lang),
            const SizedBox(height: 10),
          ],
          const Spacer(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: AnimatedScaleButton(
                onTap: onStart,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary
                            .withValues(alpha: isDark ? 0.3 : 0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      isBn
                          ? 'শুরু করুন'
                          : isHi
                              ? 'शुरू करें'
                              : 'START WORKOUT',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyGoalMini extends StatelessWidget {
  final DailyProgress progress;
  final bool isBn;
  final bool isHi;
  const _DailyGoalMini({
    required this.progress,
    required this.isBn,
    required this.isHi,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completed = progress.dailyGamesCompleted.clamp(0, progress.dailyGoal);
    final goalHit = progress.isDailyGoalComplete;
    final accent = goalHit ? const Color(0xFF10B981) : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: goalHit
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.16 : 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              goalHit
                  ? Icons.local_fire_department_rounded
                  : Icons.flag_rounded,
              size: 17,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBn
                      ? goalHit
                          ? 'দৈনিক লক্ষ্য পূরণ!'
                          : 'দৈনিক লক্ষ্য'
                      : isHi
                          ? goalHit
                              ? 'दैनिक लक्ष्य पूर्ण!'
                              : 'दैनिक लक्ष्य'
                          : goalHit
                              ? "Today's goal hit!"
                              : "Today's goal",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress.dailyGoal > 0
                        ? completed / progress.dailyGoal
                        : 0,
                    minHeight: 5,
                    backgroundColor: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$completed/${progress.dailyGoal}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color:
                (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  final WorkoutGameDef game;
  final String lang;
  const _GameRow({required this.game, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final skill = game.skill;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: skill.accent.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: skill.accent.withValues(alpha: isDark ? 0.16 : 0.10),
              shape: BoxShape.circle,
            ),
            child: Center(
                child: Text(skill.emoji, style: const TextStyle(fontSize: 17))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.title(lang),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  skill.label(lang),
                  style: TextStyle(
                    fontSize: 11,
                    color: skill.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 18,
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.25)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Between-game transition
// ─────────────────────────────────────────────────────────────────────────────
class _WorkoutTransition extends StatelessWidget {
  final WorkoutGameDef completed;
  final int? completedScore;
  final WorkoutGameDef next;
  final int index;
  final int total;
  final String lang;
  final bool nextReady;
  final VoidCallback onContinue;

  const _WorkoutTransition({
    super.key,
    required this.completed,
    this.completedScore,
    required this.next,
    required this.index,
    required this.total,
    required this.lang,
    this.nextReady = true,
    required this.onContinue,
  });

  bool get isBn => lang == 'bn';
  bool get isHi => lang == 'hi';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 1; i <= total; i++)
                Container(
                  width: i <= (index - 1) ? 24 : 12,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i <= (index - 1)
                        ? AppColors.success
                        : i == index
                            ? AppColors.primary
                            : (isDark ? Colors.white12 : Colors.black12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          BounceInWidget(
            child: Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.success.withValues(alpha: 0.25),
                      AppColors.success.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: AppColors.success, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.success, size: 44),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Text(
              isBn
                  ? completedScore != null
                      ? '${completed.skill.emoji} ${completed.skill.label(lang)} সম্পন্ন!'
                      : '${completed.skill.emoji} ${completed.skill.label(lang)} এড়িয়ে গেছে'
                  : isHi
                      ? completedScore != null
                          ? '${completed.skill.emoji} ${completed.skill.label(lang)} पूर्ण!'
                          : '${completed.skill.emoji} ${completed.skill.label(lang)} छोड़ा गया'
                      : completedScore != null
                          ? '✓ ${completed.skill.label(lang)} COMPLETED!'
                          : 'SKIPPED ${completed.skill.label(lang)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              completed.title(lang),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          if (completedScore != null) ...[
            const SizedBox(height: 14),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: completed.skill.accent
                      .withValues(alpha: isDark ? 0.14 : 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: completed.skill.accent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars_rounded,
                        size: 15, color: completed.skill.accent),
                    const SizedBox(width: 6),
                    Text(
                      isBn
                          ? 'স্কোর: $completedScore/100'
                          : isHi
                              ? 'स्कोर: $completedScore/100'
                              : 'SCORE: $completedScore/100',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: completed.skill.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E292B), const Color(0xFF131A30)]
                    : [Colors.white, const Color(0xFFF1F5F9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: next.skill.accent.withValues(alpha: 0.45), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color:
                      next.skill.accent.withValues(alpha: isDark ? 0.12 : 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: next.skill.accent
                        .withValues(alpha: isDark ? 0.2 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                      child: Text(next.skill.emoji,
                          style: const TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBn
                            ? 'পরবর্তী গেম ($index/$total)'
                            : isHi
                                ? 'अगला गेम ($index/$total)'
                                : 'NEXT UP ($index/$total)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: next.skill.accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        next.title(lang),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        next.skill.label(lang),
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          if (!nextReady) ...[
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      next.skill.accent.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: next.skill.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: next.skill.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isBn
                          ? 'পরবর্তী চ্যালেঞ্জ প্রস্তুত হচ্ছে…'
                          : isHi
                              ? 'अगली चुनौती तैयार हो रही है…'
                              : 'Preparing next challenge…',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: next.skill.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          AnimatedScaleButton(
            onTap: nextReady ? onContinue : null,
            child: Opacity(
              opacity: nextReady ? 1 : 0.5,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary
                          .withValues(alpha: isDark ? 0.3 : 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    isBn
                        ? 'চালিয়ে যান →'
                        : isHi
                            ? 'जारी रखें →'
                            : 'CONTINUE →',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Final results
// ─────────────────────────────────────────────────────────────────────────────
class _WorkoutResults extends ConsumerWidget {
  final WorkoutSessionResult session;
  final bool isBn;
  final bool isHi;
  final int pointsGained;
  final bool wasDailyGoalCompleteBefore;
  final VoidCallback onDone;

  const _WorkoutResults({
    super.key,
    required this.session,
    required this.isBn,
    required this.isHi,
    required this.pointsGained,
    required this.wasDailyGoalCompleteBefore,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimaryLight;
    final dailyProgress =
        ref.watch(dailyProgressProvider).value ?? const DailyProgress();
    final completedCount = session.completedCount;
    final overall = session.overallScore;
    final goalComplete = dailyProgress.isDailyGoalComplete;
    final showNewGoalCompletion = goalComplete && !wasDailyGoalCompleteBefore;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BounceInWidget(
            child: Center(
              child: Text(
                isBn
                    ? 'ওয়ার্কআউট সম্পন্ন! 🎉'
                    : isHi
                        ? 'वर्कआउट पूर्ण! 🎉'
                        : 'WORKOUT COMPLETE 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              completedCount == 0
                  ? isBn
                      ? 'আজ কোনো দক্ষতা সম্পূর্ণভাবে প্রশিক্ষিত হয়নি।'
                      : isHi
                          ? 'आज कोई कौशल पूरी तरह प्रशिक्षित नहीं हुआ।'
                          : 'No skill was fully trained this time — keep going!'
                  : isBn
                      ? 'আজ আপনি $completedCountটি দক্ষতা সফলভাবে প্রশিক্ষণ দিয়েছেন।'
                      : isHi
                          ? 'आपने आज $completedCount कौशल सफलतापूर्वक प्रशिक्षित किए।'
                          : 'You successfully trained $completedCount skills today.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(height: 24),
          for (final result in session.games) ...[
            _ResultSkillRow(result: result, isBn: isBn, isHi: isHi),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          _OverallScoreCard(score: overall, isBn: isBn, isHi: isHi),
          const SizedBox(height: 14),
          if (pointsGained > 0)
            _BrainPointsChip(points: pointsGained, isBn: isBn, isHi: isHi),
          const SizedBox(height: 16),
          Visibility(
            visible: !dailyProgress.isDailyGoalComplete,
            child: _DailyGoalCard(
              progress: dailyProgress,
              isBn: isBn,
              isHi: isHi,
            ),
          ),
          if (showNewGoalCompletion) ...[
            const SizedBox(height: 12),
            Center(
              child: BounceInWidget(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: Color(0xFFF97316), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      isBn
                          ? 'দৈনিক লক্ষ্য সম্পন্ন! 🔥'
                          : isHi
                              ? 'दैनिक लक्ष्य पूर्ण! 🔥'
                              : 'Daily Goal Complete! 🔥',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF97316),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          AnimatedScaleButton(
            onTap: onDone,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary
                        .withValues(alpha: isDark ? 0.3 : 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  isBn
                      ? 'সম্পন্ন'
                      : isHi
                          ? 'पूर्ण'
                          : 'DONE',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultSkillRow extends StatelessWidget {
  final WorkoutGameResult result;
  final bool isBn;
  final bool isHi;
  const _ResultSkillRow(
      {required this.result, required this.isBn, required this.isHi});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final skill = result.game.skill;
    final score = result.score;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: skill.accent.withValues(alpha: 0.35), width: 1.1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: skill.accent.withValues(alpha: isDark ? 0.18 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
                child: Text(skill.emoji, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill.label(isBn
                      ? 'bn'
                      : isHi
                          ? 'hi'
                          : 'en'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  result.game.title(isBn
                      ? 'bn'
                      : isHi
                          ? 'hi'
                          : 'en'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
          ),
          if (score != null)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: score.toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, animated, _) => Text(
                '${animated.round()}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: skill.accent,
                ),
              ),
            )
          else
            Text(
              '—',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.25),
              ),
            ),
        ],
      ),
    );
  }
}

class _OverallScoreCard extends StatelessWidget {
  final int score;
  final bool isBn;
  final bool isHi;
  const _OverallScoreCard(
      {required this.score, required this.isBn, required this.isHi});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.12),
            AppColors.secondary.withValues(alpha: isDark ? 0.10 : 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBn
                      ? 'সামগ্রিক ওয়ার্কআউট স্কোর'
                      : isHi
                          ? 'समग्र वर्कआउट स्कोर'
                          : 'Overall Workout Score',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isBn || isHi
                      ? (score >= 70
                          ? 'দারুণ!'
                          : score >= 45
                              ? 'ভালো!'
                              : 'তারা চেষ্টা চালিয়ে যান')
                      : (score >= 70
                          ? 'Great!'
                          : score >= 45
                              ? 'Good job!'
                              : 'Keep training!'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score.toDouble()),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, animated, _) => Text(
              '${animated.round()}',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                height: 1,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrainPointsChip extends StatelessWidget {
  final int points;
  final bool isBn;
  final bool isHi;
  const _BrainPointsChip(
      {required this.points, required this.isBn, required this.isHi});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.12),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.psychology_rounded,
                color: AppColors.primary, size: 18),
            const SizedBox(width: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: points.toDouble()),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, animated, _) => Text(
                isBn
                    ? '+${animated.round()} ব্রেন পয়েন্ট'
                    : isHi
                        ? '+${animated.round()} ब्रेन पॉइंट्स'
                        : '+${animated.round()} Brain Points',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyGoalCard extends StatelessWidget {
  final DailyProgress progress;
  final bool isBn;
  final bool isHi;
  const _DailyGoalCard(
      {required this.progress, required this.isBn, required this.isHi});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completed = progress.dailyGamesCompleted.clamp(0, progress.dailyGoal);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color:
                (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isBn
                    ? 'দৈনিক লক্ষ্য'
                    : isHi
                        ? 'दैनिक लक्ष्य'
                        : 'Daily Goal',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              Text(
                '$completed/${progress.dailyGoal}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value:
                  progress.dailyGoal > 0 ? completed / progress.dailyGoal : 0,
              backgroundColor: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.08),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
