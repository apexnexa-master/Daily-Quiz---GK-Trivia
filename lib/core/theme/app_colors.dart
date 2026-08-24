// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core brand colors (DESIGN3: Aurora Glass — mint & iris over midnight indigo)
  static const Color primary = Color(0xFF3EE6B0); // Aurora Mint
  static const Color primaryLight = Color(0xFF93F4D6);
  static const Color primaryDark = Color(0xFF0B9E71);

  // Neon atmosphere tokens (aurora accents)
  static const Color neonLime = Color(0xFF00E5A0); // Aurora Mint (bright)
  static const Color neonCyan = Color(0xFF22D3EE);
  static const Color neonViolet = Color(0xFF8B5CF6);
  static const Color slateDark = Color(0xFF070B16);
  static const Color slateNavy = Color(0xFF0A0F1E);

  /// Hero CTA gradient — aurora mint to sky blue.
  static const LinearGradient workoutGradient = LinearGradient(
    colors: [Color(0xFF00D9A6), Color(0xFF38BDF8)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const Color secondary = Color(0xFFB79CFF); // Soft Iris
  static const Color secondaryLight = Color(0xFFDED2FF);
  static const Color secondaryDark = Color(0xFF8B5CF6);
  static const Color accent = Color(0xFF3EE6B0); // Accent Aurora Mint

  // Semantic feedback colors
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);
  static const Color successDark = Color(0xFF047857);

  static const Color error = Color(0xFFF43F5E);
  static const Color errorLight = Color(0xFFFB7185);
  static const Color errorDark = Color(0xFFBE123C);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningDark = Color(0xFFB45309);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFF60A5FA);

  // Gamification theme colors
  static const Color xp = Color(0xFFEAB308);
  static const Color streak = Color(0xFFFB923C);
  static const Color coin = Color(0xFFFACC15);
  static const Color life = Color(0xFFEC4899);
  static const Color level = Color(0xFFA78BFA); // Iris Level

  // Light Mode Surfaces (ice lavender)
  static const Color bgLight = Color(0xFFF4F6FD);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedLight = Color(0xFFECF0FA);
  static const Color textPrimaryLight = Color(0xFF141A2E);
  static const Color textSecondaryLight = Color(0xFF4C5877);
  static const Color textTertiaryLight = Color(0xFF909CBA);

  // Dark Mode Surfaces (midnight indigo)
  static const Color bgDark = Color(0xFF090E1D); // midnight indigo background
  static const Color cardDark = Color(0xFF131A30); // surface-container
  static const Color surfaceElevatedDark = Color(0xFF1B2444); // container-high
  static const Color surfaceContainerHighest = Color(0xFF263156);
  static const Color outlineVariant = Color(0xFF333F63);
  static const Color outline = Color(0xFF7E8BAD);
  static const Color textPrimaryDark = Color(0xFFEBF0FF); // on-surface
  static const Color textSecondaryDark = Color(0xFFB7C3E4); // on-surface-variant
  static const Color textTertiaryDark = Color(0xFF7886AB);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF3EE6B0), Color(0xFF7C6AF2)], // Aurora Mint to Iris
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradientDark = LinearGradient(
    colors: [Color(0xFF06251D), Color(0xFF3EE6B0)], // deep mint to Aurora Mint
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient streakGradient = LinearGradient(
    colors: [Color(0xFFF97316), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFF43F5E), Color(0xFFBE123C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient infoGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient levelGradient = LinearGradient(
    colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient homeBackdropGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFAFCFF),
      Color(0xFFF2F5FE),
      Color(0xFFEAEEFC),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient homeBackdropDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF060A16), // deepest midnight
      Color(0xFF0A0F1F), // midnight indigo
      Color(0xFF111A36), // deep iris navy
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Ambient glow hues used by decorative backdrop blobs (dark mode).
  static const List<Color> auroraGlowColors = [
    Color(0xFF22D3EE), // cyan
    Color(0xFF8B5CF6), // violet
    Color(0xFF3EE6B0), // mint
  ];

  // Category Color Map
  static const Map<String, Color> _categoryColors = {
    'General Knowledge': Color(0xFF3EE6B0), // Aurora Mint
    'Indian History': Color(0xFFFBBF24), // Amber
    'Geography': Color(0xFF38BDF8), // Sky
    'Science': Color(0xFF34D399), // Emerald
    'Polity': Color(0xFFA78BFA), // Iris
    'Economy': Color(0xFFF472B6), // Pink
    'Current Affairs': Color(0xFF60A5FA), // Blue
    'Art & Culture': Color(0xFFFB7185), // Rose
  };

  static Color categoryColor(String category) {
    return _categoryColors[category] ?? primary;
  }

  static LinearGradient categoryGradient(String category) {
    final baseColor = categoryColor(category);
    final hsl = HSLColor.fromColor(baseColor);
    final lightColor = hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0)).toColor();
    return LinearGradient(
      colors: [baseColor, lightColor],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // Exam Mode Colors
  static const Map<String, Color> _examModeColors = {
    'GENERAL': Color(0xFF3EE6B0),
    'WBPSC': Color(0xFF0F766E),
    'SSC': Color(0xFFD97706),
    'UPSC': Color(0xFFBE123C),
    'BANK': Color(0xFF0369A1),
  };

  static Color examModeColor(String mode) {
    return _examModeColors[mode.toUpperCase()] ?? primary;
  }

  static LinearGradient examModeGradient(String mode) {
    switch (mode.toUpperCase()) {
      case 'UPSC':
        return const LinearGradient(
          colors: [Color(0xFF881337), Color(0xFFE11D48)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'BANK':
        return const LinearGradient(
          colors: [Color(0xFF0369A1), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'GENERAL':
      default:
        return const LinearGradient(
          colors: [Color(0xFF06251D), Color(0xFF3EE6B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
}

// BuildContext Extension for easy access to theme colors in UI
extension AppColorsExtension on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get primaryColor => AppColors.primary;
  Color get primaryLightColor => AppColors.primaryLight;
  Color get primaryDarkColor => AppColors.primaryDark;
  Color get secondaryColor => AppColors.secondary;
  Color get accentColor => AppColors.accent;

  Color get successColor => isDarkMode ? AppColors.successLight : AppColors.success;
  Color get errorColor => isDarkMode ? AppColors.errorLight : AppColors.error;
  Color get warningColor => isDarkMode ? AppColors.warningLight : AppColors.warning;
  Color get infoColor => isDarkMode ? AppColors.infoLight : AppColors.info;

  Color get xpColor => AppColors.xp;
  Color get streakColor => AppColors.streak;
  Color get coinColor => AppColors.coin;
  Color get lifeColor => AppColors.life;
  Color get levelColor => AppColors.level;

  Color get backgroundColor => isDarkMode ? AppColors.bgDark : AppColors.bgLight;
  Color get cardColor => isDarkMode ? AppColors.cardDark : AppColors.cardLight;
  Color get surfaceElevatedColor => isDarkMode ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight;

  Color get textPrimary => isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color get textSecondary => isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  Color get textTertiary => isDarkMode ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
}
