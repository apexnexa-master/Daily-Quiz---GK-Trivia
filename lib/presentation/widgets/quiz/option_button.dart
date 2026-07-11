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
    this.isCorrectFeedback,
    this.correctAnimation,
    this.wrongAnimation,
  });

  static const _labels = ['A', 'B', 'C', 'D'];
  static const _colors = [
    Color(0xFF6366F1),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];

  Color get _optionColor => _colors[index % _colors.length];

  Color _getTileColor() {
    if (isCorrectFeedback != null) {
      return isCorrectFeedback! 
          ? AppColors.success.withValues(alpha: 0.15)
          : AppColors.error.withValues(alpha: 0.15);
    }
    return isSelected ? _optionColor : (isDark ? AppColors.cardDark : Colors.white);
  }

  Border? _getBorder() {
    if (isCorrectFeedback != null) {
      return Border.all(
        color: isCorrectFeedback! ? AppColors.success : AppColors.error,
        width: 2.0,
      );
    }
    return Border.all(
      color: isSelected
          ? Colors.transparent
          : (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.15)),
      width: 1.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget container = Semantics(
      label: 'Option ${_labels[index % _labels.length]}. $text',
      selected: isSelected,
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: _getTileColor(),
            borderRadius: BorderRadius.circular(16),
            border: _getBorder(),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _optionColor.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Option Prefix Badge (A, B, C, D)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : (isDark
                          ? AppColors.surfaceElevatedDark
                          : const Color(0xFFF1F5F9)),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.5)
                        : _optionColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _labels[index % _labels.length],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isSelected 
                        ? Colors.white 
                        : (isCorrectFeedback != null
                            ? (isCorrectFeedback! ? AppColors.success : AppColors.error)
                            : _optionColor),
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
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white : null))
                      : Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white : null),
                            fontWeight: FontWeight.w500,
                          ),
                ),
              ),
              // Feedback icon
              if (isCorrectFeedback != null)
                Icon(
                  isCorrectFeedback! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isCorrectFeedback! ? AppColors.success : AppColors.error,
                  size: 22,
                )
              else if (isSelected)
                Icon(Icons.check_circle_rounded,
                    color: Colors.white.withValues(alpha: 0.9), size: 22),
            ],
          ),
        ),
      ),
    );

    // Apply animations for feedback if present
    if (isCorrectFeedback != null &&
        (correctAnimation != null || wrongAnimation != null)) {
      if (isCorrectFeedback == true && correctAnimation != null) {
        return AnimatedBuilder(
          animation: correctAnimation!,
          builder: (context, child) {
            final value = Curves.elasticOut.transform(correctAnimation!.value);
            return Transform.scale(
              scale: 1.0 + (0.15 * value),
              child: child,
            );
          },
          child: container,
        );
      } else if (isCorrectFeedback == false && wrongAnimation != null) {
        return AnimatedBuilder(
          animation: wrongAnimation!,
          builder: (context, child) {
            final value = Curves.elasticOut.transform(wrongAnimation!.value);
            final shake = 10.0 *
                (1 - value) *
                (wrongAnimation!.value < 0.5
                    ? (wrongAnimation!.value * 4).floor() % 2 == 0
                        ? 1
                        : -1
                    : -((wrongAnimation!.value * 4).floor() % 2 == 0 ? 1 : -1));
            return Transform.translate(
              offset: Offset(shake * (1 - value), 0),
              child: child,
            );
          },
          child: container,
        );
      }
    }

    return container;
  }
}
