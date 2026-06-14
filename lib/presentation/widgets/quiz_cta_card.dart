// lib/presentation/widgets/quiz_cta_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/quiz_scheduler_service.dart';
import '../../data/models/firestore_models.dart';
import '../providers/app_providers.dart';

class QuizCtaCard extends ConsumerWidget {
  final QuizModel? quiz;
  final String lang;
  final WidgetRef ref;

  const QuizCtaCard({
    super.key,
    this.quiz,
    required this.lang,
    required this.ref,
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
        gradient:
            isDark ? AppTheme.primaryGradientDark : AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8)),
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
                      shape: BoxShape.circle))),
          Positioned(
              right: 20,
              bottom: -40,
              child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle))),
          Positioned(
              left: -20,
              top: 40,
              child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle))),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: isQuizActive
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.orange.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              isQuizActive
                                  ? Icons.auto_awesome
                                  : Icons.schedule,
                              size: 12,
                              color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                              isQuizActive
                                  ? (isBn
                                      ? 'আজকের কুইজ'
                                      : isHi
                                          ? 'आज का क्विज़'
                                          : "Today's Quiz")
                                  : (isBn
                                      ? 'কুইজ অপেক্ষায়'
                                      : isHi
                                          ? 'क्विज़ प्रतीक्षा में'
                                          : 'Quiz Pending'),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(quiz!.examMode,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _getExamTitle(quiz!.examMode, isBn, isHi),
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1),
                ),
                const SizedBox(height: 6),
                Text(
                  isBn
                      ? '$qCount টি প্রশ্ন · $mins মিনিট'
                      : isHi
                          ? '$qCount प्रश्न · $mins मिनट'
                          : '$qCount Questions · $mins min',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildChip(Icons.timer_outlined, '$mins min', isDark),
                    const SizedBox(width: 10),
                    _buildChip(Icons.help_outline_rounded, '$qCount Q', isDark),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: isQuizActive
                            ? () {
                                ref
                                    .read(quizSessionProvider.notifier)
                                    .startQuiz(quiz!);
                                Navigator.pushNamed(context, '/quiz');
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isQuizActive
                                ? Colors.white
                                : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                  isQuizActive
                                      ? Icons.play_arrow_rounded
                                      : Icons.schedule,
                                  color: isQuizActive
                                      ? AppTheme.primaryColor
                                      : Colors.white,
                                  size: 20),
                              const SizedBox(width: 4),
                              Text(
                                isBn
                                    ? 'শুরু করুন'
                                    : isHi
                                        ? 'शुरू करें'
                                        : 'Start',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isQuizActive
                                        ? AppTheme.primaryColor
                                        : Colors.white),
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
                const SizedBox(height: 8),
                Text(
                  _getStatusText(scheduler, isQuizActive, isBn, isHi),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 10),
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
    final startMinutes =
        scheduler.quizStartHour * 60 + scheduler.quizStartMinute;
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
        return isBn
            ? 'কুইজ শেষ হয়ে গেছে'
            : isHi
                ? 'क्विज़ समाप्त हो गया'
                : 'Quiz has ended';
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
        return isBn
            ? 'আজকের কুইজ শেষ হয়ে গেছে'
            : isHi
                ? 'आज का क्विज़ समाप्त हो गया'
                : "Today's quiz has ended";
      }
    }
  }

  Widget _buildPracticeButton(
      BuildContext context, WidgetRef ref, bool isDark, bool isBn, bool isHi) {
    return PopupMenuButton<int>(
      onSelected: (count) => _startPracticeMode(context, ref, count),
      color: isDark ? AppTheme.cardDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      offset: const Offset(0, -120),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.school_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 4),
            Text(
              isBn
                  ? 'অনুশীলন'
                  : isHi
                      ? 'अभ्यास'
                      : 'Practice',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
          ],
        ),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 5,
          child: Row(
            children: [
              const Icon(Icons.bolt, color: AppTheme.warningColor, size: 18),
              const SizedBox(width: 8),
              Text(isBn
                  ? '5 প্রশ্ন (দ্রুত)'
                  : isHi
                      ? '5 प्रश्न (तेज़)'
                      : '5 Questions (Quick)'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 10,
          child: Row(
            children: [
              const Icon(Icons.timer, color: AppTheme.primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(isBn
                  ? '10 প্রশ্ন'
                  : isHi
                      ? '10 प्रश्न'
                      : '10 Questions'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 15,
          child: Row(
            children: [
              const Icon(Icons.hourglass_bottom,
                  color: AppTheme.secondaryColor, size: 18),
              const SizedBox(width: 8),
              Text(isBn
                  ? '15 প্রশ্ন (সম্পূর্ণ)'
                  : isHi
                      ? '15 प्रश्न (पूर्ण)'
                      : '15 Questions (Full)'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 20,
          child: Row(
            children: [
              const Icon(Icons.emoji_events,
                  color: AppTheme.successColor, size: 18),
              const SizedBox(width: 8),
              Text(isBn
                  ? '20 প্রশ্ন (মারাঠা)'
                  : isHi
                      ? '20 प्रश्न (मराठा)'
                      : '20 Questions (Marathon)'),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _startPracticeMode(
      BuildContext context, WidgetRef ref, int questionCount) async {
    final examMode = ref.read(examModeProvider);
    final quizService = ref.read(quizServiceProvider);

    final practiceQuiz = await quizService.fetchPracticeQuiz(
      examMode: examMode,
      questionCount: questionCount,
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
            AppTheme.primaryColor.withValues(alpha: isDark ? 0.3 : 0.1),
            AppTheme.secondaryColor.withValues(alpha: isDark ? 0.2 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle),
            child: const Icon(Icons.school_rounded,
                size: 40, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
              isBn
                  ? 'অনুশীলন মোড'
                  : isHi
                      ? 'अभ्यास मोड'
                      : 'Practice Mode',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 4),
          Text(
              isBn
                  ? 'যেকোনো সময় অনুশীলন করুন'
                  : isHi
                      ? 'कभी भी अभ्यास करें'
                      : 'Practice anytime with new questions',
              style: TextStyle(
                  fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
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
    return InkWell(
      onTap: () => _startPracticeMode(context, ref, count),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.primaryColor,
              ),
            ),
            Text(
              'Q',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
    );
  }

  String _getExamTitle(String mode, bool isBn, bool isHi) {
    switch (mode) {
      case 'GENERAL':
        return isBn
            ? 'সাধারণ জ্ঞান'
            : isHi
                ? 'সামান্য জ্ঞান'
                : 'General Knowledge';
      case 'WBPSC':
        return 'WBPSC';
      case 'SSC':
        return 'SSC';
      case 'UPSC':
        return 'UPSC';
      case 'BANK':
        return 'Bank PO';
      default:
        return mode;
    }
  }
}
