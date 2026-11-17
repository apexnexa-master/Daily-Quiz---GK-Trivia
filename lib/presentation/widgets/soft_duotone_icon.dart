import 'package:flutter/material.dart';

/// Clean, borderless game icon with a soft duotone fill and a restrained halo.
///
/// Kept deliberately quiet so it reads as a flat-shaded 2.5D mark on a matte
/// modular tile instead of competing with the card title.
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
    final glyphSize = size * 0.82;

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
                  accent.withValues(alpha: isDark ? 0.08 : 0.06),
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
