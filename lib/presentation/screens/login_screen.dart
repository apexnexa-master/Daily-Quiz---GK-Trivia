// lib/presentation/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_animations.dart';
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
        Navigator.pushReplacementNamed(context, '/home');
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
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
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
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.homeBackdropDark : AppColors.homeBackdropGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: AppSpacing.paddingScreen,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  _buildLogo(),
                  const SizedBox(height: 24),
                  _buildTitle(isDark),
                  const SizedBox(height: 8),
                  _buildSubtitle(isBn, isHi, isDark),
                  const SizedBox(height: 48),
                  if (_error != null) _buildError(),
                  const SizedBox(height: 12),
                  _buildGoogleButton(isBn, isHi),
                  const SizedBox(height: 14),
                  _buildGuestButton(isBn, isHi, isDark),
                  const SizedBox(height: 32),
                  _buildDisclaimer(isBn, isHi, isDark),
                  const SizedBox(height: 40),
                  _buildFooter(isDark),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminPasswordScreen(bool isDark, bool isBn, bool isHi) {
    final fgColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final inputBg = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04);
    final inputBorder = isDark ? Colors.white24 : Colors.black12;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.homeBackdropDark : AppColors.homeBackdropGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.15),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 48,
                        color: AppColors.primary,
                      ),
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
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: inputBorder,
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
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _googleLoading ? null : _verifyAdminPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _googleLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
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
                      onPressed: () {
                        _cancelAdmin();
                        Navigator.pushReplacementNamed(context, '/home');
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
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 110,
      height: 110,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/icon/daily_gk_quiz_playstore_icon.png',
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildTitle(bool isDark) {
    return Text(
      'GK Quiz',
      style: TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.white : AppColors.textPrimaryLight,
        letterSpacing: -1,
      ),
    );
  }

  Widget _buildSubtitle(bool isBn, bool isHi, bool isDark) {
    return Column(
      children: [
        Text(
          isBn
              ? 'আপনার জ্ঞান পরীক্ষা করুন'
              : isHi
                  ? 'अपना ज्ञान टेस्ट करें'
                  : 'Test Your Knowledge',
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
            color: AppColors.primary.withValues(alpha: 0.08),
          ),
          child: Text(
            'SSC • UPSC • WBPSC • Bank PO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
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

  Widget _buildGoogleButton(bool isBn, bool isHi) {
    return AnimatedScaleButton(
      onTap: _googleLoading ? null : _signInGoogle,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4285F4), Color(0xFF3578E8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4285F4).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _googleLoading
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icon/icons8-google-48.png',
                    width: 26,
                    height: 26,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isBn
                        ? 'Google দিয়ে লগইন করুন'
                        : isHi
                            ? 'Google से साइन इन करें'
                            : 'Sign in with Google',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGuestButton(bool isBn, bool isHi, bool isDark) {
    final fgColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final bgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12);

    return AnimatedScaleButton(
      onTap: _guestLoading ? null : _continueAsGuest,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
        ),
        child: _guestLoading
            ? Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: fgColor.withValues(alpha: 0.7),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 22,
                    color: fgColor.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isBn
                        ? 'অতিথি হিসাবে চালিয়ে যান'
                        : isHi
                            ? 'अतिथि के रूप में जारी रखें'
                            : 'Continue as Guest',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: fgColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDisclaimer(bool isBn, bool isHi, bool isDark) {
    final fgColor = isDark ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: fgColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: fgColor.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: fgColor.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 8),
          Text(
            isBn
                ? 'অতিথি প্রগ্রেস সংরক্ষিত হয় না'
                : isHi
                    ? 'अतिथि प्रगति सहेजी नहीं जाती'
                    : 'Guest progress will not be saved',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fgColor.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.favorite_rounded,
            size: 13, color: Colors.pink.withValues(alpha: 0.6)),
        const SizedBox(width: 6),
        Text(
          'Made in India',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.25),
          ),
        ),
      ],
    );
  }
}
