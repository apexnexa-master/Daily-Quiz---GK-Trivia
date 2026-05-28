// lib/core/services/sharing_service.dart
// Social sharing service for scorecards and challenges

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';

class SharingService {
  static final SharingService instance = SharingService._();
  SharingService._();

  Future<void> shareScoreCard({
    required int score,
    required int total,
    required String examMode,
    required String timeTaken,
    required String userName,
    String? referralCode,
  }) async {
    final percentage = ((score / total) * 100).toInt();
    final emoji = _getResultEmoji(percentage);

    final text = '''
🎯 **GK Quiz Results**

📚 Exam: $examMode
✅ Score: $score/$total ($percentage%)
⏱️ Time: $timeTaken

$emoji ${_getResultMessage(percentage)}

${referralCode != null ? '🎁 Use my referral code: $referralCode\n' : ''}
📲 Download GK Quiz App: https://play.google.com/store/apps/details?id=com.gkquiz.app
''';

    await Share.share(text, subject: '🎯 My GK Quiz Score!');
  }

  Future<void> shareChallenge({
    required int score,
    required int total,
    required String examMode,
    required String challengeId,
  }) async {
    final percentage = ((score / total) * 100).toInt();

    final text = '''
⚔️ **GK Quiz Challenge!**

📚 Exam: $examMode
✅ I scored $score/$total ($percentage%)

Can you beat my score? 🤔

🔥 Take the challenge:
https://gkquiz.app/challenge/$challengeId
''';

    await Share.share(text, subject: '⚔️ Beat my Quiz Score!');
  }

  Future<void> shareStreak({
    required int streak,
    required String longestStreak,
  }) async {
    final text = '''
🔥 **I'm on a roll!** 

📈 Current Streak: $streak days
🏆 Longest Streak: $longestStreak days

💪 Taking GK Quiz daily! Join me!
📲 https://play.google.com/store/apps/details?id=com.gkquiz.app
''';

    await Share.share(text, subject: '🔥 My GK Quiz Streak!');
  }

  Future<void> shareAchievement({
    required String title,
    required String icon,
  }) async {
    final text = '''
🏆 **Achievement Unlocked!** 

$icon $title

I'm crushing it on GK Quiz! 🚀
📲 https://play.google.com/store/apps/details?id=com.gkquiz.app
''';

    await Share.share(text, subject: '🏆 Achievement Unlocked!');
  }

  Future<void> shareLevelUp({
    required int newLevel,
  }) async {
    final text = '''
⭐ **Level Up!** 

I just reached Level $newLevel on GK Quiz!

🎯 Take daily quizzes and level up!
📲 https://play.google.com/store/apps/details?id=com.gkquiz.app
''';

    await Share.share(text, subject: '⭐ I just Leveled Up!');
  }

  Future<void> inviteFriends({
    required String referralCode,
  }) async {
    final text = '''
🎁 **Invite & Earn!**

Join GK Quiz using my referral code and get 50 🪙 coins!

 code: $referralCode

📲 Download: https://play.google.com/store/apps/details?id=com.gkquiz.app
''';

    await Share.share(text, subject: '🎁 Join GK Quiz with me!');
  }

  String _getResultEmoji(int percentage) {
    if (percentage >= 90) return '🏆';
    if (percentage >= 70) return '🎉';
    if (percentage >= 50) return '👍';
    return '💪';
  }

  String _getResultMessage(int percentage) {
    if (percentage >= 90) return 'Outstanding! You\'re a GK Master!';
    if (percentage >= 70) return 'Great job! Keep it up!';
    if (percentage >= 50) return 'Good effort! Practice more!';
    return 'Keep trying! You\'ll get better!';
  }
}

class ShareableScoreCard extends StatelessWidget {
  final int score;
  final int total;
  final String examMode;
  final String timeTaken;
  final bool isDark;

  const ShareableScoreCard({
    super.key,
    required this.score,
    required this.total,
    required this.examMode,
    required this.timeTaken,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = ((score / total) * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🎯',
            style: TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 8),
          Text(
            'GK Quiz',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              examMode,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '$score/$total',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text(
                timeTaken,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
