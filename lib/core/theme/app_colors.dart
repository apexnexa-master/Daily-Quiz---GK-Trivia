// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core brand colors (DESIGN2: Hyper-Glass Kinetic - Yellow edition)
  static const Color primary = Color(0xFFD4FF50); // Cyber-Lime / Neon Yellow
  static const Color primaryLight = Color(0xFFE5FF92);
  static const Color primaryDark = Color(0xFF556D00);

  // BRAINX neon palette (Glassmorphism / Neon Dark Mode style tokens)
  static const Color neonLime = Color(0xFF39FF14);
  static const Color neonCyan = Color(0xFF00F2FE);
  static const Color neonViolet = Color(0xFF7B2CBF);
  static const Color slateDark = Color(0xFF0B0E14);
  static const Color slateNavy = Color(0xFF0D1117);

  /// Hero CTA gradient — neon lime to electric green (BRAINX workout banner).
  static const LinearGradient workoutGradient = LinearGradient(
    colors: [Color(0xFF8AFF00), Color(0xFF00FF87)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const Color secondary = Color(0xFFECB2FF); // Neon Violet
  static const Color secondaryLight = Color(0xFFF8D8FF);
  static const Color secondaryDark = Color(0xFFCF5CFF);
  static const Color accent = Color(0xFFD4FF50); // Accent Cyber-Lime

  // Semantic feedback colors
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);
  static const Color successDark = Color(0xFF047857);

  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFF87171);
  static const Color errorDark = Color(0xFFB91C1C);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningDark = Color(0xFFB45309);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFF60A5FA);

  // Gamification theme colors
  static const Color xp = Color(0xFFEAB308);
  static const Color streak = Color(0xFFF97316);
  static const Color coin = Color(0xFFFACC15);
  static const Color life = Color(0xFFEC4899);
  static const Color level = Color(0xFFCF5CFF); // Neon Violet Level

  // Light Mode Surfaces
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedLight = Color(0xFFF1F5F9);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  // Dark Mode Surfaces (BRAINX Glassmorphism / Neon Dark specifications)
  static const Color bgDark = Color(0xFF0D1117); // deep slate navy background
  static const Color cardDark = Color(0xFF192122); // surface-container
  static const Color surfaceElevatedDark = Color(0xFF232B2C); // surface-container-high
  static const Color surfaceContainerHighest = Color(0xFF2E3637);
  static const Color outlineVariant = Color(0xFF3A494B);
  static const Color outline = Color(0xFF849495);
  static const Color textPrimaryDark = Color(0xFFDCE4E4); // on-surface
  static const Color textSecondaryDark = Color(0xFFB9CACB); // on-surface-variant
  static const Color textTertiaryDark = Color(0xFF849495);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFD4FF50), Color(0xFFCF5CFF)], // Cyber-Lime to Neon Violet
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradientDark = LinearGradient(
    colors: [Color(0xFF161F00), Color(0xFFD4FF50)], // Cyber-Lime dark to Cyber-Lime
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
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
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
    colors: [Color(0xFFCF5CFF), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient homeBackdropGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF8FAFC),
      Color(0xFFF1F5F9),
      Color(0xFFE2E8F0),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient homeBackdropDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0B0E14), // deep slate navy
      Color(0xFF0D1117), // slate navy
      Color(0xFF111923), // deep slate blue
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // Category Color Map
  static const Map<String, Color> _categoryColors = {
    'General Knowledge': Color(0xFFD4FF50), // Cyber-Lime / Neon Yellow
    'Indian History': Color(0xFFFBBF24), // Amber
    'Geography': Color(0xFF8B5CF6), // Violet
    'Science': Color(0xFF10B981), // Emerald
    'Polity': Color(0xFFECB2FF), // Neon Violet
    'Economy': Color(0xFFEC4899), // Pink
    'Current Affairs': Color(0xFF3B82F6), // Blue
    'Art & Culture': Color(0xFFF43F5E), // Rose
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
    'GENERAL': Color(0xFFD4FF50),
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
          colors: [Color(0xFF161F00), Color(0xFFD4FF50)],
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
