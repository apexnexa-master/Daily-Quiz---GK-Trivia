// lib/presentation/games/widgets/game_top_bar.dart
// Consistent header for all game screens: back button, gradient title and an
// optional trailing slot (lives, pause, score chip). Clean, high-contrast.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class GameTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

  const GameTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtle = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack ?? () => Navigator.maybePop(context),
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(backgroundColor: subtle),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: isDark
                        ? [AppColors.primary, const Color(0xFFECB2FF)]
                        : [AppColors.primaryDark, AppColors.secondaryDark],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ).createShader(bounds),
                  child: Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
