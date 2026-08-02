// lib/presentation/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_animations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _googleLoading = false;
  bool _guestLoading = false;
  String? _error;
  bool _showAdminPassword = false;
  String _adminEmail = '';
  final _adminPasswordController = TextEditingController();

  Future<void> _signInGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      final result = await ref.read(authServiceProvider).signInWithGoogle();
      if (!mounted) return;

      if (result == null) {
        setState(() => _googleLoading = false);
        return;
      }

      if (result.isAdminEmail) {
        setState(() {
          _googleLoading = false;
          _showAdminPassword = true;
          _adminEmail = result.credential.user?.email ?? '';
        });
      } else {
        final prefs = await SharedPreferences.getInstance();
        final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            onboardingComplete ? '/home' : '/onboarding',
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _googleLoading = false;
      });
    }
  }

  Future<void> _verifyAdminPassword() async {
    if (_adminPasswordController.text.isEmpty) {
      setState(() => _error = 'Please enter password');
      return;
    }

    setState(() {
      _googleLoading = true;
      _error = null;
    });

    try {
      final isValid = await ref.read(authServiceProvider).verifyAdminPassword(
            _adminEmail,
            _adminPasswordController.text,
          );

      if (mounted) {
        if (isValid) {
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          setState(() {
            _googleLoading = false;
            _error = 'Invalid password';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _googleLoading = false;
          _error = 'Verification failed: ${e.toString()}';
        });
      }
    }
  }

  void _cancelAdmin() {
    setState(() {
      _showAdminPassword = false;
      _adminEmail = '';
      _adminPasswordController.clear();
    });
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _guestLoading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).signInAnonymously();
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_complete', true);
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _guestLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _adminPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(languageProvider);
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    if (_showAdminPassword) {
      return _buildAdminPasswordScreen(isDark, isBn, isHi);
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: isDark ? AppColors.homeBackdropDark : AppColors.homeBackdropGradient,
            ),
          ),
          // Ambient glow
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: isDark ? 0.05 : 0.02),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Glowing Hero Psychology Icon
                    PulseWidget(
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDark : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.outlineVariant : Colors.black12,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.psychology_rounded,
                          size: 64,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Typography Stack
                    Text(
                      'Train Your Mind',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        letterSpacing: -0.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The daily fitness app for your brain.',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    if (_error != null) ...[
                      _buildErrorCard(),
                      const SizedBox(height: 16),
                    ],

                    // Action buttons
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _googleLoading ? null : _signInGoogle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _googleLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.black,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/icon/icons8-google-48.png',
                                    width: 22,
                                    height: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    isBn
                                        ? 'Google দিয়ে লগইন করুন'
                                        : isHi
                                            ? 'Google से साइन इन करें'
                                            : 'Sign in with Google',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: _guestLoading ? null : _continueAsGuest,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(
                            color: isDark ? AppColors.outlineVariant : Colors.black12,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _guestLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.primary,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.person_outline_rounded, size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    isBn
                                        ? 'অতিথি হিসাবে চালিয়ে যান'
                                        : isHi
                                            ? 'अतिथि के रूप में जारी रखें'
                                            : 'Continue as Guest',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),


                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlappingAvatars() {
    final urls = [
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCImtVH3VgniNY-MaL-vFISxWYnFOmqW0ViSvlFmJUmxysOgNKIwA_Lh4o8803DZlQ0CoDS4LBUu10O3D5-L-WmEuQOCuQM84o-Qgxm0jJ3SEJjq4CsSg-NwoWFsLfmAwDfXfxnwXncMhvcdiEIDrAzj2HZkJb9dKkuSAjA0rQv-42GnD6U-BqJ2mDZmXmoYY-JlHWsYQXs3iE7u5U9cmU6cuY7YBadC9LTO2KbDd2sz1QtjyNRD3bJZQ',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBdDtvYV_GxPwceoL9_EBglntE1_F4wR2w0KJ7YTQQ2VZooOs58HdDUzKd3Ss6aNqbLueESiJpw9lq_GHTx71ARwLD0xxuDkD7t7X58ns9I-tIcAGii5Qkmd2n616-cZayBQPigPWlERIM3WG6Cz8Rkvw66SVgxl5_WFfXSE61E5qYLJgsFDbYo-Rou14_0avYmDAxrH0heOHCFNQxgBRJ9huM5gKPXgKzKVQAUOXVf2uV5m839TsSYww',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBzyxMPoYjZB-I5DGLCjbllMYQ-4qmqxS0VRlJKsej5Z_gGLZpEbGuxs6__eiH3QVt-Dye9HH5KnfCKYcQFfN4cEraEoKCiFQqtid4c8oLaGlT7m6NBaoqHf4-lHWtstwes18UY8cpcA7LcLvgxNllozmUzoZVxsFOeNjHRU3MkPmMeQKM2-N1uwLbOWrxjHjmq9qH31TIUJW-oeU5jRZNOaMZ0w6SGMeHRs8kNJF1hyV-i1sotFMxkcA',
    ];

    return SizedBox(
      width: 56,
      height: 24,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: CircleAvatar(
              radius: 12,
              backgroundImage: NetworkImage(urls[0]),
              backgroundColor: AppColors.bgDark,
            ),
          ),
          Positioned(
            left: 16,
            child: CircleAvatar(
              radius: 12,
              backgroundImage: NetworkImage(urls[1]),
              backgroundColor: AppColors.bgDark,
            ),
          ),
          Positioned(
            left: 32,
            child: CircleAvatar(
              radius: 12,
              backgroundImage: NetworkImage(urls[2]),
              backgroundColor: AppColors.bgDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminPasswordScreen(bool isDark, bool isBn, bool isHi) {
    final fgColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final inputBg = isDark ? AppColors.cardDark : Colors.black.withValues(alpha: 0.03);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: isDark ? AppColors.homeBackdropDark : AppColors.homeBackdropGradient,
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? AppColors.outlineVariant : Colors.black12,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 48,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Admin Access',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: fgColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _adminEmail,
                        style: TextStyle(fontSize: 13, color: fgColor.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.outlineVariant : Colors.black12,
                          ),
                        ),
                        child: TextField(
                          controller: _adminPasswordController,
                          obscureText: true,
                          style: TextStyle(color: fgColor, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: TextStyle(
                              color: fgColor.withValues(alpha: 0.4),
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline_rounded,
                              color: fgColor.withValues(alpha: 0.5),
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _googleLoading ? null : _verifyAdminPassword,
                          child: _googleLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text(
                                  'Verify',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () async {
                          _cancelAdmin();
                          final prefs = await SharedPreferences.getInstance();
                          final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
                          if (mounted) {
                            Navigator.pushReplacementNamed(
                              context,
                              onboardingComplete ? '/home' : '/onboarding',
                            );
                          }
                        },
                        child: Text(
                          'Continue as Normal User',
                          style: TextStyle(
                            color: fgColor.withValues(alpha: 0.5),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
