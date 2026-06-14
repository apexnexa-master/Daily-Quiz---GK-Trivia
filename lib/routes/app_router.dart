// lib/routes/app_router.dart
import 'package:flutter/material.dart';
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
// Premium screen - not used
// import '../presentation/screens/premium_screen.dart';
import '../presentation/screens/admin_screen.dart';
import '../presentation/screens/disclaimer_screen.dart';

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
  // Premium route - not used
  // static const String premium = '/premium';
  static const String admin = '/admin';
  static const String disclaimer = '/disclaimer';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _build(const SplashScreen(), settings);
      case login:
        return _build(const LoginScreen(), settings);
      case home:
        return _build(const HomeScreen(), settings);
      case quiz:
        return _build(const QuizScreen(), settings);
      case result:
        return _build(const ResultScreen(), settings);
      case leaderboard:
        return _build(const LeaderboardScreen(), settings);
      case profile:
        return _build(const ProfileScreen(), settings);
      case battle:
        return _build(const BattleScreen(), settings);
      case achievements:
        return _build(const AchievementsScreen(), settings);
      case onboarding:
        return _buildOnboarding(settings);
      // Premium route - commented out as not required
      // case premium:
      //   return _build(const PremiumScreen(), settings);
      case admin:
        return _build(const AdminScreen(), settings);
      case disclaimer:
        return _build(const DisclaimerAndSourcesScreen(), settings);
      default:
        return _build(const HomeScreen(), settings);
    }
  }

  static MaterialPageRoute _build(Widget widget, RouteSettings settings) {
    return MaterialPageRoute(builder: (_) => widget, settings: settings);
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
