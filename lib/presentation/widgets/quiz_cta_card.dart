// lib/presentation/widgets/quiz_cta_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_animations.dart';
import '../../core/services/quiz_scheduler_service.dart';
import '../../data/models/firestore_models.dart';
import '../providers/app_providers.dart';
import '../utils/daily_challenge_auth.dart';

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
    const accent = AppColors.gamingCyan;
    const cardGradient = LinearGradient(
      colors: [Color(0xFF20262F), Color(0xFF171C24)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.gamingBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.10 : 0.08),
            blurRadius: 28,
            spreadRadius: -8,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
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
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isQuizActive) ...[
                        PulseWidget(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isQuizActive
                                  ? (isBn ? 'আজকের চ্যালেঞ্জ' : isHi ? 'आज की चुनौती' : "Today's Challenge")
                                  : (isBn ? 'চ্যালেঞ্জ অপেক্ষায়' : isHi ? 'चुनौती प्रतीक्षा में' : 'Challenge Pending'),
                              style: const TextStyle(
                                fontSize: 10.5,
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
                            fontSize: 10.5,
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getExamTitle(examMode, isBn, isHi),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildChip(AppIcons.timer, '$mins min'),
                      const SizedBox(width: 8),
                      _buildChip(Icons.help_outline_rounded, '$qCount Q'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildChip(
                          Icons.timer_outlined,
                          _getStatusText(scheduler, isQuizActive, isBn, isHi),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AnimatedScaleButton(
                    onTap: isQuizActive
                        ? () {
                            if (!DailyChallengeAuth.canStart(ref)) {
                              DailyChallengeAuth.requireLogin(context, ref);
                              return;
                            }
                            ref.read(quizSessionProvider.notifier).startQuiz(quiz!);
                            Navigator.pushNamed(context, '/quiz');
                          }
                        : null,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isQuizActive
                            ? accent
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isQuizActive
                              ? accent
                              : AppColors.gamingBorder,
                        ),
                        boxShadow: isQuizActive ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.28),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          )
                        ] : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           Icon(
                            isQuizActive ? Icons.play_arrow_rounded : Icons.lock_rounded,
                            color: isQuizActive ? AppColors.gamingBg : Colors.white54,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isQuizActive 
                                ? (isBn ? 'চ্যালেঞ্জ শুরু করুন' : isHi ? 'चुनौती शुरू करें' : 'START CHALLENGE')
                                : (isBn ? 'লক করা আছে' : isHi ? 'लॉक है' : 'LOCKED'),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: isQuizActive ? AppColors.gamingBg : Colors.white54,
                            ),
                          ),
                        ],
                      ),
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
              ? 'আজকের চ্যালেঞ্জ $hours ঘণ্টা $mins মিনিটে শুরু'
              : isHi
                  ? 'आज की चुनौती $hours घंटे $mins मिनट में शुरू'
                  : "Today's challenge starts in ${hours}h ${mins}m";
        } else {
          return isBn
              ? 'আজকের চ্যালেঞ্জ $mins মিনিটে শুরু'
              : isHi
                  ? 'आज की चुनौती $mins मिनट में शुरू'
                  : "Today's challenge starts in $mins min";
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
        gradient: const LinearGradient(
          colors: [Color(0xFF20262F), Color(0xFF171C24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.gamingBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gamingCyan.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.gamingCyan.withValues(alpha: 0.28),
              ),
            ),
            child: const Icon(Icons.stars_rounded, size: 40, color: AppColors.gamingCyan),
          ),
          const SizedBox(height: 16),
          Text(
            isBn ? 'আজকের চ্যালেঞ্জ নেই' : isHi ? 'आज कोई चुनौती नहीं है' : 'No Challenge Today',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isBn
                ? 'আজকের চ্যালেঞ্জ পরে পরীক্ষা করুন বা অনুশীলন মোড খেলুন।'
                : isHi
                    ? 'आज की चुनौती के लिए बाद में देखें या अभ्यास मोड खेलें।'
                    : "Check back later for today's challenge or practice below.",
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.gamingTextSecondary,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
