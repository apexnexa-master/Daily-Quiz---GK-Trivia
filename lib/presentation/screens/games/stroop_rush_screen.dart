// lib/presentation/screens/games/stroop_rush_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';

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

  static const List<String> _names = ['RED', 'BLUE', 'GREEN', 'YELLOW', 'PURPLE'];
  static const List<Color> _values = [
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFEAB308),
    Color(0xFFA855F7),
  ];

  final Random _rng = Random();
  late final AnimationController _timer;
  late final AnimationController _shake;
  late final AnimationController _confetti;
  late final AnimationController _ambient;

  String _text = 'RED';
  Color _ink = _values[0];
  int _textIndex = 0;
  int _inkIndex = 0;
  _StroopRule _rule = _StroopRule.tapInk;
  int _correctIdx = 0;
  int _distractorIdx = 1;
  bool _correctOnLeft = true;

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

  bool _intro = true;
  bool _playing = false;
  bool _paused = false;
  bool _finished = false;
  bool _answering = false;
  bool _flashCorrect = false;
  bool _flashWrong = false;

  bool _ruleJustChanged = false;
  bool _ruleFlash = false;
  bool _isNewBest = false;

  final List<_FloatingScore> _floaters = [];
  SharedPreferences? _prefs;

  int get _leftIdx => _correctOnLeft ? _correctIdx : _distractorIdx;
  int get _rightIdx => _correctOnLeft ? _distractorIdx : _correctIdx;

  int get _speedPips =>
      1 + (((_baseTurnSeconds - _turnSeconds) / (_baseTurnSeconds - _minTurnSeconds)) * 4).round().clamp(0, 4);

  double get _avgReactionSeconds =>
      _correct == 0 ? 0 : (_totalReactionMs / _correct) / 1000;

  double get _comboMultiplier {
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
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
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
    _ambient.dispose();
    for (final floater in _floaters) {
      floater.controller.dispose();
    }
    super.dispose();
  }

  _StroopRule _pickRule() {
    if (_correct < 6) return _StroopRule.tapInk;
    final swap = _rng.nextBool();
    return swap
        ? (_rule == _StroopRule.tapInk ? _StroopRule.tapWord : _StroopRule.tapInk)
        : _rule;
  }

  void _nextTurn() {
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

  void _submitAnswer({required bool left}) {
    if (!_playing || _answering || _finished) return;
    _answering = true;
    final remaining = 1 - _timer.value;
    _timer.stop();

    if (left == _correctOnLeft) {
      _totalReactionMs += ((_turnSeconds - remaining * _turnSeconds) * 1000).round();
      _correct++;
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;
      final speedPoints = (remaining * 6).round();
      final earned = ((10 + speedPoints) * _comboMultiplier).round();
      _score += earned;
      final reactionSeconds = (1 - remaining) * _turnSeconds;
      _updateTurnDuration(reactionSeconds);
      HapticFeedback.lightImpact();
      setState(() => _flashCorrect = true);
      _spawnFloater('$earned', AppColors.success);
      Future<void>.delayed(const Duration(milliseconds: 130), () {
        if (!mounted) return;
        setState(() {
          _flashCorrect = false;
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
    HapticFeedback.heavyImpact();
    _turnSeconds = (_turnSeconds + 0.4).clamp(_minTurnSeconds, _baseTurnSeconds);
    _timer.duration = Duration(milliseconds: (_turnSeconds * 1000).round());
    setState(() {
      _flashWrong = true;
      _lives--;
      _streak = 0;
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
      _turnSeconds = _baseTurnSeconds;
      _timer.duration = Duration(milliseconds: (_turnSeconds * 1000).round());
      _intro = false;
      _playing = true;
      _paused = false;
      _finished = false;
      _answering = false;
      _flashCorrect = false;
      _flashWrong = false;
      _isNewBest = false;
      _ruleFlash = false;
      _ruleJustChanged = false;
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
                SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(isDark),
                      _buildStatsRow(isDark),
                      _buildTimerBar(isDark),
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
          if (_ruleFlash) _buildRuleFlashOverlay(isDark),
          if (_intro) _buildIntroOverlay(isDark),
          if (_paused && !_finished) _buildPauseOverlay(isDark),
          if (_finished) _buildResultOverlay(isDark),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Background
  // ---------------------------------------------------------------------------
  Widget _buildGlowDots(bool isDark) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ambient,
        builder: (context, _) {
          final t = _ambient.value;
          return Stack(
            children: [
              Positioned(
                top: -70 - t * 16,
                right: -70 + t * 14,
                child: Transform.scale(
                  scale: 1 + t * 0.08,
                  child: _GlowOrb(
                    size: 230,
                    color: AppColors.primary,
                    alpha: isDark ? 0.16 : 0.10,
                  ),
                ),
              ),
              Positioned(
                bottom: 40 - t * 10,
                left: -80 + t * 12,
                child: Transform.scale(
                  scale: 1 + (1 - t) * 0.06,
                  child: _GlowOrb(
                    size: 210,
                    color: const Color(0xFFA855F7),
                    alpha: isDark ? 0.16 : 0.08,
                  ),
                ),
              ),
            ],
          );
        },
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
                Text(
                  'STROOP RUSH',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
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
              'SCORE',
              '$_score',
              Icons.bolt_rounded,
              AppColors.primary,
              isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatBox(
              'BEST',
              '$_best',
              Icons.emoji_events_rounded,
              const Color(0xFFECB2FF),
              isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatBox(
              'STREAK',
              '$_streak',
              Icons.local_fire_department_rounded,
              const Color(0xFFF97316),
              isDark,
              trailing: _comboMultiplier > 1 ? 'x$_comboMultiplier' : null,
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.82),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 11, color: accent),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          trailing,
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ],
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

  // ---------------------------------------------------------------------------
  // Timer
  // ---------------------------------------------------------------------------
  Widget _buildTimerBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: AnimatedBuilder(
        animation: _timer,
        builder: (context, _) {
          final remaining = 1 - _timer.value;
          final color = remaining > 0.55
              ? AppColors.success
              : remaining > 0.25
                  ? AppColors.warning
                  : AppColors.error;
          final seconds = (_turnSeconds * remaining).clamp(0.0, _turnSeconds);
          return Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 14,
                    child: Stack(
                      children: [
                        Container(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: remaining.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: LinearGradient(
                                  colors: [color.withValues(alpha: 0.65), color],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 12,
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
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
                ),
                child: Text(
                  '${seconds.toStringAsFixed(1)}s',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Question banner (the question for the current word)
  // ---------------------------------------------------------------------------
  Widget _buildQuestion(bool isDark) {
    final isInk = _rule == _StroopRule.tapInk;
    final accent = isInk ? const Color(0xFFA855F7) : const Color(0xFF3B82F6);
    final text = isInk ? 'Which is the INK color?' : 'Which is the WORD?';

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
        key: ValueKey(text),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: isDark ? 0.26 : 0.16),
              accent.withValues(alpha: isDark ? 0.08 : 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.16 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent.withValues(alpha: 0.9), accent.withValues(alpha: 0.6)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                boxShadow: [
                  BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 12),
                ],
              ),
              child: Icon(
                isInk ? Icons.palette_rounded : Icons.hub_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QUESTION',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
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
  // Word stage (word + ink swatch at similar size)
  // ---------------------------------------------------------------------------
  Widget _buildWordStage(bool isDark) {
    final borderColor = _flashCorrect
        ? AppColors.success
        : _flashWrong
            ? AppColors.error
            : (isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.08));
    final glowColor = _flashCorrect
        ? AppColors.success
        : _flashWrong
            ? AppColors.error
            : _ink;

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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                glowColor.withValues(alpha: isDark ? 0.18 : 0.13),
                (isDark ? const Color(0xFF151D1E) : Colors.white).withValues(alpha: 0.96),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: borderColor,
              width: _flashCorrect || _flashWrong ? 3 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: _flashCorrect || _flashWrong ? 0.45 : 0.14),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildQuestion(isDark),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
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
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: _ink,
                          shadows: [
                            Shadow(color: _ink.withValues(alpha: 0.35), blurRadius: 24),
                            Shadow(color: _ink.withValues(alpha: 0.15), blurRadius: 48),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              _buildRoundHint(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundHint(bool isDark) {
    final tertiary = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    String text;
    IconData icon;
    Color color = tertiary;

    if (_ruleFlash) {
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
  // Answer area (two color options to tap)
  // ---------------------------------------------------------------------------
  Widget _buildAnswerArea(bool isDark) {
    final enabled = _playing && !_answering && !_finished && !_intro && !_paused;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _ColorOption(
              name: _names[_leftIdx],
              color: _values[_leftIdx],
              isDark: isDark,
              enabled: enabled,
              onTap: () => _submitAnswer(left: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ColorOption(
              name: _names[_rightIdx],
              color: _values[_rightIdx],
              isDark: isDark,
              enabled: enabled,
              onTap: () => _submitAnswer(left: false),
            ),
          ),
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
          Row(
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
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.62),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'NEW PERSONAL BEST!',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: AppColors.success,
                              letterSpacing: 0.5,
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildResultStat('CORRECT', '$_correct', isDark),
                            _buildResultStat('BEST STREAK', '$_bestStreak', isDark),
                            _buildResultStat('AVG TAP', '${_avgReactionSeconds.toStringAsFixed(2)}s', isDark),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: _playAgain,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
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
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Exit',
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
          ],
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
    if (score >= 200) {
      return (
        label: 'STROOP LEGEND',
        color: const Color(0xFFFBBF24),
        icon: Icons.military_tech_rounded,
      );
    }
    if (score >= 130) {
      return (
        label: 'INSANE MODE',
        color: AppColors.secondary,
        icon: Icons.flash_on_rounded,
      );
    }
    if (score >= 80) {
      return (
        label: 'SPEEDY',
        color: AppColors.success,
        icon: Icons.bolt_rounded,
      );
    }
    if (score >= 40) {
      return (
        label: 'WARM UP',
        color: AppColors.info,
        icon: Icons.trending_up_rounded,
      );
    }
    return (
      label: 'KEEP GOING',
      color: AppColors.warning,
      icon: Icons.flag_rounded,
    );
  }

  Widget _buildResultStat(String label, String value, bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final tertiary = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return Column(
      children: [
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
  });

  final String name;
  final Color color;
  final bool isDark;
  final bool enabled;
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

    return Opacity(
      opacity: widget.enabled ? 1 : 0.45,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 90),
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
            height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  base.withValues(alpha: isDark ? 0.30 : 0.24),
                  base.withValues(alpha: isDark ? 0.14 : 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: base.withValues(alpha: _pressed ? 0.95 : 0.55),
                width: _pressed ? 2.2 : 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: base.withValues(alpha: isDark ? 0.30 : 0.22),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: base,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 2),
                    boxShadow: [
                      BoxShadow(color: base.withValues(alpha: 0.6), blurRadius: 14),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.name,
                  style: GoogleFonts.montserrat(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: base,
                    shadows: [
                      Shadow(color: base.withValues(alpha: 0.4), blurRadius: 10),
                    ],
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
