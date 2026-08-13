// lib/routes/app_router.dart
import 'package:flutter/material.dart';
import '../presentation/screens/main_navigation_screen.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/quiz_screen.dart';
import '../presentation/screens/result_screen.dart';
import '../presentation/screens/login_screen.dart';
import '../presentation/screens/leaderboard_screen.dart';
import '../presentation/screens/splash_screen.dart';
import '../presentation/screens/profile_screen.dart';
import '../presentation/screens/battle_screen.dart';
import '../presentation/screens/achievements_screen.dart';
import '../presentation/screens/onboarding_screen.dart';
import '../presentation/screens/feedback_screen.dart';
// Premium screen - not used
// import '../presentation/screens/premium_screen.dart';
import '../presentation/screens/admin_screen.dart';
import '../presentation/screens/games/game_placeholder_screen.dart';
import '../presentation/screens/knowledge_categories_screen.dart';
import '../presentation/screens/games/arrow_escape_game_screen.dart';
import '../presentation/screens/games/stroop_rush_screen.dart';
import '../presentation/workout/workout_screen.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String quiz = '/quiz';
  static const String result = '/result';
  static const String leaderboard = '/leaderboard';
  static const String profile = '/profile';
  static const String battle = '/battle';
  static const String achievements = '/achievements';
  static const String onboarding = '/onboarding';
  static const String feedback = '/feedback';
  static const String knowledge = '/knowledge';
  // Premium route - not used
  // static const String premium = '/premium';
  static const String admin = '/admin';
  static const String arrowPuzzle = '/arrow-puzzle';
  static const String stroopRush = '/stroop-rush';
  static const String workout = '/workout';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Intercept deep links of format: /challenge/{roomId}
    if (settings.name != null && settings.name!.startsWith('/challenge/')) {
      final parts = settings.name!.split('/');
      final roomId = parts.length > 2 ? parts[2] : null;
      return _build(BattleScreen(roomId: roomId), settings);
    }

    switch (settings.name) {
      case splash:
        return _build(const SplashScreen(), settings);
      case login:
        return _build(const LoginScreen(), settings);
      case home:
        return _build(const MainNavigationScreen(), settings);
      case quiz:
        return _buildFade(const QuizScreen(), settings);
      case result:
        return _build(const ResultScreen(), settings);
      case leaderboard:
        return _build(const LeaderboardScreen(), settings);
      case profile:
        return _build(const ProfileScreen(), settings);
      case feedback:
        return _build(const FeedbackScreen(), settings);
      case knowledge:
        return _build(const KnowledgeCategoriesScreen(), settings);
      case battle:
        return _build(const BattleScreen(), settings);
      case achievements:
        return _build(const AchievementsScreen(), settings);
      case onboarding:
        return _buildOnboarding(settings);
      // Premium route - commented out as not required
      // case premium:
      //   return _build(const PremiumScreen(), settings);
      case '/game-placeholder':
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _build(
          GamePlaceholderScreen(
            title: args['title'] ?? 'Game Mode',
            description: args['description'] ?? 'Coming soon!',
          ),
          settings,
        );
      case admin:
        return _build(const AdminScreen(), settings);
      case arrowPuzzle:
        return _buildFade(const ArrowEscapeGameScreen(), settings);
      case stroopRush:
        return _buildFade(const StroopRushScreen(), settings);
      case workout:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _buildFade(
          WorkoutScreen(presetId: args['presetId'] ?? 'balanced'),
          settings,
        );
      default:
        return _build(const HomeScreen(), settings);
    }
  }

  static MaterialPageRoute _build(Widget widget, RouteSettings settings) {
    return MaterialPageRoute(builder: (_) => widget, settings: settings);
  }

  /// Smooth fade + subtle rise transition used for game/quiz screens so that
  /// switching between modes feels polished instead of the default zoom.
  static PageRoute<void> _buildFade(Widget widget, RouteSettings settings) {
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) => widget,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.025),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static Route<dynamic> _buildOnboarding(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => OnboardingScreen(
        onComplete: () {
          navigatorKey.currentState?.pushReplacementNamed(home);
        },
      ),
      settings: settings,
    );
  }
}
