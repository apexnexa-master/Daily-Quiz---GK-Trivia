// lib/presentation/widgets/quiz_cta_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_animations.dart';
import '../../core/services/quiz_scheduler_service.dart';
import '../../data/models/firestore_models.dart';
import '../providers/app_providers.dart';

class QuizCtaCard extends ConsumerWidget {
  final QuizModel? quiz;
  final String lang;

  const QuizCtaCard({
    super.key,
    this.quiz,
    required this.lang,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final scheduler = QuizSchedulerService.instance;
    final isQuizActive = scheduler.isQuizActive();

    if (quiz == null) {
      return _buildEmptyState(context, isDark, isBn, isHi, ref);
    }

    final qCount = quiz!.questionCount;
    final mins = (qCount * 30 / 60).clamp(1, 99).toInt();

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.primaryGradientDark : AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -40,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isQuizActive
                            ? Colors.white.withValues(alpha: 0.2)
                            : AppColors.warning.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isQuizActive ? Icons.auto_awesome_rounded : Icons.schedule_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isQuizActive
                                ? (isBn ? 'আজকের কুইজ' : isHi ? 'आज का क्विज़' : "Today's Quiz")
                                : (isBn ? 'কুইজ অপেক্ষায়' : isHi ? 'क्विज़ प्रतीक्षा में' : 'Quiz Pending'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        quiz!.examMode,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _getExamTitle(quiz!.examMode, isBn, isHi),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isBn
                      ? '$qCount টি প্রশ্ন · $mins মিনিট'
                      : isHi
                          ? '$qCount प्रश्न · $mins मिनट'
                          : '$qCount Questions · $mins min',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildChip(AppIcons.timer, '$mins min'),
                    const SizedBox(width: 8),
                    _buildChip(Icons.help_outline_rounded, '$qCount Q'),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedScaleButton(
                        onTap: isQuizActive
                            ? () {
                                ref.read(quizSessionProvider.notifier).startQuiz(quiz!);
                                Navigator.pushNamed(context, '/quiz');
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isQuizActive ? Colors.white : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isQuizActive ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ] : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isQuizActive ? Icons.play_arrow_rounded : Icons.schedule_rounded,
                                color: isQuizActive ? AppColors.primary : Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isBn ? 'শুরু করুন' : isHi ? 'शुरू करें' : 'Start Now',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isQuizActive ? AppColors.primary : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildPracticeButton(context, ref, isDark, isBn, isHi),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _getStatusText(scheduler, isQuizActive, isBn, isHi),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    isBn
                        ? '💡 নতুন প্রশ্ন সব সময়!'
                        : isHi
                            ? '💡 हमेशा नए प्रश्न!'
                            : '💡 Always new questions!',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(
      QuizSchedulerService scheduler, bool isQuizActive, bool isBn, bool isHi) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = scheduler.quizStartHour * 60 + scheduler.quizStartMinute;
    final endMinutes = scheduler.quizEndHour * 60 + scheduler.quizEndMinute;

    if (isQuizActive) {
      final remainingMinutes = endMinutes - currentMinutes;
      if (remainingMinutes > 0) {
        final hours = remainingMinutes ~/ 60;
        final mins = remainingMinutes % 60;
        if (hours > 0) {
          return isBn
              ? 'কুইজ $hours ঘণ্টা $mins মিনিটে শেষ হবে'
              : isHi
                  ? 'क्विज़ $hours घंटे $mins मिनट में समाप्त होगा'
                  : 'Quiz ends in ${hours}h ${mins}m';
        } else {
          return isBn
              ? 'কুইজ $mins মিনিটে শেষ হবে'
              : isHi
                  ? 'क्विज़ $mins मिनट में समाप्त होगा'
                  : 'Quiz ends in $mins min';
        }
      } else {
        return isBn ? 'কুইজ শেষ হয়ে গেছে' : isHi ? 'क्विज़ समाप्त हो गया' : 'Quiz has ended';
      }
    } else {
      if (currentMinutes < startMinutes) {
        final waitMinutes = startMinutes - currentMinutes;
        final hours = waitMinutes ~/ 60;
        final mins = waitMinutes % 60;
        if (hours > 0) {
          return isBn
              ? 'দৈনিক কুইজ $hours ঘণ্টা $mins মিনিটে শুরু'
              : isHi
                  ? 'दैनिक क्विज़ $hours घंटे $mins मिनट में शुरू'
                  : 'Daily quiz starts in ${hours}h ${mins}m';
        } else {
          return isBn
              ? 'দৈনিক কুইজ $mins মিনিটে শুরু'
              : isHi
                  ? 'दैनिक क्विज़ $mins मिनट में शुरू'
                  : 'Daily quiz starts in $mins min';
        }
      } else {
        return isBn ? 'আজকের কুইজ শেষ হয়ে গেছে' : isHi ? 'आज का क्विज़ समाप्त हो गया' : "Today's quiz has ended";
      }
    }
  }

  Widget _buildPracticeButton(
      BuildContext context, WidgetRef ref, bool isDark, bool isBn, bool isHi) {
    return InkWell(
      onTap: () => _showPracticeBottomSheet(context, ref, isDark, isBn, isHi),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.school_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              isBn ? 'অনুশীলন' : isHi ? 'अभ्यास' : 'Practice',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPracticeBottomSheet(
      BuildContext context, WidgetRef ref, bool isDark, bool isBn, bool isHi) {
    int selectedCount = 10;
    String selectedDifficulty = 'All';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2F) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isBn ? 'অনুশীলন কনফিগার করুন' : isHi ? 'अभ्यास कॉन्फ़िगर करें' : 'Configure Practice',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isBn ? 'প্রশ্নের সংখ্যা' : isHi ? 'प्रश्नों की संख्या' : 'Number of Questions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [5, 10, 15, 20].map((count) {
                      final selected = selectedCount == count;
                      return ChoiceChip(
                        label: Text('$count'),
                        selected: selected,
                        onSelected: (val) {
                          if (val) setModalState(() => selectedCount = count);
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isBn ? 'অসুবিধা স্তর' : isHi ? 'कठिनाई स्तर' : 'Difficulty Level',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['All', 'Easy', 'Medium', 'Hard'].map((diff) {
                      final selected = selectedDifficulty == diff;
                      return ChoiceChip(
                        label: Text(isBn
                            ? (diff == 'All' ? 'সব' : diff == 'Easy' ? 'সহজ' : diff == 'Medium' ? 'মাঝারি' : 'কঠিন')
                            : isHi
                                ? (diff == 'All' ? 'सभी' : diff == 'Easy' ? 'आसान' : diff == 'Medium' ? 'मध्यम' : 'कठिन')
                                : diff),
                        selected: selected,
                        onSelected: (val) {
                          if (val) setModalState(() => selectedDifficulty = diff);
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _startPracticeMode(context, ref, selectedCount, selectedDifficulty);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        isBn ? 'অনুশীলন শুরু করুন' : isHi ? 'अभ्यास शुरू करें' : 'Start Practice',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _startPracticeMode(
      BuildContext context, WidgetRef ref, int questionCount, String difficulty) async {
    final examMode = ref.read(examModeProvider);
    final quizService = ref.read(quizServiceProvider);

    final practiceQuiz = await quizService.fetchPracticeQuiz(
      examMode: examMode,
      questionCount: questionCount,
      difficulty: difficulty == 'All' ? null : difficulty.toLowerCase(),
    );

    if (practiceQuiz != null && context.mounted) {
      ref.read(quizSessionProvider.notifier).startQuiz(practiceQuiz);
      Navigator.pushNamed(context, '/quiz');
    }
  }

  Widget _buildEmptyState(
      BuildContext context, bool isDark, bool isBn, bool isHi, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.08),
            AppColors.level.withValues(alpha: isDark ? 0.15 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_rounded, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            isBn ? 'অনুশীলন মোড' : isHi ? 'अभ्यास मोड' : 'Practice Mode',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isBn
                ? 'যেকোনো সময় অনুশীলন করুন'
                : isHi
                    ? 'कभी भी अभ्यास करें'
                    : 'Practice anytime with new questions',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPracticeStartButton(context, ref, 5, isDark, isBn, isHi),
              const SizedBox(width: 10),
              _buildPracticeStartButton(context, ref, 10, isDark, isBn, isHi),
              const SizedBox(width: 10),
              _buildPracticeStartButton(context, ref, 15, isDark, isBn, isHi),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeStartButton(BuildContext context, WidgetRef ref,
      int count, bool isDark, bool isBn, bool isHi) {
    return AnimatedScaleButton(
      onTap: () => _startPracticeMode(context, ref, count, 'All'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            Text(
              'Q',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _getExamTitle(String mode, bool isBn, bool isHi) {
    switch (mode) {
      case 'GENERAL':
        return isBn ? 'সাধারণ জ্ঞান' : isHi ? 'सामान्य ज्ञान' : 'General Knowledge';
      case 'WBPSC':
        return 'WBPSC Exam';
      case 'SSC':
        return 'SSC Exam';
      case 'UPSC':
        return 'UPSC Exam';
      case 'BANK':
        return 'Bank PO';
      default:
        return mode;
      }
  }
}
