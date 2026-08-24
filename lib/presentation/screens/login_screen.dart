// lib/presentation/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  bool _googleLoading = false;
  bool _guestLoading = false;
  String? _error;
  bool _showAdminPassword = false;
  String _adminEmail = '';
  final _adminPasswordController = TextEditingController();

  late final AnimationController _auroraController;

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

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
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          onboardingComplete ? '/home' : '/onboarding',
        );
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _guestLoading = false;
      });
    }
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
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: isDark ? AppColors.homeBackdropDark : AppColors.homeBackdropGradient,
            ),
          ),
          // Drifting aurora glows
          AnimatedBuilder(
            animation: _auroraController,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_auroraController.value);
              return Stack(
                children: [
                  Positioned(
                    top: -120 + t * 36,
                    left: -110 - t * 24,
                    child: _glowBlob(300,
                        AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.10)),
                  ),
                  Positioned(
                    bottom: -150 - t * 30,
                    right: -120 + t * 26,
                    child: _glowBlob(340,
                        AppColors.secondary.withValues(alpha: isDark ? 0.14 : 0.10)),
                  ),
                  Positioned(
                    top: 180 - t * 20,
                    right: -80,
                    child: _glowBlob(200,
                        AppColors.neonCyan.withValues(alpha: isDark ? 0.08 : 0.06)),
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Glowing glass logo tile
                    PulseWidget(
                      child: Container(
                        width: 168,
                        height: 168,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(48),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [
                                    Colors.white.withValues(alpha: 0.10),
                                    Colors.white.withValues(alpha: 0.03),
                                  ]
                                : [Colors.white, Colors.white.withValues(alpha: 0.75)],
                          ),
                          border: Border.all(
                            color: (isDark ? Colors.white : AppColors.primary)
                                .withValues(alpha: isDark ? 0.16 : 0.35),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary
                                  .withValues(alpha: isDark ? 0.26 : 0.20),
                              blurRadius: 46,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Image.asset(
                            'assets/icon/logo2.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Typography stack
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [AppColors.primaryLight, AppColors.secondary],
                      ).createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: Text(
                        isBn
                            ? 'মনকে প্রশিক্ষণ দিন'
                            : isHi
                                ? 'अपने दिमाग को ट्रेन करें'
                                : 'Train Your Mind',
                        style: GoogleFonts.montserrat(
                          fontSize: 31,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isBn
                          ? 'আপনার ব্রেইনের দৈনিক ফিটনেস অ্যাপ।'
                          : isHi
                              ? 'आपके दिमाग का डेली फिटनेस ऐप।'
                              : 'The daily fitness app for your brain.',
                      style: TextStyle(
                        fontSize: 15.5,
                        height: 1.4,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Feature chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _featureChip(Icons.psychology_alt_rounded,
                            isBn ? 'কুইজ' : isHi ? 'क्विज़' : 'Daily Quiz', isDark),
                        _featureChip(Icons.bolt_rounded,
                            isBn ? 'ব্রেইন গেমস' : isHi ? 'ब्रेन गेम्स' : 'Brain Games', isDark),
                        _featureChip(Icons.emoji_events_rounded,
                            isBn ? 'র‍্যাঙ্ক' : isHi ? 'रैंक' : 'Leaderboards', isDark),
                      ],
                    ),
                    const SizedBox(height: 40),

                    if (_error != null) ...[
                      _buildErrorCard(),
                      const SizedBox(height: 16),
                    ],

                    // Action buttons
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _googleLoading ? null : _signInGoogle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDark ? Colors.white : AppColors.textPrimaryLight,
                          foregroundColor:
                              isDark ? AppColors.bgDark : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _googleLoading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color:
                                      isDark ? AppColors.bgDark : Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Image.asset(
                                      'assets/icon/icons8-google-48.png',
                                      width: 18,
                                      height: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    isBn
                                        ? 'Google দিয়ে লগইন করুন'
                                        : isHi
                                            ? 'Google से साइन इन करें'
                                            : 'Sign in with Google',
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _guestLoading ? null : _continueAsGuest,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? AppColors.primaryLight
                              : AppColors.primaryDark,
                          side: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.16)
                                : Colors.black.withValues(alpha: 0.10),
                            width: 1.4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
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
                                  const Icon(Icons.person_outline_rounded,
                                      size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    isBn
                                        ? 'অতিথি হিসাবে চালিয়ে যান'
                                        : isHi
                                            ? 'अतिथि के रूप में जारी रखें'
                                            : 'Continue as Guest',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white70
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Trust microcopy
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 13,
                          color: isDark
                              ? Colors.white38
                              : AppColors.textTertiaryLight,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isBn
                              ? 'আপনার তথ্য সুরক্ষিত'
                              : isHi
                                  ? 'आपकी जानकारी सुरक्षित है'
                                  : 'Your data stays safe & secure',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: isDark
                                ? Colors.white38
                                : AppColors.textTertiaryLight,
                          ),
                        ),
                      ],
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

  Widget _glowBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _featureChip(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.white)
            .withValues(alpha: isDark ? 0.07 : 0.85),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: (isDark ? Colors.white : AppColors.primary)
              .withValues(alpha: isDark ? 0.12 : 0.5),
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryDark),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
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
        borderRadius: BorderRadius.circular(14),
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
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark ? AppColors.outlineVariant : Colors.black12,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 32,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          size: 30,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Admin Access',
                        style: GoogleFonts.montserrat(
                          fontSize: 23,
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
                          borderRadius: BorderRadius.circular(16),
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
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
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
