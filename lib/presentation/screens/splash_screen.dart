// lib/presentation/screens/splash_screen.dart
import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../routes/app_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _auroraController;
  late final AnimationController _entranceController;
  late final AnimationController _floatController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _riseAnimation;

  @override
  void initState() {
    super.initState();
    // Slow ambient drift for the aurora glow blobs.
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat(reverse: true);

    // Gentle floating motion for the logo tile.
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    // Entrance choreography.
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );
    _riseAnimation = Tween<double>(begin: 26, end: 0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.15, 0.9, curve: Curves.easeOutCubic),
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );
    _entranceController.forward();
    _navigateAfterDelay();
  }

  void _navigateAfterDelay() {
    Future.delayed(const Duration(milliseconds: 2000), () async {
      final prefs = await SharedPreferences.getInstance();
      final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

      // Use FirebaseAuth directly for reliable synchronous auth check.
      // The StreamProvider may still be loading on cold start, causing
      // ref.read(authStateProvider).value to return null even when the
      // user is actually logged in.
      final user = FirebaseAuth.instance.currentUser;
      if (!mounted) return;

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
    _auroraController.dispose();
    _floatController.dispose();
    _entranceController.dispose();
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
            // ── Animated aurora glow blobs ──
            AnimatedBuilder(
              animation: _auroraController,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_auroraController.value);
                return Stack(
                  children: [
                    Positioned(
                      top: -140 + t * 40,
                      right: -120 - t * 30,
                      child: _glowBlob(320,
                          (isDark ? AppColors.primary : AppColors.secondary)
                              .withValues(alpha: isDark ? 0.14 : 0.10)),
                    ),
                    Positioned(
                      bottom: -160 - t * 40,
                      left: -130 + t * 30,
                      child: _glowBlob(360,
                          (isDark ? AppColors.neonViolet : AppColors.primary)
                              .withValues(alpha: isDark ? 0.13 : 0.09)),
                    ),
                  ],
                );
              },
            ),
            // ── Center content ──
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glass logo tile with float + scale-in
                  AnimatedBuilder(
                    animation: Listenable.merge([_floatController, _entranceController]),
                    builder: (context, child) {
                      final lift =
                          Curves.easeInOut.transform(_floatController.value);
                      return Transform.translate(
                        offset: Offset(0, lift * -8 - (26 - _riseAnimation.value)),
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: child,
                        ),
                      );
                    },
                    child: _buildLogoTile(isDark),
                  ),
                  const SizedBox(height: 34),
                  // App name & tagline
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              const LinearGradient(
                                colors: [
                                  AppColors.primaryLight,
                                  AppColors.secondary,
                                ],
                              ).createShader(bounds),
                          blendMode: BlendMode.srcIn,
                          child: Text(
                            AppConstants.appName.toUpperCase(),
                            style: GoogleFonts.montserrat(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: isDark ? 0.06 : 0.04),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            'Daily Quiz + Practice',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? Colors.white60
                                  : AppColors.textSecondaryLight,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 56),
                  // Custom bouncing dot loader
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const _DotLoader(),
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
                    'v${AppConstants.appVersion}',
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

  Widget _glowBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildLogoTile(bool isDark) {
    return Container(
      width: 158,
      height: 158,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(44),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.03)]
              : [Colors.white, Colors.white.withValues(alpha: 0.75)],
        ),
        border: Border.all(
          color: (isDark ? Colors.white : AppColors.primary)
              .withValues(alpha: isDark ? 0.16 : 0.35),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.28 : 0.22),
            blurRadius: 42,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(43),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Image.asset(
              'assets/icon/logo2.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

/// Three dots bouncing in sequence — a softer loading cue than a spinner.
class _DotLoader extends StatefulWidget {
  const _DotLoader();

  @override
  State<_DotLoader> createState() => _DotLoaderState();
}

class _DotLoaderState extends State<_DotLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final staggered = (_controller.value * 3 - i).clamp(0.0, 1.0);
              final bounce = (staggered < 0.5 ? staggered * 2 : 2 - staggered * 2);
              return Transform.translate(
                offset: Offset(0, -7 * Curves.easeOut.transform(bounce)),
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
