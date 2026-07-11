// lib/core/constants/app_constants.dart
import 'dart:io';

class AppConstants {
  AppConstants._();

  // ── App Info ──────────────────────────────────────────────
  static const String appName = 'Daily Quiz - GK & Trivia';
  static const String appPackage = 'com.nexasoft.dailyquiz';
  static const int quizQuestionCount = 10;
  static const int questionTimerSeconds = 15;
  static const int maxInterstitialsPerSession = 3;

  // ── Firestore Collections ─────────────────────────────────
  static const String colUsers = 'users';
  static const String colQuizzes = 'quizzes';
  static const String colQuestions = 'questions';
  static const String colAttempts = 'attempts';
  static const String colStreaks = 'streaks';
  static const String colLeaderboard = 'leaderboard';
  static const String colChallenges = 'challenges';

  // ── Hive Box Names ────────────────────────────────────────
  static const String hiveBoxQuiz = 'quiz_cache';
  static const String hiveBoxUser = 'user_prefs';
  static const String hiveKeyLanguage = 'selected_language';
  static const String hiveKeyIsPro = 'is_pro';

  /// Best correct answers in a single completed quiz (same `outOf` for fair compare).
  static const String hiveKeyHighScore = 'personal_best_score';
  static const String hiveKeyHighScoreOutOf = 'personal_best_out_of';

  // ── SharedPreferences Keys ────────────────────────────────
  static const String prefLanguage = 'lang';
  static const String prefThemeMode = 'theme_mode';
  static const String prefOnboardingDone = 'onboarding_done';

  // ── AdMob Unit IDs ────────────────────────────────────────
  // IMPORTANT: Replace test IDs with real IDs before release.
  static String get admobAppId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544~3347511713'; // TEST
    }
    return 'ca-app-pub-3940256099942544~1458002511'; // TEST iOS
  }

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // TEST banner
    }
    return 'ca-app-pub-3940256099942544/2934735716';
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // TEST interstitial
    }
    return 'ca-app-pub-3940256099942544/4411468910';
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // TEST rewarded
    }
    return 'ca-app-pub-3940256099942544/1712485313';
  }

  // ── Disclaimer & Attribution ─────────────────────────────
  static const String disclaimerText =
      'This app is not affiliated with, endorsed by, or connected to any '
      'government entity, including UPSC, SSC, WBPSC, or any other '
      'government organization. All content is for educational purposes only.';

  static const String sourceAttribution =
      'Quiz content is sourced from publicly available government publications '
      'including NCERT textbooks (ncert.nic.in), the National Portal of India '
      '(india.gov.in), and official government exam syllabi.';

  static const String sourceUrl = 'https://ncert.nic.in';

  // ── Deep Link Base ────────────────────────────────────────
  static const String deepLinkBase = 'https://dailyquiz.page.link';
  static const String appLinksDomain = 'dailyquiz.nexasoft.com';

  // ── Supported Locales ─────────────────────────────────────
  static const List<String> supportedLanguages = ['en', 'hi', 'bn'];
  static const String defaultLanguage = 'en'; // English first
}
