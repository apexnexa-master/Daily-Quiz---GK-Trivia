// lib/presentation/widgets/quiz/question_card.dart
import 'package:flutter/material.dart';
import '../../../../data/models/firestore_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'option_button.dart';

class QuestionCard extends StatelessWidget {
  final QuestionModel question;
  final String lang;
  final int? selectedAnswer;
  final ValueChanged<int> onAnswerSelected;
  final bool isDark;
  final Set<int>? visibleOptions;
  final AnimationController? correctAnimationController;
  final AnimationController? wrongAnimationController;
  final int? selectedForFeedback;
  final bool? isCorrectFeedback;

  const QuestionCard({
    super.key,
    required this.question,
    required this.lang,
    required this.selectedAnswer,
    required this.onAnswerSelected,
    required this.isDark,
    this.visibleOptions,
    this.correctAnimationController,
    this.wrongAnimationController,
    this.selectedForFeedback,
    this.isCorrectFeedback,
  });

  Color _difficultyColor(String d) {
    switch (d.toLowerCase()) {
      case 'easy':
        return AppColors.success;
      case 'hard':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final questionText = question.getText(lang);
    final options = question.getOptions(lang);
    final isBengali = lang == 'bn';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question text card
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: BoxDecoration(
              gradient: isDark
                  ? LinearGradient(
                      colors: [
                        AppColors.cardDark,
                        AppColors.surfaceElevatedDark.withValues(alpha: 0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white,
                        const Color(0xFFF8FAFC),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : AppColors.primary)
                      .withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        question.category.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _difficultyColor(question.difficulty)
                            .withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _difficultyColor(question.difficulty)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        question.difficulty.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _difficultyColor(question.difficulty),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  questionText,
                  style: isBengali
                      ? AppTheme.bengaliStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)
                      : Theme.of(context).textTheme.titleLarge?.copyWith(
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Options List
          ...options.asMap().entries.map((entry) {
            final i = entry.key;
            if (visibleOptions != null && !visibleOptions!.contains(i)) {
              return const SizedBox.shrink();
            }
            final text = entry.value;
            final isSelected = selectedAnswer == i;
            return OptionButton(
              index: i,
              text: text,
              isSelected: isSelected,
              isBengali: isBengali,
              isDark: isDark,
              onTap: selectedAnswer == null
                  ? () => onAnswerSelected(i)
                  : null,
              isCorrectFeedback: selectedForFeedback == i
                  ? isCorrectFeedback
                  : null,
              correctAnimation: correctAnimationController,
              wrongAnimation: wrongAnimationController,
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
