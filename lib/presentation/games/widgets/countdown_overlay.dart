// lib/presentation/games/widgets/countdown_overlay.dart
// 3-2-1-GO overlay used before a timed game starts. Each number scales in and
// out with a matching tick sound. The translucent scrim lets the game's aurora
// background bleed through and every number is rendered as a gradient with a
// contracting ring for a punchy, modern feel.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/game_sfx.dart';
import '../../../core/theme/app_colors.dart';

class CountdownOverlay extends StatefulWidget {
  /// Called once after the final GO step finishes.
  final VoidCallback onFinished;

  final String goLabel;

  const CountdownOverlay({
    super.key,
    required this.onFinished,
    this.goLabel = 'GO!',
  });

  @override
  State<CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<CountdownOverlay>
    with SingleTickerProviderStateMixin {
  static const List<String> _steps = ['3', '2', '1'];

  late final AnimationController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..addStatusListener(_onTick);
    GameSfxService.instance.play(GameSfx.countdown);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTick(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_index < _steps.length) {
      GameSfxService.instance.play(GameSfx.countdown);
      setState(() => _index++);
      _controller.forward(from: 0);
    } else {
      GameSfxService.instance.play(GameSfx.tap);
      widget.onFinished();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final display = _index < _steps.length ? _steps[_index] : widget.goLabel;
    final isGo = _index >= _steps.length;

    final ringColor = isGo ? AppColors.primary : const Color(0xFF00F1FE);

    return Positioned.fill(
      child: Material(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.72),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, animation) {
              final scale = Tween<double>(begin: 0.4, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              );
              final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              );
              return FadeTransition(
                opacity: fade,
                child: ScaleTransition(scale: scale, child: child),
              );
            },
            child: Stack(
              key: ValueKey(display),
              alignment: Alignment.center,
              children: [
                // Contracting ring pulse behind the number.
                ScaleTransition(
                  scale: Tween<double>(begin: 0.55, end: 1.0).animate(
                    CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
                  ),
                  child: Container(
                    width: isGo ? 220 : 180,
                    height: isGo ? 220 : 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ringColor.withValues(alpha: isDark ? 0.10 : 0.08),
                      border: Border.all(
                        color: ringColor.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ringColor.withValues(alpha: 0.25),
                          blurRadius: 34,
                        ),
                      ],
                    ),
                  ),
                ),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isGo
                        ? const [Color(0xFFD4FF50), Color(0xFF00F1FE)]
                        : const [Color(0xFF00F1FE), Color(0xFFA78BFA), Color(0xFFFF5FA8)],
                  ).createShader(bounds),
                  child: Text(
                    display,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: isGo ? 76 : 100,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: ringColor.withValues(alpha: 0.55),
                          blurRadius: 40,
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
    );
  }
}
