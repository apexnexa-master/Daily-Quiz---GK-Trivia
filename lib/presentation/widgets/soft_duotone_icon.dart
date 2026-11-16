import 'package:flutter/material.dart';

/// Clean, borderless game icon with a soft duotone fill and a faint glow.
///
/// Replaces the old bordered squircle/token so tiles stay visually quiet and
/// the game title remains the focal point.
class SoftDuotoneIcon extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final double size;
  final bool isDark;

  const SoftDuotoneIcon({
    super.key,
    required this.icon,
    required this.accent,
    required this.size,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final top = Color.lerp(accent, Colors.white, isDark ? 0.32 : 0.10)!;
    final bottom =
        isDark ? accent : Color.lerp(accent, Colors.black, 0.18)!;
    final glyphSize = size * 0.74;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: isDark ? 0.20 : 0.12),
                  accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(size * 0.035, size * 0.045),
            child: Icon(
              icon,
              size: glyphSize,
              color: accent.withValues(alpha: isDark ? 0.30 : 0.16),
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [top, bottom],
            ).createShader(rect),
            child: Icon(
              icon,
              size: glyphSize,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
