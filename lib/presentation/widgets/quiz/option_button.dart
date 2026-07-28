// lib/presentation/widgets/quiz/option_button.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class OptionButton extends StatelessWidget {
  final int index;
  final String text;
  final bool isSelected;
  final bool isBengali;
  final bool isDark;
  final VoidCallback? onTap;
  final bool showAsCorrect;
  final bool showAsWrong;
  final bool? isCorrectFeedback;
  final AnimationController? correctAnimation;
  final AnimationController? wrongAnimation;
  final bool isEliminated;

  const OptionButton({
    super.key,
    required this.index,
    required this.text,
    required this.isSelected,
    required this.isBengali,
    required this.isDark,
    this.onTap,
    this.showAsCorrect = false,
    this.showAsWrong = false,
    this.isCorrectFeedback,
    this.correctAnimation,
    this.wrongAnimation,
    this.isEliminated = false,
  });

  static const _labels = ['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    Color? tileBgColor;
    Gradient? tileGradient;
    Color borderColor;
    Color textColor;
    Color badgeBgColor;
    Color badgeTextColor;
    Widget? rightIcon;

    if (isEliminated) {
      tileBgColor = isDark ? Colors.white.withValues(alpha: 0.01) : Colors.grey.shade50;
      borderColor = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.08);
      textColor = isDark ? Colors.white24 : Colors.grey.shade400;
      badgeBgColor = isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade200;
      badgeTextColor = isDark ? Colors.white24 : Colors.grey.shade400;
      rightIcon = Icon(
        Icons.block_rounded,
        color: isDark ? Colors.white24 : Colors.grey.shade400,
        size: 18,
      );
    } else if (showAsCorrect) {
      tileGradient = const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      borderColor = Colors.transparent;
      textColor = Colors.white;
      badgeBgColor = Colors.white.withValues(alpha: 0.25);
      badgeTextColor = Colors.white;
      rightIcon = const Icon(
        Icons.check_circle_rounded,
        color: Colors.white,
        size: 22,
      );
    } else if (showAsWrong) {
      tileGradient = const LinearGradient(
        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      borderColor = Colors.transparent;
      textColor = Colors.white;
      badgeBgColor = Colors.white.withValues(alpha: 0.25);
      badgeTextColor = Colors.white;
      rightIcon = const Icon(
        Icons.cancel_rounded,
        color: Colors.white,
        size: 22,
      );
    } else if (isSelected) {
      tileBgColor = isDark ? AppColors.primary.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.08);
      borderColor = AppColors.primary;
      textColor = isDark ? Colors.white : AppColors.primary;
      badgeBgColor = AppColors.primary;
      badgeTextColor = Colors.white;
      rightIcon = const Icon(
        Icons.circle_rounded,
        color: AppColors.primary,
        size: 16,
      );
    } else {
      tileBgColor = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white;
      borderColor = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.05);
      textColor = isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.textPrimaryLight;
      badgeBgColor = isDark
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFFF1F5F9);
      badgeTextColor = AppColors.primary;
    }

    Widget container = Semantics(
      label: 'Option ${_labels[index % _labels.length]}. $text',
      selected: isSelected,
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: isEliminated ? 0.2 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: tileBgColor,
              gradient: tileGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
                width: (isSelected || showAsCorrect || showAsWrong) ? 2.0 : 1.5,
              ),
              boxShadow: (isSelected || showAsCorrect || showAsWrong)
                  ? [
                      BoxShadow(
                        color: (showAsCorrect 
                                ? AppColors.success 
                                : showAsWrong 
                                    ? AppColors.error 
                                    : AppColors.primary)
                            .withValues(alpha: isDark ? 0.3 : 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : (isEliminated
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                      ),
                    ]),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: badgeBgColor,
                    border: Border.all(
                      color: (isSelected || showAsCorrect || showAsWrong)
                          ? Colors.white.withValues(alpha: 0.4)
                          : (isEliminated
                              ? Colors.transparent
                              : AppColors.primary.withValues(alpha: 0.15)),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _labels[index % _labels.length],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: badgeTextColor,
                      decoration: isEliminated ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    text,
                    style: isBengali
                        ? AppTheme.bengaliStyle(
                            fontSize: 14.5,
                            color: textColor,
                          ).copyWith(
                            decoration: isEliminated ? TextDecoration.lineThrough : null,
                          )
                        : TextStyle(
                              color: textColor,
                              fontSize: 14.5,
                              fontWeight: (isSelected || showAsCorrect || showAsWrong) 
                                  ? FontWeight.w700 
                                  : FontWeight.w500,
                              decoration: isEliminated ? TextDecoration.lineThrough : null,
                            ),
                  ),
                ),
                if (rightIcon != null) rightIcon,
              ],
            ),
          ),
        ),
      ),
    );

    // Apply horizontal shake animation for incorrect choice
    if (showAsWrong && wrongAnimation != null) {
      final shakeTranslation = TweenSequence<double>([
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 0.0, end: 10.0),
          weight: 1,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 10.0, end: -10.0),
          weight: 2,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: -10.0, end: 10.0),
          weight: 2,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 10.0, end: -10.0),
          weight: 2,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: -10.0, end: 0.0),
          weight: 1,
        ),
      ]);
      return AnimatedBuilder(
        animation: wrongAnimation!,
        builder: (context, child) {
          final offset = shakeTranslation.transform(wrongAnimation!.value);
          return Transform.translate(
            offset: Offset(offset, 0),
            child: child,
          );
        },
        child: container,
      );
    }

    // Apply scale bounce animation for correct choice
    if (showAsCorrect && correctAnimation != null) {
      final scaleBounce = TweenSequence<double>([
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 1.0, end: 1.04),
          weight: 1,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 1.04, end: 0.98),
          weight: 1,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 0.98, end: 1.0),
          weight: 1,
        ),
      ]);
      return AnimatedBuilder(
        animation: correctAnimation!,
        builder: (context, child) {
          final scale = scaleBounce.transform(correctAnimation!.value);
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: container,
      );
    }

    return container;
  }
}
