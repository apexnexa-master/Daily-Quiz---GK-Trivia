// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_manager.dart';
import 'core/services/ad_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/local_stats_service.dart';
import 'core/services/question_tracking_service.dart';
import 'core/services/gamification_service.dart';
import 'core/services/cloud_sync_service.dart';
import 'core/services/bookmark_service.dart';
import 'core/utils/offline_manager.dart';
import 'presentation/providers/app_providers.dart';
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

  await Hive.initFlutter();
  await Hive.openBox<String>(AppConstants.hiveBoxQuiz);
  await Hive.openBox<String>(AppConstants.hiveBoxUser);

  OfflineManager.instance.init();

  await Future.wait([
    LocalStatsService.instance.init(),
    QuestionTrackingService.instance.init(),
    AdService.instance.initialize(),
    GamificationService.instance.init(),
    CloudSyncService.instance.init(),
    BookmarkService().init(),
    LocalQuizData.init(),
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initNotifications() async {
    try {
      final auth = ref.read(authServiceProvider);
      await NotificationService.instance.initialize(auth);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isProAsync = ref.watch(isProProvider);
    final themeMode = ref.watch(themeModeProvider);

    isProAsync.whenData((isPro) => AdService.instance.setProStatus(isPro));

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _getThemeMode(themeMode),
      navigatorKey: AppRouter.navigatorKey,
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: AppRouter.splash,
      themeAnimationDuration: const Duration(milliseconds: 280),
      themeAnimationCurve: Curves.easeOutCubic,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('bn')],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
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
