// lib/presentation/widgets/quiz/quiz_progress_stepper.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class QuizProgressStepper extends StatelessWidget {
  final int current;
  final int total;
  final String lang;

  const QuizProgressStepper({
    super.key,
    required this.current,
    required this.total,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = total > 0 ? current / total : 0.0;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    final text = isBn
        ? 'প্রশ্ন $current এর $total'
        : isHi
            ? 'प्रश्न $current का $total'
            : 'Question $current of $total';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppColors.textPrimaryLight,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 6,
              width: MediaQuery.of(context).size.width * progress * 0.9, // Adjust width based on screen width
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
