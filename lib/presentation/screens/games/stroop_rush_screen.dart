// lib/presentation/screens/games/stroop_rush_screen.dart
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/ad_service.dart';
import '../../../core/services/daily_progress_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';

enum _StroopRule { tapInk, tapWord }

class StroopRushScreen extends StatefulWidget {
  const StroopRushScreen({super.key});

  @override
  State<StroopRushScreen> createState() => _StroopRushScreenState();
}

class _StroopRushScreenState extends State<StroopRushScreen>
    with TickerProviderStateMixin {
  static const double _baseTurnSeconds = 5.0;
  static const double _minTurnSeconds = 1.5;
  static const int _maxLives = 3;

  static const List<String> _allNames = ['RED', 'BLUE', 'GREEN', 'YELLOW', 'PURPLE', 'ORANGE', 'PINK'];
  static const List<Color> _allValues = [
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFEAB308),
    Color(0xFFA855F7),
    Color(0xFFF97316),
    Color(0xFFEC4899),
  ];

  /// Active palette grows as the player scores higher.
  List<String> get _names => _correct >= 15 ? _allNames : _allNames.sublist(0, 5);
  List<Color> get _values => _correct >= 15 ? _allValues : _allValues.sublist(0, 5);

  final Random _rng = Random();
  late final AnimationController _timer;
  late final AnimationController _shake;
  late final AnimationController _confetti;
  late final AnimationController _introPulse;

  String _text = 'RED';
  Color _ink = const Color(0xFFEF4444);
  int _textIndex = 0;
  int _inkIndex = 0;
  _StroopRule _rule = _StroopRule.tapInk;
  int _correctIdx = 0;
  int _distractorIdx = 1;
  int _distractor2Idx = -1; // -1 means no 3rd option
  bool _correctOnLeft = true;
  int _correctSlot = 0; // 0=left, 1=right, 2=center (for 3-option)

  int _prevTextIndex = -1;
  int _prevInkIndex = -1;
  bool? _lastAnswer;
  int _sameAnswerCount = 0;

  double _turnSeconds = _baseTurnSeconds;
  int _score = 0;
  int _best = 0;
  int _correct = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _lives = _maxLives;
  int _totalReactionMs = 0;
  int _round = 0;
  int _totalAttempts = 0;
  int _totalSpeedPoints = 0;
  double _lastComboMultiplier = 1.0;
  bool _hasStreakFreeze = false;
  bool _flashStreak = false;

  bool _intro = true;
  bool _playing = false;
  bool _paused = false;
  bool _finished = false;
  bool _answering = false;
  bool _flashCorrect = false;
  bool _flashWrong = false;
  bool _flashPerfect = false;
  bool _showComboMilestone = false;
  String _comboMilestoneText = '';

  bool _ruleJustChanged = false;
  bool _ruleFlash = false;
  bool _isNewBest = false;
  bool _reviveUsed = false;
  bool _reviving = false;

  final List<_FloatingScore> _floaters = [];
  SharedPreferences? _prefs;

  bool get _has3Options => _correct >= 20 && _distractor2Idx >= 0;

  /// For 2-option mode
  int get _leftIdx => _correctOnLeft ? _correctIdx : _distractorIdx;
  int get _rightIdx => _correctOnLeft ? _distractorIdx : _correctIdx;

  /// For 3-option mode: slot 0=left, 1=center, 2=right
  int _slotIdx(int slot) {
    if (!_has3Options) return slot == 0 ? _leftIdx : _rightIdx;
    if (slot == _correctSlot) return _correctIdx;
    final distractors = [_distractorIdx, _distractor2Idx];
    final otherSlots = [0, 1, 2].where((s) => s != _correctSlot).toList();
    final pos = otherSlots.indexOf(slot);
    return pos >= 0 && pos < distractors.length ? distractors[pos] : _distractorIdx;
  }

  double get _accuracy => _totalAttempts == 0 ? 0 : (_correct / _totalAttempts) * 100;

  int get _speedPips =>
      1 + (((_baseTurnSeconds - _turnSeconds) / (_baseTurnSeconds - _minTurnSeconds)) * 4).round().clamp(0, 4);

  double get _avgReactionSeconds =>
      _correct == 0 ? 0 : (_totalReactionMs / _correct) / 1000;

  double get _comboMultiplier {
    if (_streak >= 15) return 2.5;
    if (_streak >= 10) return 2.0;
    if (_streak >= 5) return 1.5;
    return 1.0;
  }

  @override
  void initState() {
    super.initState();
    _timer = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_baseTurnSeconds * 1000).round()),
    );
    _timer.addStatusListener((status) {
      if (status == AnimationStatus.completed && _playing && !_answering) {
        _onTimeout();
      }
    });
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _introPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _best = prefs.getInt('stroop_best_score') ?? 0;
    });
    _nextTurn();
  }

  @override
  void dispose() {
    _timer.dispose();
    _shake.dispose();
    _confetti.dispose();
    _introPulse.dispose();
    for (final floater in _floaters) {
      floater.controller.dispose();
    }
    super.dispose();
  }

  _StroopRule _pickRule() {
    if (_correct < 6) return _StroopRule.tapInk;
    // Progressive: switch probability grows with score
    final switchChance = (_correct < 12) ? 0.3 : (_correct < 20) ? 0.45 : 0.5;
    final swap = _rng.nextDouble() < switchChance;
    return swap
        ? (_rule == _StroopRule.tapInk ? _StroopRule.tapWord : _StroopRule.tapInk)
        : _rule;
  }

  void _nextTurn() {
    _round++;
    final previousRule = _rule;
    var placed = false;
    for (var attempt = 0; attempt < 8; attempt++) {
      final textIndex = _rng.nextInt(_names.length);
      final inkIndex = _rng.nextInt(_values.length);

      if (textIndex == _prevTextIndex && inkIndex == _prevInkIndex) continue;

      final rule = _pickRule();
      final correctIdx = rule == _StroopRule.tapInk ? inkIndex : textIndex;
      var distractorIdx = _rng.nextInt(_names.length);
      if (distractorIdx == correctIdx) {
        distractorIdx = (distractorIdx + 1) % _names.length;
      }
      final correctOnLeft = _rng.nextBool();

      if (_sameAnswerCount >= 3 && correctOnLeft == _lastAnswer) continue;
      if (correctOnLeft == _lastAnswer) {
        _sameAnswerCount++;
      } else {
        _sameAnswerCount = 1;
      }

      _prevTextIndex = textIndex;
      _prevInkIndex = inkIndex;
      _lastAnswer = correctOnLeft;
      _textIndex = textIndex;
      _text = _names[textIndex];
      _inkIndex = inkIndex;
      _ink = _values[inkIndex];
      _rule = rule;
      _correctIdx = correctIdx;
      _distractorIdx = distractorIdx;
      _correctOnLeft = correctOnLeft;
      placed = true;
      break;
    }
    if (!placed) {
      _correctOnLeft = !(_lastAnswer ?? true);
      _lastAnswer = _correctOnLeft;
      _sameAnswerCount = 1;
      _textIndex = _prevTextIndex < 0 ? 0 : (_prevTextIndex + 1) % _names.length;
      _inkIndex = _prevInkIndex < 0 ? 1 : (_prevInkIndex + 1) % _values.length;
      _prevTextIndex = _textIndex;
      _prevInkIndex = _inkIndex;
      _text = _names[_textIndex];
      _ink = _values[_inkIndex];
      _rule = _StroopRule.tapInk;
      _correctIdx = _inkIndex;
      _distractorIdx = (_inkIndex + 1) % _names.length;
    }

    // Generate 3rd distractor at high difficulty
    if (_correct >= 20) {
      var d2 = _rng.nextInt(_names.length);
      while (d2 == _correctIdx || d2 == _distractorIdx) {
        d2 = (d2 + 1) % _names.length;
      }
      _distractor2Idx = d2;
      _correctSlot = _rng.nextInt(3);
    } else {
      _distractor2Idx = -1;
    }

    _ruleJustChanged = _rule != previousRule;
    _timer.value = 0;
    setState(() {});
  }

  void _updateTurnDuration(double reactionSeconds) {
    final speedBonus = (_baseTurnSeconds - reactionSeconds).clamp(0.0, _baseTurnSeconds);
    final shrink = 0.03 + speedBonus * 0.06;
    _turnSeconds = (_turnSeconds - shrink).clamp(_minTurnSeconds, _baseTurnSeconds);
    _timer.duration = Duration(milliseconds: (_turnSeconds * 1000).round());
  }

  void _startGame() {
    if (_playing) return;
    HapticFeedback.selectionClick();
    _introPulse.stop();
    _introPulse.value = 0;
    setState(() => _intro = false);
    _nextTurn();
    setState(() => _playing = true);
    _timer.forward(from: 0);
  }

  void _togglePause() {
    if (!_playing || _finished || _answering || _intro) return;
    HapticFeedback.selectionClick();
    if (_paused) {
      setState(() => _paused = false);
      if (!_answering) {
        _timer.forward(from: _timer.value);
      }
    } else {
      _timer.stop();
      setState(() => _paused = true);
    }
  }

  Future<void> _advance() async {
    _nextTurn();
    if (_ruleJustChanged) {
      _answering = true;
      setState(() => _ruleFlash = true);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() {
        _ruleFlash = false;
        _answering = false;
      });
    }
    if (!_playing || _finished) return;
    _timer.forward(from: 0);
  }

  void _submitAnswer({required int slot}) {
    if (!_playing || _answering || _finished) return;
    _answering = true;
    _totalAttempts++;
    final remaining = 1 - _timer.value;
    _timer.stop();

    final tappedIdx = _slotIdx(slot);
    final isCorrect = tappedIdx == _correctIdx;

    if (isCorrect) {
      final reactionMs = ((_turnSeconds - remaining * _turnSeconds) * 1000).round();
      _totalReactionMs += reactionMs;
      _correct++;
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;

      // Grant streak freeze shield at 10-streak
      if (_streak == 10 && !_hasStreakFreeze) {
        _hasStreakFreeze = true;
        _spawnFloater('🛡️ SHIELD', const Color(0xFF3B82F6));
      }

      final speedPoints = (remaining * 6).round();
      final comboPoints =
          ((10 + speedPoints) * (_comboMultiplier - 1)).round();
      final earned = 10 + speedPoints + comboPoints;
      _totalSpeedPoints += speedPoints;
      _score += earned;
      final reactionSeconds = (1 - remaining) * _turnSeconds;
      _updateTurnDuration(reactionSeconds);

      // Flash the streak stat gold when the combo multiplier climbs
      if (_comboMultiplier > _lastComboMultiplier) {
        _lastComboMultiplier = _comboMultiplier;
        setState(() => _flashStreak = true);
        Future<void>.delayed(const Duration(milliseconds: 650), () {
          if (!mounted) return;
          setState(() => _flashStreak = false);
        });
      }

      // Perfect answer detection (< 0.8s)
      final isPerfect = reactionSeconds < 0.8;
      HapticFeedback.lightImpact();

      setState(() {
        _flashCorrect = true;
        _flashPerfect = isPerfect;
      });

      _spawnFloater(
        isPerfect ? '$earned PERFECT' : '$earned',
        isPerfect ? const Color(0xFFFBBF24) : AppColors.success,
      );

      // Combo milestone banners
      if (_streak == 5 || _streak == 10 || _streak == 15 || _streak == 20) {
        _showComboMilestone = true;
        _comboMilestoneText = '🔥 x$_streak COMBO!';
        HapticFeedback.mediumImpact();
        Future<void>.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          setState(() => _showComboMilestone = false);
        });
      }

      Future<void>.delayed(const Duration(milliseconds: 130), () {
        if (!mounted) return;
        setState(() {
          _flashCorrect = false;
          _flashPerfect = false;
          _answering = false;
        });
        _advance();
      });
    } else {
      _onMistake();
    }
  }

  void _onTimeout() {
    if (!_playing || _answering || _finished) return;
    _answering = true;
    _timer.stop();
    _onMistake();
  }

  void _onMistake() {
    // Streak freeze: absorb one mistake without losing a life
    if (_hasStreakFreeze) {
      _hasStreakFreeze = false;
      HapticFeedback.mediumImpact();
      _spawnFloater('🛡️ SAVED', const Color(0xFF3B82F6));
      setState(() {
        _flashWrong = true;
        _streak = 0;
        _lastComboMultiplier = 1.0;
      });
      _shake.forward(from: 0);
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() {
          _flashWrong = false;
          _answering = false;
        });
        _advance();
      });
      return;
    }

    HapticFeedback.heavyImpact();
    _turnSeconds = (_turnSeconds + 0.4).clamp(_minTurnSeconds, _baseTurnSeconds);
    _timer.duration = Duration(milliseconds: (_turnSeconds * 1000).round());
    setState(() {
      _flashWrong = true;
      _lives--;
      _streak = 0;
      _lastComboMultiplier = 1.0;
    });
    _shake.forward(from: 0);
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      setState(() {
        _flashWrong = false;
        _answering = false;
      });
      if (_lives <= 0) {
        _finishGame();
      } else {
        _advance();
      }
    });
  }

  void _finishGame() {
    final isNewBest = _score > _best;
    _playing = false;
    _finished = true;
    if (isNewBest) {
      _best = _score;
      _confetti.repeat();
    }
    setState(() => _isNewBest = isNewBest);
    final prefs = _prefs;
    if (prefs != null && isNewBest) {
      prefs.setInt('stroop_best_score', _score);
    }

    // Track daily goal, streak & brain score (Reaction pillar)
    DailyProgressService.instance.recordGameCompletion(
      pillar: BrainPillar.reaction,
      scorePct: _score,
      gameType: GameType.stroop,
    );
    try {
      ProviderScope.containerOf(context, listen: false)
          .invalidate(dailyProgressProvider);
    } catch (_) {}
  }

  Future<void> _offerExtraLife() async {
    if (_reviving) return;
    setState(() => _reviving = true);
    try {
      if (!AdService.instance.isRewardedReady) {
        await AdService.instance.loadRewarded();
      }
      if (!AdService.instance.isRewardedReady) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No ad available right now. Please try again.')),
        );
        return;
      }
      final earned = await AdService.instance.showRewarded();
      if (earned) {
        if (!mounted) return;
        _reviveRun();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Watch the full ad to earn an extra life.')),
        );
      }
    } finally {
      if (mounted) setState(() => _reviving = false);
    }
  }

  void _reviveRun() {
    _confetti.stop();
    _confetti.value = 0;
    setState(() {
      _reviveUsed = true;
      _lives = _maxLives;
      _finished = false;
      _isNewBest = false;
      _playing = true;
      _paused = false;
      _answering = false;
    });
    _nextTurn();
    _timer.forward(from: 0);
  }

  Future<void> _shareScore() async {
    final rank = _rankInfo(_score);
    final text = '''
🎨 **Stroop Rush**

🔥 I scored **$_score** points!
🏆 Rank: ${rank.label}
✅ Correct: $_correct (${_accuracy.toStringAsFixed(0)}% accuracy)
⚡ Best streak: $_bestStreak

Can you beat me? 🚀
''';
    try {
      await Share.share(text, subject: '🎨 My Stroop Rush Score!');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sharing is not available right now.')),
      );
    }
  }

  void _playAgain() {
    _confetti.stop();
    _confetti.value = 0;
    setState(() {
      _score = 0;
      _correct = 0;
      _streak = 0;
      _bestStreak = 0;
      _lives = _maxLives;
      _totalReactionMs = 0;
      _round = 0;
      _totalAttempts = 0;
      _totalSpeedPoints = 0;
      _lastComboMultiplier = 1.0;
      _hasStreakFreeze = false;
      _flashStreak = false;
      _turnSeconds = _baseTurnSeconds;
      _timer.duration = Duration(milliseconds: (_turnSeconds * 1000).round());
      _intro = false;
      _playing = true;
      _paused = false;
      _finished = false;
      _answering = false;
      _flashCorrect = false;
      _flashWrong = false;
      _flashPerfect = false;
      _showComboMilestone = false;
      _isNewBest = false;
      _ruleFlash = false;
      _ruleJustChanged = false;
      _distractor2Idx = -1;
      _reviveUsed = false;
      _reviving = false;
      _floaters.clear();
      _prevTextIndex = -1;
      _prevInkIndex = -1;
      _lastAnswer = null;
      _sameAnswerCount = 0;
    });
    _nextTurn();
    _timer.forward(from: 0);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: isDark ? AppColors.homeBackdropDark : AppColors.homeBackdropGradient,
            ),
            child: Stack(
              children: [
                _buildGlowDots(isDark),
                _buildAurora(isDark),
                _buildVignette(isDark),
                SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(isDark),
                      _buildStatsRow(isDark),
                      Expanded(child: _buildWordStage(isDark)),
                      _buildAnswerArea(isDark),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildFloaters(),
          if (_showComboMilestone) _buildComboMilestoneOverlay(isDark),
          if (_ruleFlash) _buildRuleFlashOverlay(isDark),
          if (_intro) _buildIntroOverlay(isDark),
          if (_paused && !_finished) _buildPauseOverlay(isDark),
          if (_finished) _buildResultOverlay(isDark),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Aurora background (slow drifting color blooms)
  // ---------------------------------------------------------------------------
  Widget _buildAurora(bool isDark) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: -90,
            top: -70,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: isDark ? 0.10 : 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -70,
            bottom: -50,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFCF5CFF).withValues(alpha: isDark ? 0.10 : 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 60,
            top: 160,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.07 : 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Vignette + top spotlight (adds depth and focus on the word card)
  // ---------------------------------------------------------------------------
  Widget _buildVignette(bool isDark) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.05 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 320,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: isDark ? 0.38 : 0.06),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.1,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                  ],
                  stops: const [0.55, 0.82, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Background
  // ---------------------------------------------------------------------------
  Widget _buildGlowDots(bool isDark) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -70,
            child: _GlowOrb(
              size: 230,
              color: AppColors.primary,
              alpha: isDark ? 0.16 : 0.10,
            ),
          ),
          Positioned(
            bottom: 40,
            left: -80,
            child: _GlowOrb(
              size: 210,
              color: const Color(0xFFA855F7),
              alpha: isDark ? 0.16 : 0.08,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------
  Widget _buildHeader(bool isDark) {
    final subtle = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
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
                        ? [AppColors.primary, const Color(0xFFECB2FF)]
                        : [AppColors.primaryDark, AppColors.secondaryDark],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ).createShader(bounds),
                  child: Text(
                    'STROOP RUSH',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  'Match the rule. Beat the clock.',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _buildLivesIndicator(isDark),
          const SizedBox(width: 8),
          _buildSpeedChip(isDark),
          const SizedBox(width: 8),
          IconButton(
            onPressed: (_playing && !_finished && !_answering) ? _togglePause : null,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(backgroundColor: subtle),
            icon: Icon(
              _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivesIndicator(bool isDark) {
    final dim = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _maxLives; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Icon(
                Icons.favorite_rounded,
                size: 15,
                color: i < _lives ? const Color(0xFFF43F5E) : dim,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpeedChip(bool isDark) {
    final chipColor = isDark ? AppColors.primary : AppColors.primaryDark;
    final dim = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 14, color: chipColor),
          const SizedBox(width: 5),
          for (var i = 0; i < 5; i++)
            Container(
              width: 4,
              height: 9,
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              decoration: BoxDecoration(
                color: i < _speedPips ? chipColor : dim,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stats
  // ---------------------------------------------------------------------------
  Widget _buildStatsRow(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _buildStatBox(
              'ROUND',
              '$_round',
              Icons.tag_rounded,
              const Color(0xFF06B6D4),
              isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _buildStatBox(
              'SCORE',
              '$_score',
              Icons.bolt_rounded,
              AppColors.primary,
              isDark,
              countUp: true,
              goldFlash: _flashStreak,
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
    bool isDark, {
    String? trailing,
    bool countUp = false,
    bool goldFlash = false,
  }) {
    final boxAccent = goldFlash ? const Color(0xFFFBBF24) : accent;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.03)]
              : [Colors.white.withValues(alpha: 0.96), Colors.white.withValues(alpha: 0.80)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: boxAccent.withValues(alpha: goldFlash ? 0.75 : (isDark ? 0.35 : 0.25)),
          width: goldFlash ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: boxAccent.withValues(alpha: goldFlash ? 0.30 : (isDark ? 0.10 : 0.06)),
            blurRadius: goldFlash ? 20 : 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: boxAccent.withValues(alpha: isDark ? 0.18 : 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: boxAccent.withValues(alpha: 0.35), width: 1),
                ),
                child: Icon(icon, size: 11, color: boxAccent),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (countUp)
                            TweenAnimationBuilder<double>(
                              tween: Tween(end: _score.toDouble()),
                              duration: const Duration(milliseconds: 450),
                              curve: Curves.easeOutCubic,
                              builder: (context, animated, _) => Text(
                                '${animated.round()}',
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                ),
                              ),
                            )
                          else
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(scale: anim, child: child),
                              child: Text(
                                value,
                                key: ValueKey(value),
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: goldFlash
                                      ? const Color(0xFFFBBF24)
                                      : isDark
                                          ? Colors.white
                                          : AppColors.textPrimaryLight,
                                  shadows: goldFlash
                                      ? const [
                                          Shadow(
                                            color: Color(0xFFFBBF24),
                                            blurRadius: 12,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          if (trailing != null) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: boxAccent.withValues(alpha: isDark ? 0.22 : 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                trailing,
                                style: GoogleFonts.montserrat(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: boxAccent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: boxAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 10,
            right: 10,
            child: Container(
              height: 1.2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: isDark ? 0.35 : 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Question banner (high-contrast, single-scan instruction)
  // ---------------------------------------------------------------------------
  Widget _buildQuestion(bool isDark) {
    final isInk = _rule == _StroopRule.tapInk;
    final accent = isInk ? const Color(0xFF3EC8FF) : const Color(0xFFECB2FF);
    final highlight = isInk ? 'INK COLOR' : 'WRITTEN WORD';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(highlight),
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1B2426), const Color(0xFF0E1415)]
                : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.22 : 0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isInk ? Icons.palette_rounded : Icons.hub_rounded,
                  size: 15,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Text(
                  'TAP THE ',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Colors.white.withValues(alpha: isDark ? 0.9 : 0.95),
                  ),
                ),
                Text(
                  highlight,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: accent,
                    shadows: [
                      Shadow(color: accent.withValues(alpha: 0.8), blurRadius: 14),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 12,
              right: 12,
              child: Container(
                height: 1.2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: isDark ? 0.35 : 0.8),
                      Colors.transparent,
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

  // ---------------------------------------------------------------------------
  // Word stage (word + ink swatch at similar size)
  // ---------------------------------------------------------------------------
  Widget _buildWordStage(bool isDark) {
    final flash = _flashCorrect || _flashWrong || _flashPerfect;
    final borderColor = _flashPerfect
        ? const Color(0xFFFBBF24)
        : _flashCorrect
            ? AppColors.success
            : _flashWrong
                ? AppColors.error
                : (isDark ? Colors.white.withValues(alpha: 0.16) : Colors.black.withValues(alpha: 0.10));
    final glowColor = _flashPerfect
        ? const Color(0xFFFBBF24)
        : _flashCorrect
            ? AppColors.success
            : _flashWrong
                ? AppColors.error
                : Colors.white;
    final cardTint = isDark ? const Color(0xFF2E3637) : const Color(0xFFE2E8F0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final t = _shake.value;
          final dx = t <= 0 ? 0.0 : sin(t * pi * 12) * 14 * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cardTint.withValues(alpha: isDark ? 0.45 : 0.40),
                (isDark ? const Color(0xFF151D1E) : Colors.white).withValues(alpha: 0.97),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: borderColor,
              width: flash ? 3 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: flash
                    ? glowColor.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildQuestion(isDark),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _buildRingStage(glowColor, flash, isDark),
                  ),
                  const SizedBox(height: 10),
                  _buildRoundHint(isDark),
                ],
              ),
              Positioned(
                top: 0,
                left: 24,
                right: 24,
                child: Container(
                  height: 1.4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: isDark ? 0.35 : 0.85),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Circular countdown ring + word + ink swatch. Pulses and glows when time runs low.
  Widget _buildRingStage(Color glowColor, bool flash, bool isDark) {
    return AnimatedBuilder(
      animation: _timer,
      builder: (context, _) {
        final remaining = (1 - _timer.value).clamp(0.0, 1.0);
        final lowTime = _playing && !_finished && remaining < 0.25;
        final Color ringColor;
        if (remaining >= 0.55) {
          ringColor = Color.lerp(AppColors.success, AppColors.warning, (1 - remaining) / 0.45)!;
        } else {
          ringColor = Color.lerp(AppColors.warning, AppColors.error, (0.55 - remaining) / 0.55)!;
        }
        final pulse = lowTime ? 1 + sin(_timer.value * pi * 10) * 0.06 : 1.0;
        return LayoutBuilder(
          builder: (context, constraints) {
            final side = min(constraints.maxWidth, constraints.maxHeight);
            return Center(
              child: Transform.scale(
                scale: pulse,
                child: SizedBox(
                  width: side,
                  height: side,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size.square(side),
                        painter: _TimerRingPainter(
                          progress: remaining,
                          color: ringColor,
                          glow: lowTime,
                          trackColor: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : Colors.black.withValues(alpha: 0.07),
                          strokeWidth: 9,
                        ),
                      ),
                      _GlowOrb(
                        size: side * 0.74,
                        color: glowColor,
                        alpha: flash ? 0.32 : (isDark ? 0.10 : 0.30),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(
                              scale: Tween(begin: 0.9, end: 1.0).animate(
                                CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                              ),
                              child: child,
                            ),
                          ),
                          child: FittedBox(
                            key: ValueKey('$_text-${_ink.toARGB32()}'),
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _text,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(
                                fontSize: 84,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: _ink,
                                shadows: [
                                  Shadow(color: _ink.withValues(alpha: 0.5), blurRadius: 26),
                                  Shadow(color: _ink.withValues(alpha: 0.22), blurRadius: 60),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRoundHint(bool isDark) {
    final tertiary = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    String text;
    IconData icon;
    Color color = tertiary;

    if (_flashPerfect) {
      text = 'PERFECT!';
      icon = Icons.auto_awesome_rounded;
      color = const Color(0xFFFBBF24);
    } else if (_ruleFlash) {
      text = 'new rule — study it';
      icon = Icons.bolt_rounded;
      color = const Color(0xFFECB2FF);
    } else {
      text = '';
      icon = Icons.touch_app_rounded;
    }

    if (text.isEmpty) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Answer area (two or three color options to tap)
  // ---------------------------------------------------------------------------
  Widget _buildAnswerArea(bool isDark) {
    final enabled = _playing && !_answering && !_finished && !_intro && !_paused;

    Widget option(int slot, {required bool compact}) {
      final isLeft = slot == 0;
      final isRight = slot == (_has3Options ? 2 : 1);
      final slide = isLeft
          ? const Offset(-0.6, 0)
          : isRight
              ? const Offset(0.6, 0)
              : const Offset(0, 0.6);
      return TweenAnimationBuilder<Offset>(
        key: ValueKey('slot-$_round-$slot'),
        tween: Tween(begin: slide, end: Offset.zero),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        builder: (context, offset, child) => Transform.translate(
          offset: Offset(offset.dx * 46, offset.dy * 46),
          child: child,
        ),
        child: _ColorOption(
          name: _names[_slotIdx(slot)],
          color: _values[_slotIdx(slot)],
          isDark: isDark,
          enabled: enabled,
          compact: compact,
          onTap: () => _submitAnswer(slot: slot),
        ),
      );
    }

    if (_has3Options) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (var slot = 0; slot < 3; slot++) ...[
              if (slot > 0) const SizedBox(width: 8),
              Expanded(child: option(slot, compact: true)),
            ],
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: option(0, compact: false)),
          const SizedBox(width: 12),
          Expanded(child: option(1, compact: false)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Floating score popups
  // ---------------------------------------------------------------------------
  Widget _buildFloaters() {
    if (_floaters.isEmpty) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            for (var i = 0; i < _floaters.length; i++)
              Align(
                alignment: const Alignment(0, -0.15),
                child: AnimatedBuilder(
                  animation: _floaters[i].controller,
                  builder: (context, _) {
                    final item = _floaters[i];
                    final t = Curves.easeOutCubic.transform(item.controller.value);
                    return Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, -t * 64),
                        child: Transform.scale(
                          scale: 0.8 + t * 0.25,
                          child: Text(
                            '+${item.text}',
                            style: GoogleFonts.montserrat(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: item.color,
                              shadows: [
                                Shadow(
                                  color: item.color.withValues(alpha: 0.6),
                                  blurRadius: 18,
                                ),
                                const Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
                              ],
                            ),
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

  // ---------------------------------------------------------------------------
  // "NEW RULE" reveal pause
  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // Combo milestone overlay
  // ---------------------------------------------------------------------------
  Widget _buildComboMilestoneOverlay(bool isDark) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF97316).withValues(alpha: 0.22),
                    const Color(0xFFEF4444).withValues(alpha: 0.16),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFF97316).withValues(alpha: 0.7),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF97316).withValues(alpha: 0.5),
                    blurRadius: 32,
                  ),
                ],
              ),
              child: Text(
                _comboMilestoneText,
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: const Color(0xFFFBBF24),
                  shadows: [
                    Shadow(
                      color: const Color(0xFFF97316).withValues(alpha: 0.7),
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // "NEW RULE" reveal pause
  // ---------------------------------------------------------------------------
  Widget _buildRuleFlashOverlay(bool isDark) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 150,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.7, end: 1.0),
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA855F7).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFFA855F7).withValues(alpha: 0.6),
                          width: 1.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFA855F7).withValues(alpha: 0.4),
                            blurRadius: 28,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFFECB2FF),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'NEW RULE — READY?',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: const Color(0xFFECB2FF),
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
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Intro overlay (how to play + START)
  // ---------------------------------------------------------------------------
  Widget _buildIntroOverlay(bool isDark) {
    final cardText = isDark ? Colors.white : AppColors.textPrimaryLight;
    final cardTertiary = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
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
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
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
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'STROOP RUSH',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: cardText,
                        ),
                      ),
                      Text(
                        'How to play',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: cardTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildIntroSample(isDark),
                  const SizedBox(height: 18),
                  _buildIntroBullet(
                    Icons.help_outline_rounded,
                    'Read the question above the word',
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildIntroBullet(
                    Icons.touch_app_rounded,
                    'Tap the color button that answers it',
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildIntroBullet(
                    Icons.timer_outlined,
                    'Answer fast — a wrong tap costs a life',
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildIntroBullet(
                    Icons.rocket_launch_rounded,
                    'Speed increases as you play — new colors & rules unlock!',
                    isDark,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: _StartButton(onTap: _startGame),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroSample(bool isDark) {
    const inkColor = Color(0xFF3B82F6);
    const inkName = 'BLUE';
    const wordName = 'RED';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            inkColor.withValues(alpha: isDark ? 0.20 : 0.14),
            (isDark ? const Color(0xFF151D1E) : Colors.white).withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFA855F7).withValues(alpha: isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFA855F7).withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.palette_rounded, size: 13, color: Color(0xFFA855F7)),
                const SizedBox(width: 6),
                Text(
                  'Which is the INK color?',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _introPulse,
            builder: (context, child) {
              final scale = 1 + _introPulse.value * 0.05;
              return Transform.scale(scale: scale, child: child);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  wordName,
                  style: GoogleFonts.montserrat(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: inkColor,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: inkColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      inkName,
                      style: GoogleFonts.montserrat(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: inkColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                    boxShadow: [
                      BoxShadow(color: inkColor.withValues(alpha: 0.5), blurRadius: 14),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: inkColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        inkName,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                      width: 1.4,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'RED',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'answer is BLUE — tap it before time runs out!',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIntroBullet(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Pause overlay
  // ---------------------------------------------------------------------------
  Widget _buildPauseOverlay(bool isDark) {
    final cardText = isDark ? Colors.white : AppColors.textPrimaryLight;
    final cardTertiary = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.62),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Container(
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
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
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
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.12),
                      border: Border.all(color: AppColors.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 26,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.pause_rounded,
                      color: AppColors.primary,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'PAUSED',
                    style: GoogleFonts.montserrat(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      color: cardText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The clock is frozen — take a breath.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cardTertiary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _togglePause,
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      label: const Text(
                        'RESUME',
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _playAgain,
                    child: Text(
                      'RESTART',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cardTertiary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'EXIT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cardTertiary,
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

  // ---------------------------------------------------------------------------
  // Result overlay
  // ---------------------------------------------------------------------------
  Widget _buildResultOverlay(bool isDark) {
    final rank = _rankInfo(_score);
    final cardText = isDark ? Colors.white : AppColors.textPrimaryLight;
    final cardTertiary = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.75),
          child: Stack(
            children: [
            if (_isNewBest)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _confetti,
                    builder: (context, _) => CustomPaint(
                      painter: _ConfettiPainter(
                        progress: _confetti.value,
                        colors: _confettiColors,
                      ),
                    ),
                  ),
                ),
              ),
            Center(
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
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
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
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.close_rounded,
                              size: 22,
                              color: cardTertiary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.12),
                          border: Border.all(color: AppColors.primary, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 26,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.emoji_events_rounded,
                          color: AppColors.primary,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              rank.color.withValues(alpha: isDark ? 0.22 : 0.14),
                              rank.color.withValues(alpha: isDark ? 0.08 : 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: rank.color.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(rank.icon, size: 13, color: rank.color),
                            const SizedBox(width: 6),
                            Text(
                              rank.label,
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                                color: rank.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_isNewBest) ...[
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.4, end: 1),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFBBF24).withValues(alpha: 0.55),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Text(
                              '🎉 NEW HIGH SCORE!',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: _score.toDouble()),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => Text(
                          '${value.round()}',
                          style: GoogleFonts.montserrat(
                            fontSize: 58,
                            fontWeight: FontWeight.w900,
                            color: cardText,
                          ),
                        ),
                      ),
                      Text(
                        'POINTS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: cardTertiary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildResultStat(
                                    'ACCURACY',
                                    '${_accuracy.toStringAsFixed(0)}%',
                                    Icons.ads_click_rounded,
                                    const Color(0xFF3B82F6),
                                    isDark,
                                  ),
                                ),
                                Expanded(
                                  child: _buildResultStat(
                                    'AVG TAP',
                                    '${_avgReactionSeconds.toStringAsFixed(2)}s',
                                    Icons.bolt_rounded,
                                    const Color(0xFFFBBF24),
                                    isDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Divider(
                              height: 1,
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildResultStat(
                                    'BEST STREAK',
                                    '$_bestStreak',
                                    Icons.local_fire_department_rounded,
                                    const Color(0xFFF97316),
                                    isDark,
                                  ),
                                ),
                                Expanded(
                                  child: _buildResultStat(
                                    'SPEED BONUS',
                                    '+$_totalSpeedPoints',
                                    Icons.rocket_launch_rounded,
                                    AppColors.success,
                                    isDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!_reviveUsed) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.tonalIcon(
                            onPressed: _reviving ? null : _offerExtraLife,
                            icon: _reviving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.play_circle_fill_rounded, size: 20),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.28 : 0.14),
                              foregroundColor: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.45 : 0.35),
                                ),
                              ),
                              elevation: 0,
                            ),
                            label: const Text(
                              'WATCH AD FOR EXTRA LIFE',
                              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.4, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: FilledButton.icon(
                                onPressed: _shareScore,
                                icon: const Icon(Icons.share_rounded, size: 18),
                                style: FilledButton.styleFrom(
                                  backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                                  foregroundColor: cardText,
                                  side: BorderSide(
                                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                label: const Text(
                                  'SHARE',
                                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
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
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                label: const Text(
                                  'PLAY AGAIN',
                                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  static const List<Color> _confettiColors = [
    AppColors.primary,
    AppColors.secondary,
    Color(0xFFFBBF24),
    AppColors.success,
    Color(0xFF3B82F6),
    Color(0xFFF43F5E),
  ];

  ({String label, Color color, IconData icon}) _rankInfo(int score) {
    if (score >= 300) {
      return (
        label: 'STROOP LEGEND',
        color: const Color(0xFFFBBF24),
        icon: Icons.military_tech_rounded,
      );
    }
    if (score >= 220) {
      return (
        label: 'INSANE MODE',
        color: AppColors.secondary,
        icon: Icons.flash_on_rounded,
      );
    }
    if (score >= 150) {
      return (
        label: 'SPEED DEMON',
        color: AppColors.success,
        icon: Icons.bolt_rounded,
      );
    }
    if (score >= 100) {
      return (
        label: 'SHARP SHOOTER',
        color: AppColors.info,
        icon: Icons.gps_fixed_rounded,
      );
    }
    if (score >= 60) {
      return (
        label: 'WARM UP',
        color: AppColors.warning,
        icon: Icons.trending_up_rounded,
      );
    }
    if (score >= 30) {
      return (
        label: 'GETTING THERE',
        color: const Color(0xFFF97316),
        icon: Icons.rocket_launch_rounded,
      );
    }
    return (
      label: 'KEEP GOING',
      color: AppColors.error,
      icon: Icons.flag_rounded,
    );
  }

  Widget _buildResultStat(
    String label,
    String value,
    IconData icon,
    Color accent,
    bool isDark,
  ) {
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final tertiary = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(height: 5),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: tertiary,
          ),
        ),
      ],
    );
  }
}

class _FloatingScore {
  _FloatingScore(this.controller, this.text, this.color);

  final AnimationController controller;
  final String text;
  final Color color;
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
    required this.alpha,
  });

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: alpha),
            blurRadius: 90,
            spreadRadius: 30,
          ),
        ],
      ),
    );
  }
}

class _TimerRingPainter extends CustomPainter {
  _TimerRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    this.glow = false,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    if (glow) {
      final glowArc = Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 1.8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawArc(rect, -pi / 2, progress * 2 * pi, false, glowArc);
    }

    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -pi / 2, progress * 2 * pi, false, arc);
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.glow != glow;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.colors});

  final double progress;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(7);
    final fallSpan = size.height + 80;
    for (var i = 0; i < 64; i++) {
      final seedX = rng.nextDouble() * size.width;
      final seedY = rng.nextDouble() * size.height;
      final speed = 0.6 + rng.nextDouble() * 1.0;
      final drift = sin(progress * pi * 2 + i) * 18;
      final x = seedX + drift;
      final y = (seedY + progress * fallSpan * speed) % fallSpan - 40;
      final w = 6 + rng.nextDouble() * 6;
      final h = 4 + rng.nextDouble() * 6;
      final rotation = rng.nextDouble() * pi * 2 + progress * (rng.nextBool() ? 8 : -8);
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: 0.7 + rng.nextDouble() * 0.3);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-w / 2, -h / 2, w, h),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _StartButton extends StatefulWidget {
  const _StartButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 90),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryLight, AppColors.primary],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'START',
                style: GoogleFonts.montserrat(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorOption extends StatefulWidget {
  const _ColorOption({
    required this.name,
    required this.color,
    required this.isDark,
    required this.enabled,
    required this.onTap,
    this.compact = false,
  });

  final String name;
  final Color color;
  final bool isDark;
  final bool enabled;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_ColorOption> createState() => _ColorOptionState();
}

class _ColorOptionState extends State<_ColorOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final base = widget.color;
    final isDark = widget.isDark;
    final compact = widget.compact;
    final height = compact ? 58.0 : 74.0;
    final fontSize = compact ? 16.0 : 20.0;

    final Color fillTop;
    final Color fillBottom;
    if (isDark) {
      fillTop = Color.lerp(const Color(0xFF31445F), base, _pressed ? 0.20 : 0.04)!;
      fillBottom = Color.lerp(const Color(0xFF0C1420), base, _pressed ? 0.30 : 0.08)!;
    } else {
      fillTop = Color.lerp(const Color(0xFF3B4A5E), base, _pressed ? 0.16 : 0.03)!;
      fillBottom = Color.lerp(const Color(0xFF18212C), base, _pressed ? 0.24 : 0.06)!;
    }

    return Opacity(
      opacity: widget.enabled ? 1 : 0.45,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: widget.enabled
              ? (_) {
                  setState(() => _pressed = false);
                  widget.onTap();
                }
              : null,
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [fillTop, fillBottom],
              ),
              borderRadius: BorderRadius.circular(compact ? 22 : 26),
              border: Border.all(
                color: Colors.white.withValues(alpha: _pressed ? 0.35 : 0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.18),
                  blurRadius: _pressed ? 8 : 18,
                  offset: Offset(0, _pressed ? 3 : 9),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: height * 0.45,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: _pressed ? 0.10 : 0.16),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: height * 0.22,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0),
                          Colors.black.withValues(alpha: isDark ? 0.30 : 0.16),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: GoogleFonts.montserrat(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 6),
                            Shadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 14),
                          ],
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
    );
  }
}
