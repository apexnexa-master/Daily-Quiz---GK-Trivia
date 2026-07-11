// lib/presentation/widgets/result/question_review_card.dart
import 'package:flutter/material.dart';
import '../../../../data/models/firestore_models.dart';
import '../../../core/theme/app_colors.dart';
import '../quiz/explanation_panel.dart';

class QuestionReviewCard extends StatelessWidget {
  final QuestionModel question;
  final int index;
  final int? userAnswer;
  final bool isCorrect;
  final bool isSkipped;
  final List<String> options;
  final String lang;
  final bool isDark;

  const QuestionReviewCard({
    super.key,
    required this.question,
    required this.index,
    required this.userAnswer,
    required this.isCorrect,
    required this.isSkipped,
    required this.options,
    required this.lang,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isBn = lang == 'bn';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isCorrect
                  ? AppColors.success
                  : isSkipped
                      ? Colors.grey
                      : AppColors.error)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header with status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: (isCorrect
                      ? AppColors.success
                      : isSkipped
                          ? Colors.grey
                          : AppColors.error)
                  .withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: (isCorrect
                            ? AppColors.success
                            : isSkipped
                                ? Colors.grey
                                : AppColors.error)
                        .withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isCorrect
                          ? AppColors.success
                          : isSkipped
                              ? Colors.grey
                              : AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isCorrect
                      ? Icons.check_circle_rounded
                      : isSkipped
                          ? Icons.remove_circle_outline_rounded
                          : Icons.cancel_rounded,
                  color: isCorrect
                      ? AppColors.success
                      : isSkipped
                          ? Colors.grey
                          : AppColors.error,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  isCorrect
                      ? (isBn ? 'সঠিক' : 'Correct')
                      : isSkipped
                          ? (isBn ? 'এড়িয়ে গেছে' : 'Skipped')
                          : (isBn ? 'ভুল' : 'Wrong'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isCorrect
                        ? AppColors.success
                        : isSkipped
                            ? Colors.grey
                            : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          
          // Question Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.getText(lang),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Correct Option box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: isDark ? 0.1 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.success, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          options.length > question.correctIndex
                              ? options[question.correctIndex]
                              : '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // User's Wrong Option box (if answered incorrectly)
                if (!isCorrect && !isSkipped && userAnswer != null && userAnswer! >= 0 && userAnswer! < options.length) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: isDark ? 0.08 : 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cancel_rounded,
                            color: AppColors.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            options[userAnswer!],
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Explanation Panel (collapsible)
                const SizedBox(height: 12),
                ExplanationPanel(
                  explanation: question.getExplanation(lang),
                  lang: lang,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
