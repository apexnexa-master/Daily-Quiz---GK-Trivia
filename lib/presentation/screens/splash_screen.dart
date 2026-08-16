// lib/presentation/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../providers/app_providers.dart';
import '../../routes/app_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );
    _controller.forward();
    _navigateAfterDelay();
  }

  void _navigateAfterDelay() {
    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
      final user = ref.read(authStateProvider).value;

      if (user == null) {
        Navigator.pushReplacementNamed(context, AppRouter.login);
      } else if (!onboardingComplete) {
        Navigator.pushReplacementNamed(context, AppRouter.onboarding);
      } else {
        Navigator.pushReplacementNamed(context, AppRouter.home);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.homeBackdropDark : AppColors.homeBackdropGradient,
        ),
        child: Stack(
          children: [
            // Center Content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Logo Animated
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Image.asset(
                      'assets/icon/logo2.png',
                      width: 170,
                      height: 170,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // App Name & Tagline Animated
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          'BrainX',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Daily Quiz + Practice',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),
                  // Progress spinner
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Version Display at bottom
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: Text(
                    'v1.0.2',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
