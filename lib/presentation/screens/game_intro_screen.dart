import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_animations.dart';
import '../../data/game_intro_data.dart';
import '../providers/app_providers.dart';

class GameIntroScreen extends ConsumerStatefulWidget {
  final GameIntroData gameData;
  final Map<String, dynamic>? routeArgs;

  const GameIntroScreen({super.key, required this.gameData, this.routeArgs});

  @override
  ConsumerState<GameIntroScreen> createState() => _GameIntroScreenState();
}

class _GameIntroScreenState extends ConsumerState<GameIntroScreen>
    with TickerProviderStateMixin {
  late AnimationController _orbController;
  late Animation<double> _orbScale;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _orbScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _orbController, curve: Curves.easeInOut),
    );
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  String _t(String en, String bn, String hi) {
    final lang = ref.read(languageProvider);
    if (lang == 'bn') return bn;
    if (lang == 'hi') return hi;
    return en;
  }

  void _startGame() {
    HapticFeedback.mediumImpact();
    Navigator.pushReplacementNamed(
      context,
      widget.gameData.targetRoute,
      arguments: widget.routeArgs ?? widget.gameData.targetArgs,
    );
  }

  void _showRulesSheet() {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gd = widget.gameData;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RulesSheet(
        gameData: gd,
        isDark: isDark,
        lang: ref.read(languageProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gd = widget.gameData;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.homeBackdropDark
              : AppColors.homeBackdropGradient,
        ),
        child: Stack(
          children: [
            _buildBackgroundOrbs(isDark, gd),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(isDark),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildHeroOrb(isDark, gd),
                          const SizedBox(height: 24),
                          _buildTitle(isDark, gd),
                          const SizedBox(height: 8),
                          _buildTagline(isDark, gd),
                          const SizedBox(height: 28),
                          _buildBrainBenefitCard(isDark, gd),
                          const SizedBox(height: 16),
                          _buildRulesPreview(isDark, gd),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  _buildStartButton(isDark, gd),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundOrbs(bool isDark, GameIntroData gd) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: gd.accentColor.withValues(alpha: isDark ? 0.06 : 0.03),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (gd.secondaryColor ?? gd.accentColor)
                    .withValues(alpha: isDark ? 0.04 : 0.02),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white70 : Colors.black54,
              size: 24,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _showRulesSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 14,
                    color: isDark ? Colors.white60 : Colors.black45,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _t('Rules', 'নিয়ম', 'नियम'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white60 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildHeroOrb(bool isDark, GameIntroData gd) {
    if (gd.showOrbitingOperators) {
      return _buildOrbitingOrb(isDark, gd);
    }
    if (gd.showOrbitingDots) {
      return _buildOrbitingDotOrb(isDark, gd);
    }
    return AnimatedBuilder(
      animation: _orbScale,
      builder: (context, child) {
        return Transform.scale(
          scale: _orbScale.value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  gd.accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  gd.accentColor.withValues(alpha: isDark ? 0.05 : 0.02),
                  Colors.transparent,
                ],
                stops: const [0.4, 0.7, 1.0],
              ),
              border: Border.all(
                color: gd.accentColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: gd.accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  blurRadius: 40,
                ),
              ],
            ),
            child: Icon(
              gd.icon,
              size: 48,
              color: gd.accentColor,
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrbitingOrb(bool isDark, GameIntroData gd) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  gd.accentColor,
                  gd.secondaryColor ?? gd.accentColor,
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gd.accentColor.withValues(alpha: isDark ? 0.4 : 0.3),
                  blurRadius: 34,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              gd.icon,
              size: 50,
              color: Colors.black,
            ),
          ),
          AnimatedBuilder(
            animation: _spinController,
            builder: (context, _) {
              final angle = _spinController.value * 2 * pi;
              return Transform.rotate(
                angle: angle,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _orbitSymbol('+', const Offset(70, 0), const Color(0xFF00F1FE)),
                    _orbitSymbol('−', const Offset(-70, 0), const Color(0xFFFF5FA8)),
                    _orbitSymbol('×', const Offset(0, 70), const Color(0xFF3EE6B0)),
                    _orbitSymbol('÷', const Offset(0, -70), const Color(0xFFA78BFA)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _orbitSymbol(String symbol, Offset offset, Color color) {
    return Transform.translate(
      offset: offset,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12),
          ],
        ),
        child: Text(
          symbol,
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildOrbitingDotOrb(bool isDark, GameIntroData gd) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gd.accentColor,
                  gd.secondaryColor ?? gd.accentColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gd.accentColor.withValues(alpha: isDark ? 0.45 : 0.35),
                  blurRadius: 34,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              gd.icon,
              size: 50,
              color: Colors.white,
            ),
          ),
          AnimatedBuilder(
            animation: _spinController,
            builder: (context, _) {
              final angle = _spinController.value * 2 * pi;
              return Transform.rotate(
                angle: angle,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _orbitDot(const Offset(64, 0), const Color(0xFF00E5FF)),
                    _orbitDot(const Offset(-64, 0), const Color(0xFFFF6D00)),
                    _orbitDot(const Offset(0, 64), const Color(0xFFE040FB)),
                    _orbitDot(const Offset(0, -64), const Color(0xFFFFEB3B)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _orbitDot(Offset offset, Color color) {
    return Transform.translate(
      offset: offset,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          shape: BoxShape.circle,
          border:
              Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _buildTitle(bool isDark, GameIntroData gd) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [gd.accentColor, gd.secondaryColor ?? gd.accentColor],
      ).createShader(bounds),
      child: Text(
        _t(gd.title, gd.titleBn, gd.titleHi),
        textAlign: TextAlign.center,
        style: GoogleFonts.montserrat(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTagline(bool isDark, GameIntroData gd) {
    return Text(
      _t(gd.tagline, gd.taglineBn, gd.taglineHi),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color:
            isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      ),
    );
  }

  Widget _buildBrainBenefitCard(bool isDark, GameIntroData gd) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, size: 16, color: gd.accentColor),
              const SizedBox(width: 8),
              Text(
                _t(
                  'How This Helps Your Brain',
                  'এটি মস্তিষ্ককে কিভাবে সাহায্য করে',
                  'यह दिमाग की कैसे मदद करता है',
                ),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color:
                      isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _t(gd.brainBenefit, gd.brainBenefitBn, gd.brainBenefitHi),
            style: TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesPreview(bool isDark, GameIntroData gd) {
    final lang = ref.read(languageProvider);
    final rules = lang == 'bn'
        ? gd.rulesBn
        : lang == 'hi'
            ? gd.rulesHi
            : gd.rules;

    return GestureDetector(
      onTap: _showRulesSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: gd.accentColor.withValues(alpha: isDark ? 0.06 : 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: gd.accentColor.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rule_rounded, size: 16, color: gd.accentColor),
                const SizedBox(width: 8),
                Text(
                  _t('How to Play', 'কিভাবে খেলবেন', 'कैसे खेलें'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color:
                        isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: gd.accentColor.withValues(alpha: 0.6),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...rules.take(3).map(
              (rule) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: gd.accentColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        rule,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (rules.length > 3) ...[
              const SizedBox(height: 4),
              Text(
                _t(
                  'Tap to see all rules',
                  'সব নিয়ম দেখতে ট্যাপ করুন',
                  'सभी नियम देखने के लिए टैप करें',
                ),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: gd.accentColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton(bool isDark, GameIntroData gd) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: AnimatedScaleButton(
          onTap: _startGame,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gd.accentColor,
                  gd.secondaryColor ?? gd.accentColor,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: gd.accentColor.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _t('START', 'শুরু করুন', 'शुरू करें'),
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RulesSheet extends StatelessWidget {
  final GameIntroData gameData;
  final bool isDark;
  final String lang;

  const _RulesSheet({
    required this.gameData,
    required this.isDark,
    required this.lang,
  });

  String _t(String en, String bn, String hi) {
    if (lang == 'bn') return bn;
    if (lang == 'hi') return hi;
    return en;
  }

  @override
  Widget build(BuildContext context) {
    final gd = gameData;
    final rules = lang == 'bn'
        ? gd.rulesBn
        : lang == 'hi'
            ? gd.rulesHi
            : gd.rules;

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111318) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.rule_rounded, color: gd.accentColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  _t('Rules', 'নিয়ম', 'नियম'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color:
                        isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color:
                (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ),
          Expanded(
            child: ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              itemCount: rules.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: gd.accentColor.withValues(alpha: 0.12),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: gd.accentColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          rules[index],
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gd.accentColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _t('GOT IT', 'বুঝেছি', 'समझ गया'),
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
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
