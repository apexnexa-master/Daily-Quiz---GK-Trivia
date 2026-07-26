// lib/presentation/widgets/quiz_cta_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
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
      return _buildEmptyState(context, isDark, isBn, isHi);
    }

    final qCount = quiz!.questionCount;
    final mins = (qCount * 30 / 60).clamp(1, 99).toInt();
    final examMode = quiz!.examMode;
    final cardGradient = LinearGradient(
      colors: isDark 
          ? [const Color(0xFF064E3B), const Color(0xFF0F766E), const Color(0xFF0891B2)]
          : [const Color(0xFF10B981), const Color(0xFF0D9488), const Color(0xFF06B6D4)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: isDark ? 0.35 : 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Ambient design elements
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
                                  ? (isBn ? 'আজকের চ্যালেঞ্জ' : isHi ? 'आज की चुनौती' : "Today's Challenge")
                                  : (isBn ? 'চ্যালেঞ্জ অপেক্ষায়' : isHi ? 'चुनौती प्रतीक्षा में' : 'Challenge Pending'),
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
                          examMode,
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
                    _getExamTitle(examMode, isBn, isHi),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isBn
                        ? 'প্রতিদিন একটি নতুন কুইজ চ্যালেঞ্জ খেলুন এবং আপনার স্কোর উন্নত করুন।'
                        : isHi
                            ? 'हर दिन एक नया क्विज़ खेलें और अपना स्कोर सुधारें।'
                            : 'Play a fresh daily challenge every day and improve your scores.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
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
                  AnimatedScaleButton(
                    onTap: isQuizActive
                        ? () {
                            ref.read(quizSessionProvider.notifier).startQuiz(quiz!);
                            Navigator.pushNamed(context, '/quiz');
                          }
                        : null,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isQuizActive ? Colors.white : Colors.white24,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isQuizActive ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ] : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isQuizActive ? Icons.play_arrow_rounded : Icons.lock_rounded,
                            color: isQuizActive ? const Color(0xFF0D9488) : Colors.white70,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isQuizActive 
                                ? (isBn ? 'চ্যালেঞ্জ শুরু করুন' : isHi ? 'चुनौती शुरू करें' : 'START CHALLENGE NOW')
                                : (isBn ? 'লক করা আছে' : isHi ? 'लॉक है' : 'LOCKED'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: isQuizActive ? const Color(0xFF0D9488) : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.white70, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _getStatusText(scheduler, isQuizActive, isBn, isHi),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
              ? 'চ্যালেঞ্জ $hours ঘণ্টা $mins মিনিটে শেষ হবে'
              : isHi
                  ? 'चुनौती $hours घंटे $mins मिनट में समाप्त होगी'
                  : 'Challenge ends in ${hours}h ${mins}m';
        } else {
          return isBn
              ? 'চ্যালেঞ্জ $mins মিনিটে শেষ হবে'
              : isHi
                  ? 'चुनौती $mins मिनट में समाप्त होगी'
                  : 'Challenge ends in $mins min';
        }
      } else {
        return isBn ? 'চ্যালেঞ্জ শেষ হয়ে গেছে' : isHi ? 'चुनौती समाप्त हो गई' : 'Challenge has ended';
      }
    } else {
      if (currentMinutes < startMinutes) {
        final waitMinutes = startMinutes - currentMinutes;
        final hours = waitMinutes ~/ 60;
        final mins = waitMinutes % 60;
        if (hours > 0) {
          return isBn
              ? 'দৈনিক চ্যালেঞ্জ $hours ঘণ্টা $mins মিনিটে শুরু'
              : isHi
                  ? 'दैनिक चुनौती $hours घंटे $mins मिनट में शुरू'
                  : 'Daily challenge starts in ${hours}h ${mins}m';
        } else {
          return isBn
              ? 'দৈনিক চ্যালেঞ্জ $mins মিনিটে শুরু'
              : isHi
                  ? 'दैनिक चुनौती $mins मिनट में शुरू'
                  : 'Daily challenge starts in $mins min';
        }
      } else {
        return isBn ? 'আজকের চ্যালেঞ্জ শেষ হয়ে গেছে' : isHi ? 'आज की चुनौती समाप्त हो गई' : "Today's challenge has ended";
      }
    }
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, bool isBn, bool isHi) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
            AppColors.secondary.withValues(alpha: isDark ? 0.08 : 0.04),
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
            child: const Icon(Icons.stars_rounded, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            isBn ? 'আজকের চ্যালেঞ্জ নেই' : isHi ? 'आज कोई चुनौती नहीं है' : 'No Challenge Today',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isBn
                ? 'দৈনিক চ্যালেঞ্জগুলি পরে পরীক্ষা করুন বা অনুশীলন মোড খেলুন।'
                : isHi
                    ? 'दैनिक चुनौती के लिए बाद में देखें या अभ्यास मोड खेलें।'
                    : 'Check back later for the next daily challenge or practice below.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
      default:
        return mode;
    }
  }
}
