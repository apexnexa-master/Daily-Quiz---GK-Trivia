// lib/main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_manager.dart';
import 'core/services/ad_service.dart';
import 'core/services/update_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/local_stats_service.dart';
import 'core/services/question_tracking_service.dart';
import 'core/services/gamification_service.dart';
import 'core/services/cloud_sync_service.dart';
import 'core/services/daily_challenge_submission_service.dart';
import 'core/services/daily_progress_service.dart';
import 'core/services/game_sfx.dart';
import 'core/services/analytics_service.dart';
import 'core/services/quiz/practice_quiz_service.dart';
import 'core/scoring/daily_challenge_service.dart';
import 'core/scoring/progression_service.dart';
import 'core/utils/offline_manager.dart';
import 'core/utils/app_logger.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/utils/account_linker.dart';
import 'routes/app_router.dart';
import 'firebase_options.dart';
import 'data/local_quiz_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await DailyChallengeService.instance.initialize();

  await Hive.initFlutter();
  await Hive.openBox<String>(AppConstants.hiveBoxQuiz);
  await Hive.openBox<String>(AppConstants.hiveBoxUser);
  // NOTE: do not wipe the quiz cache on every launch. Cache keys are
  // date-scoped (`quiz_yyyy-MM-dd_MODE`), so stale entries are never read and
  // keeping them enables instant, offline-friendly cold starts.

  OfflineManager.instance.init();

  await Future.wait([
    LocalStatsService.instance.init(),
    QuestionTrackingService.instance.init(),
    AdService.instance.initialize(),
    GamificationService.instance.init(),
    CloudSyncService.instance.init(),
    DailyProgressService.instance.init(),
    GameSfxService.instance.init(),
    ProgressionService.instance.init(),
    LocalQuizData.init(),
    PracticeQuizService.instance.init(),
  ]);

  runApp(
    const ProviderScope(
      child: GkQuizApp(),
    ),
  );
}

class GkQuizApp extends ConsumerStatefulWidget {
  const GkQuizApp({super.key});
  @override
  ConsumerState<GkQuizApp> createState() => _GkQuizAppState();
}

class _GkQuizAppState extends ConsumerState<GkQuizApp>
    with WidgetsBindingObserver {
  StreamSubscription<bool>? _scorePromptSubscription;
  StreamSubscription<User?>? _authSubscription;
  Timer? _scorePromptTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService.instance.logAppOpen();
    _initNotifications();
    UpdateService.instance.checkForUpdates();
    _scorePromptSubscription = DailyChallengeSubmissionService.instance
        .signInPromptStream
        .listen((show) {
      if (show) _showScoreSubmissionPrompt();
    });
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null || user.isAnonymous) return;
      final submitted = await DailyChallengeSubmissionService.instance
          .flushPending();
      if (submitted > 0 && mounted) {
        ref.invalidate(localLeaderboardProvider);
      }
    });
  }

  @override
  void dispose() {
    _scorePromptSubscription?.cancel();
    _authSubscription?.cancel();
    _scorePromptTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _showScoreSubmissionPrompt() {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final lang = ref.read(languageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final message = isBn
        ? 'স্কোর সংরক্ষিত। জমা দিতে লগইন করুন।'
        : isHi
            ? 'स्कोर सेव हो गया। जमा करने के लिए लॉगिन करें।'
            : 'Score saved. Sign in to submit it.';
    final actionLabel =
        isBn ? 'লগইন করুন' : isHi ? 'लॉगिन करें' : 'Sign in';

    _scorePromptTimer?.cancel();
    _scorePromptTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: isDark ? AppColors.cardDark : Colors.white,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
          content: Row(
            children: [
              const Icon(Icons.cloud_upload_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: actionLabel,
            textColor: AppColors.primary,
            onPressed: () {
              messenger.hideCurrentSnackBar();
              if (context.mounted) AccountLinker.linkAccount(context, ref);
            },
          ),
        ),
      );
    });
  }

  Future<void> _initNotifications() async {
    try {
      final auth = ref.read(authServiceProvider);
      await NotificationService.instance.initialize(auth);
    } catch (e, st) {
      AppLogger.error('Failed to initialize notifications', error: e, stackTrace: st, name: 'GkQuizApp');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProAsync = ref.watch(isProProvider);
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(languageProvider);

    isProAsync.whenData((isPro) => AdService.instance.setProStatus(isPro));

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _getThemeMode(themeMode),
      navigatorKey: AppRouter.navigatorKey,
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: AppRouter.splash,
      themeAnimationDuration: const Duration(milliseconds: 280),
      themeAnimationCurve: Curves.easeOutCubic,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: Locale(language),
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('bn')],
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          // Respect the user's accessibility font size, but cap it so the
          // dense dashboard and game HUDs stay usable.
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  ThemeMode _getThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
