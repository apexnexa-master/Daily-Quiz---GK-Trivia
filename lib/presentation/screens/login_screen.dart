// lib/presentation/screens/login_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  bool _loading = false;
  String? _error;
  bool _showAdminPassword = false;
  String _adminEmail = '';
  final _adminPasswordController = TextEditingController();
  late AnimationController _animController;
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _floatController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.0, 0.7, curve: Curves.easeOut)));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _animController,
                curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic)));
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _signInGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(authServiceProvider).signInWithGoogle();
      if (!mounted) return;

      if (result?.isAdminEmail == true) {
        setState(() {
          _loading = false;
          _showAdminPassword = true;
          _adminEmail = result!.credential.user?.email ?? '';
        });
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _verifyAdminPassword() async {
    if (_adminPasswordController.text.isEmpty) {
      setState(() => _error = 'Please enter password');
      return;
    }

    setState(() {
      _loading = true;
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
            _loading = false;
            _error = 'Invalid password';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
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
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).signInAnonymously();
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(languageProvider);
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final size = MediaQuery.of(context).size;

    if (_showAdminPassword) {
      return _buildAdminPasswordScreen(isDark, isBn, isHi);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: Stack(
        children: [
          _AnimatedBackground(isDark: isDark),
          _FloatingParticles(size: size, controller: _floatController),
          _CyberGridLines(size: size, controller: _floatController),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      _buildLogo(isDark, isBn, isHi),
                      const SizedBox(height: 20),
                      _buildTitle(isDark, isBn, isHi),
                      const SizedBox(height: 12),
                      _buildSubtitle(isDark, isBn, isHi),
                      const SizedBox(height: 50),
                      _buildFeatureCards(isDark, isBn, isHi),
                      const SizedBox(height: 40),
                      if (_error != null) _buildError(),
                      if (_loading)
                        _buildLoading()
                      else
                        _buildButtons(isDark, isBn, isHi),
                      const SizedBox(height: 20),
                      _buildDisclaimer(isDark, isBn, isHi),
                      const SizedBox(height: 30),
                      _buildFooter(isDark),
                      const SizedBox(height: 20),
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

  Widget _buildAdminPasswordScreen(bool isDark, bool isBn, bool isHi) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.deepPurple.withValues(alpha: 0.2),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    size: 60,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Admin Access',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _adminEmail,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your admin password',
                  style: TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _adminPasswordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(Icons.lock, color: Colors.white70),
                          border: InputBorder.none,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verifyAdminPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Verify'),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    _cancelAdmin();
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  child: const Text(
                    'Continue as Normal User',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isDark, bool isBn, bool isHi) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_glowAnimation.value * 0.05),
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.3),
                  AppTheme.primaryColor.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor
                      .withValues(alpha: 0.4 * _glowAnimation.value),
                  blurRadius: 60 * _glowAnimation.value,
                  spreadRadius: 20 * _glowAnimation.value,
                ),
                BoxShadow(
                  color: AppTheme.secondaryColor
                      .withValues(alpha: 0.3 * _glowAnimation.value),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.secondaryColor,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitle(bool isDark, bool isBn, bool isHi) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899)],
      ).createShader(bounds),
      child: Text(
        'GK Quiz',
        style: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: -1,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildSubtitle(bool isDark, bool isBn, bool isHi) {
    return Column(
      children: [
        Text(
          isBn
              ? 'আপনার জ্ঞান পরীক্ষা করুন'
              : isHi
                  ? 'अपना ज्ञान टेस्ट करें'
                  : 'Test Your Knowledge',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
          ),
          child: Text(
            'SSC • UPSC • WBPSC • Bank PO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor.withValues(alpha: 0.9),
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCards(bool isDark, bool isBn, bool isHi) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _FeatureCard(
          icon: Icons.auto_awesome,
          title: isBn
              ? 'দৈনিক কুইজ'
              : isHi
                  ? 'दैनिक क्विज़'
                  : 'Daily Quiz',
          subtitle: isBn
              ? 'নতুন প্রশ্ন'
              : isHi
                  ? 'नए प्रश्न'
                  : 'Fresh Questions',
          color: const Color(0xFF6366F1),
          controller: _floatController,
        ),
        _FeatureCard(
          icon: Icons.school_rounded,
          title: isBn
              ? 'অনুশীলন'
              : isHi
                  ? 'अभ्यास'
                  : 'Practice',
          subtitle: isBn
              ? 'যেকোনো সময়'
              : isHi
                  ? 'कभी भी'
                  : 'Anytime',
          color: const Color(0xFF8B5CF6),
          controller: _floatController,
          delay: 0.5,
        ),
        _FeatureCard(
          icon: Icons.emoji_events_rounded,
          title: isBn
              ? 'অর্জন'
              : isHi
                  ? 'उपलब्धियाँ'
                  : 'Achievements',
          subtitle: isBn
              ? 'প্রগ্রেস ট্র্যাক'
              : isHi
                  ? 'प्रगति ट्रैक'
                  : 'Track Progress',
          color: const Color(0xFFEC4899),
          controller: _floatController,
          delay: 1.0,
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: AppTheme.errorColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
          ),
          SizedBox(height: 12),
          Text(
            'Connecting...',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(bool isDark, bool isBn, bool isHi) {
    return Column(
      children: [
        _FuturisticButton(
          onTap: _signInGoogle,
          label: isBn
              ? 'Google দিয়ে লগইন করুন'
              : isHi
                  ? 'Google से साइन इन करें'
                  : 'Sign in with Google',
          icon: Icons.g_mobiledata_rounded,
          gradient: const [Color(0xFF4285F4), Color(0xFF3578E8)],
          glowColor: const Color(0xFF4285F4),
        ),
        const SizedBox(height: 16),
        _FuturisticButton(
          onTap: _continueAsGuest,
          label: isBn
              ? 'অতিথি হিসাবে চালিয়ে যান'
              : isHi
                  ? 'अतिथि के रूप में जारी रखें'
                  : 'Continue as Guest',
          icon: Icons.person_outline_rounded,
          gradient: const [Color(0xFF1E1E2E), Color(0xFF2D2D44)],
          glowColor: AppTheme.primaryColor,
          isOutlined: true,
        ),
      ],
    );
  }

  Widget _buildDisclaimer(bool isDark, bool isBn, bool isHi) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: Colors.white.withValues(alpha: 0.4),
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
              color: Colors.white.withValues(alpha: 0.4),
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
            size: 14, color: Colors.pink.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Text(
          'Made in India',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}

class _AnimatedBackground extends StatelessWidget {
  final bool isDark;
  const _AnimatedBackground({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A0E27),
            const Color(0xFF1A1F4B),
            const Color(0xFF0A0E27),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondaryColor.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingParticles extends StatelessWidget {
  final Size size;
  final AnimationController controller;
  const _FloatingParticles({required this.size, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(
          size: size,
          painter: _ParticlePainter(controller.value),
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double animationValue;
  _ParticlePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final random = math.Random(42);
    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = (random.nextDouble() + animationValue) % 1 * size.height;
      final radius = random.nextDouble() * 2 + 1;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CyberGridLines extends StatelessWidget {
  final Size size;
  final AnimationController controller;
  const _CyberGridLines({required this.size, required this.controller});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: size,
      painter: _GridPainter(),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 60.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final AnimationController controller;
  final double delay;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.controller,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final offset = math.sin((controller.value + delay) * math.pi * 2) * 8;
        return Transform.translate(
          offset: Offset(0, offset),
          child: Container(
            width: 100,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.2),
                        color.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FuturisticButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final Color glowColor;
  final bool isOutlined;

  const _FuturisticButton({
    required this.onTap,
    required this.label,
    required this.icon,
    required this.gradient,
    required this.glowColor,
    this.isOutlined = false,
  });

  @override
  State<_FuturisticButton> createState() => _FuturisticButtonState();
}

class _FuturisticButtonState extends State<_FuturisticButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: widget.isOutlined
                    ? null
                    : LinearGradient(
                        colors: widget.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: widget.isOutlined
                    ? Colors.white.withValues(alpha: 0.03)
                    : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isOutlined
                      ? widget.glowColor.withValues(alpha: 0.3)
                      : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: widget.isOutlined
                    ? null
                    : [
                        BoxShadow(
                          color: widget.glowColor
                              .withValues(alpha: _glowAnimation.value * 0.4),
                          blurRadius: 20 * _glowAnimation.value,
                          spreadRadius: -2,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withValues(alpha: widget.isOutlined ? 0.1 : 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 22,
                      color:
                          widget.isOutlined ? widget.glowColor : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color:
                          widget.isOutlined ? widget.glowColor : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
