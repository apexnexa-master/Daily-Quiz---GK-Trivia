// lib/presentation/screens/battle_screen.dart
// Battle Mode - 1v1 Quiz Battles

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/gamification_models.dart';
import '../../data/models/firestore_models.dart';
import '../../data/local_quiz_data.dart';

class BattleScreen extends ConsumerStatefulWidget {
  const BattleScreen({super.key});

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen> {
  bool _isSearching = true;
  bool _isBattleActive = false;
  int _playerScore = 0;
  int _opponentScore = 0;
  int _currentQuestion = 0;
  int _totalQuestions = 5;
  List<QuestionModel> _questions = [];
  int? _selectedAnswer;
  bool _isAnswered = false;
  Timer? _searchTimer;
  Timer? _opponentTimer;

  @override
  void initState() {
    super.initState();
    _startSearch();
  }

  void _startSearch() {
    _searchTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted && _isSearching) {
        setState(() {
          _isSearching = false;
          _isBattleActive = true;
          _questions =
              LocalQuizData.getAllQuestionsForMode('GENERAL').take(5).toList();
        });
        _startOpponentSimulation();
      }
    });
  }

  void _startOpponentSimulation() {
    _opponentTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _isBattleActive && !_isAnswered) {
        setState(() {
          _opponentScore += Random().nextInt(2);
        });
      }
    });
  }

  void _onAnswerSelected(int index) {
    if (_isAnswered) return;

    setState(() {
      _selectedAnswer = index;
      _isAnswered = true;
    });

    if (_selectedAnswer == _questions[_currentQuestion].correctIndex) {
      setState(() {
        _playerScore += 1;
      });
      _addXP(20);
    }

    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        if (_currentQuestion < _totalQuestions - 1) {
          setState(() {
            _currentQuestion++;
            _selectedAnswer = null;
            _isAnswered = false;
          });
        } else {
          _endBattle();
        }
      }
    });
  }

  void _addXP(int xp) {
    ref.read(gamificationNotifierProvider.notifier).addXP(xp);
  }

  void _endBattle() {
    setState(() {
      _isBattleActive = false;
    });
    _opponentTimer?.cancel();
    _showResultDialog();
  }

  void _showResultDialog() {
    final isWin = _playerScore > _opponentScore;
    final isDraw = _playerScore == _opponentScore;
    final lang = ref.read(languageProvider);
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1B4B)
            : Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isWin
                  ? '🏆'
                  : isDraw
                      ? '🤝'
                      : '💪',
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              isWin
                  ? 'Victory!'
                  : isDraw
                      ? 'Draw!'
                      : 'Keep Trying!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: isWin
                    ? AppTheme.successColor
                    : isDraw
                        ? AppTheme.warningColor
                        : AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildScoreColumn('You', _playerScore, AppTheme.primaryColor),
                Text(
                  'vs',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white54
                        : Colors.grey,
                  ),
                ),
                _buildScoreColumn(
                    'Opponent', _opponentScore, AppTheme.errorColor),
              ],
            ),
            const SizedBox(height: 24),
            if (isWin) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: AppTheme.warningColor),
                    const SizedBox(width: 8),
                    Text(
                      '+${_playerScore * 20} XP',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: const Text('Exit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _isSearching = true;
                        _isBattleActive = false;
                        _playerScore = 0;
                        _opponentScore = 0;
                        _currentQuestion = 0;
                        _selectedAnswer = null;
                        _isAnswered = false;
                      });
                      _startSearch();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Rematch'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _opponentTimer?.cancel();
    super.dispose();
  }

  Widget _buildScoreColumn(String label, int score, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$score',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(languageProvider);
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF8FAFC), Color(0xFFEEF2FF)],
                ),
        ),
        child: SafeArea(
          child: _isSearching
              ? _buildSearchingState(isDark, isBn, isHi)
              : _buildBattleState(isDark, isBn, isHi),
        ),
      ),
    );
  }

  Widget _buildSearchingState(bool isDark, bool isBn, bool isHi) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back_rounded,
                    color: isDark ? Colors.white : Colors.black),
              ),
              Text(
                isBn
                    ? 'Battle Mode'
                    : isHi
                        ? 'बैटल मोड'
                        : 'Battle Mode',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                    valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  isBn
                      ? 'খোঁজা হচ্ছে...'
                      : isHi
                          ? 'खोज रहा है...'
                          : 'Finding opponent...',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isBn
                      ? 'একজন প্রতিপক্ষ খুঁজছি'
                      : isHi
                          ? 'प्रतिद्वंद्वी खोज रहा है'
                          : 'Looking for a worthy opponent',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBattleState(bool isDark, bool isBn, bool isHi) {
    if (_questions.isEmpty) return const SizedBox();

    final lang = ref.read(languageProvider);

    final question = _questions[_currentQuestion];
    final questionText = question.getText(lang);
    final options = question.getOptions(lang);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _BattleScoreBar(
                  label: isBn
                      ? 'আপনি'
                      : isHi
                          ? 'आप'
                          : 'You',
                  score: _playerScore,
                  color: AppTheme.primaryColor,
                  isDark: isDark,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentQuestion + 1}/${_totalQuestions}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Expanded(
                child: _BattleScoreBar(
                  label: isBn
                      ? 'প্রতিপক্ষ'
                      : isHi
                          ? 'प्रतिद्वंद्वी'
                          : 'Opponent',
                  score: _opponentScore,
                  color: AppTheme.errorColor,
                  isDark: isDark,
                  isRight: true,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    questionText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ...List.generate(
                    options.length,
                    (i) => _BattleOptionTile(
                          index: i,
                          text: options[i],
                          isSelected: _selectedAnswer == i,
                          isCorrect: _isAnswered && i == question.correctIndex,
                          isWrong: _isAnswered &&
                              _selectedAnswer == i &&
                              i != question.correctIndex,
                          isDark: isDark,
                          onTap:
                              _isAnswered ? null : () => _onAnswerSelected(i),
                        )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BattleScoreBar extends StatelessWidget {
  final String label;
  final int score;
  final Color color;
  final bool isDark;
  final bool isRight;

  const _BattleScoreBar({
    required this.label,
    required this.score,
    required this.color,
    required this.isDark,
    this.isRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            '$score',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _BattleOptionTile extends StatelessWidget {
  final int index;
  final String text;
  final bool isSelected;
  final bool isCorrect;
  final bool isWrong;
  final bool isDark;
  final VoidCallback? onTap;

  const _BattleOptionTile({
    required this.index,
    required this.text,
    required this.isSelected,
    required this.isCorrect,
    required this.isWrong,
    required this.isDark,
    this.onTap,
  });

  static const _labels = ['A', 'B', 'C', 'D'];
  static const _colors = [
    Color(0xFF6366F1),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];

  @override
  Widget build(BuildContext context) {
    Color getColor() {
      if (isCorrect) return AppTheme.successColor;
      if (isWrong) return AppTheme.errorColor;
      if (isSelected) return _colors[index];
      return isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: getColor().withValues(
              alpha: isSelected || isCorrect || isWrong ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: getColor().withValues(alpha: 0.3),
            width: isSelected || isCorrect || isWrong ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected || isCorrect || isWrong
                    ? getColor()
                    : _colors[index].withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _labels[index],
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isSelected || isCorrect || isWrong
                      ? Colors.white
                      : _colors[index],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            if (isCorrect)
              const Icon(Icons.check_circle, color: AppTheme.successColor),
            if (isWrong) const Icon(Icons.cancel, color: AppTheme.errorColor),
          ],
        ),
      ),
    );
  }
}
