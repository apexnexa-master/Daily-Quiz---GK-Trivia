// lib/core/services/quiz/quiz_timing_manager.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuizTimingManager {
  QuizTimingManager._();
  static final QuizTimingManager instance = QuizTimingManager._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _lastQuizDateKey = 'last_quiz_date';

  int _quizStartHour = 6;
  int _quizStartMinute = 0;
  int _quizEndHour = 23;
  int _quizEndMinute = 59;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(seconds: 30);

  int get quizStartHour => _quizStartHour;
  int get quizStartMinute => _quizStartMinute;
  int get quizEndHour => _quizEndHour;
  int get quizEndMinute => _quizEndMinute;

  Future<void> refreshTiming() async {
    try {
      final doc = await _db.collection('settings').doc('quiz_timing').get();
      if (doc.exists) {
        final data = doc.data()!;
        _quizStartHour = data['start_hour'] ?? 6;
        _quizStartMinute = data['start_minute'] ?? 0;
        _quizEndHour = data['end_hour'] ?? 23;
        _quizEndMinute = data['end_minute'] ?? 59;
      }
    } catch (_) {}
    _lastFetchTime = DateTime.now();
  }

  void ensureTimingFresh() {
    if (_lastFetchTime == null ||
        DateTime.now().difference(_lastFetchTime!) > _cacheDuration) {
      _lastFetchTime = DateTime.now();
      refreshTiming();
    }
  }

  bool isQuizActive() {
    ensureTimingFresh();
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = _quizStartHour * 60 + _quizStartMinute;
    final endMinutes = _quizEndHour * 60 + _quizEndMinute;
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  bool canShowAnswers() {
    ensureTimingFresh();
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final endMinutes = _quizEndHour * 60 + _quizEndMinute;
    return currentMinutes > endMinutes;
  }

  Future<bool> isNewQuizAvailable() async {
    ensureTimingFresh();
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(_lastQuizDateKey);

    return lastDate != today || now.hour >= _quizStartHour;
  }

  Duration getTimeUntilNextQuiz() {
    final now = DateTime.now();
    var nextQuiz = DateTime(
        now.year, now.month, now.day, _quizStartHour, _quizStartMinute);

    if (now.hour > _quizStartHour ||
        (now.hour == _quizStartHour && now.minute >= _quizStartMinute)) {
      nextQuiz = nextQuiz.add(const Duration(days: 1));
    }

    return nextQuiz.difference(now);
  }

  String getCountdownString() {
    ensureTimingFresh();
    final duration = getTimeUntilNextQuiz();

    if (duration.isNegative) {
      return 'Quiz available now!';
    }

    if (!isQuizActive()) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      if (hours > 0) {
        return 'Quiz starts in ${hours}h ${minutes}m';
      } else {
        return 'Quiz starts in ${minutes}m';
      }
    }

    final endTime = DateTime.now();
    var endDateTime = DateTime(
        endTime.year, endTime.month, endTime.day, _quizEndHour, _quizEndMinute);
    if (endDateTime.isBefore(endTime)) {
      endDateTime = endDateTime.add(const Duration(days: 1));
    }
    final remaining = endDateTime.difference(endTime);

    if (canShowAnswers()) {
      return 'Quiz ended - Answers available';
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) {
      return 'Quiz ends in ${hours}h ${minutes}m';
    } else {
      return 'Quiz ends in ${minutes}m';
    }
  }
}
