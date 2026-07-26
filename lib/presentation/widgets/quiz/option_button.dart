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
  });

  static const _labels = ['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    // Determine clean, non-confusing neutral colors
    final baseBg = isDark ? AppColors.cardDark : Colors.white;

    Color tileBgColor;
    Color borderColor;
    Color textColor;
    Color badgeBgColor;
    Color badgeTextColor;
    Widget? rightIcon;

    if (showAsCorrect) {
      tileBgColor = AppColors.success;
      borderColor = AppColors.success;
      textColor = Colors.white;
      badgeBgColor = Colors.white.withValues(alpha: 0.25);
      badgeTextColor = Colors.white;
      rightIcon = const Icon(
        Icons.check_circle_rounded,
        color: Colors.white,
        size: 22,
      );
    } else if (showAsWrong) {
      tileBgColor = AppColors.error;
      borderColor = AppColors.error;
      textColor = Colors.white;
      badgeBgColor = Colors.white.withValues(alpha: 0.25);
      badgeTextColor = Colors.white;
      rightIcon = const Icon(
        Icons.cancel_rounded,
        color: Colors.white,
        size: 22,
      );
    } else if (isSelected) {
      tileBgColor = AppColors.primary;
      borderColor = AppColors.primary;
      textColor = Colors.white;
      badgeBgColor = Colors.white.withValues(alpha: 0.25);
      badgeTextColor = Colors.white;
      rightIcon = const Icon(
        Icons.check_circle_rounded,
        color: Colors.white,
        size: 22,
      );
    } else {
      tileBgColor = baseBg;
      borderColor = isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.grey.withValues(alpha: 0.2);
      textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
      badgeBgColor = isDark
          ? Colors.white.withValues(alpha: 0.08)
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: tileBgColor,
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
                          .withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Option Prefix Badge (A, B, C, D)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badgeBgColor,
                  border: Border.all(
                    color: (isSelected || showAsCorrect || showAsWrong)
                        ? Colors.white.withValues(alpha: 0.4)
                        : AppColors.primary.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _labels[index % _labels.length],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: badgeTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Option Text
              Expanded(
                child: Text(
                  text,
                  style: isBengali
                      ? AppTheme.bengaliStyle(
                          fontSize: 15,
                          color: textColor,
                        )
                      : Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: textColor,
                            fontWeight: (isSelected || showAsCorrect || showAsWrong) 
                                ? FontWeight.w700 
                                : FontWeight.w500,
                          ),
                ),
              ),
              // Clean selection feedback indicator icon
              if (rightIcon != null) rightIcon,
            ],
          ),
        ),
      ),
    );

    return container;
  }
}
