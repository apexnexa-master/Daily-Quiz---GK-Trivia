// lib/presentation/widgets/practice_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_animations.dart';
import '../../core/services/quiz/practice_quiz_service.dart';
import '../providers/app_providers.dart';
import 'soft_duotone_icon.dart';

class PracticeArenaCard extends ConsumerStatefulWidget {
  final String lang;
  const PracticeArenaCard({super.key, required this.lang});

  @override
  ConsumerState<PracticeArenaCard> createState() => _PracticeArenaCardState();
}

class _PracticeArenaCardState extends ConsumerState<PracticeArenaCard> {
  String _selectedDifficulty = 'All';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = widget.lang == 'bn';
    final isHi = widget.lang == 'hi';

    // UI translations
    final title = isBn ? 'অনুশীলন ক্ষেত্র' : isHi ? 'अभ्यास क्षेत्र' : 'Practice Arena';
    final subtitle = isBn
        ? 'আপনার পছন্দের কঠিনতা বেছে নিন'
        : isHi
            ? 'अपनी पसंदीदा कठिनाई चुनें'
            : 'Pick your difficulty and jump straight in';
    final diffLabel = isBn ? 'অসুবিধা স্তর:' : isHi ? 'कठिनाई स्तर:' : 'Difficulty:';
    final quickPlayLabel = isBn ? 'দ্রুত খেলা শুরু করুন' : isHi ? 'त्वरित खेल शुरू करें' : 'Quick Play';
    const accent = AppColors.gamingCyan;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF20262F), Color(0xFF171C24)]
              : const [Colors.white, Color(0xFFF6F8FC)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.gamingBorder : const Color(0xFFE4E9F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.10 : 0.06),
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
            // Ambient glow graphics
            Positioned(
              right: -30,
              top: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: isDark ? 0.16 : 0.08),
                      accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Custom Config Icon Row
                  Row(
                    children: [
                      SoftDuotoneIcon(
                        icon: Icons.psychology_rounded,
                        accent: accent,
                        size: 42,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppColors.gamingTextSecondary
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Custom Config Icon
                      InkWell(
                        onTap: () => _showPracticeBottomSheet(context, isDark, isBn, isHi),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.gamingSurfaceElevated
                                : const Color(0xFFF1F5FB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.gamingBorder
                                  : const Color(0xFFE4E9F0),
                            ),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: isDark
                                ? AppColors.gamingTextSecondary
                                : AppColors.textSecondaryLight,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Difficulty Selector Label
                  Text(
                    diffLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: isDark
                          ? AppColors.gamingTextSecondary
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Difficulty Chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['All', 'Easy', 'Medium', 'Hard'].map((diff) {
                      final isSelected = _selectedDifficulty == diff;
                      final label = isBn
                          ? (diff == 'All' ? 'সব' : diff == 'Easy' ? 'সহজ' : diff == 'Medium' ? 'মাঝারি' : 'কঠিন')
                          : isHi
                              ? (diff == 'All' ? 'सभी' : diff == 'Easy' ? 'आसान' : diff == 'Medium' ? 'मध्यम' : 'कठिन')
                              : diff;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: InkWell(
                            onTap: () => setState(() => _selectedDifficulty = diff),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? accent
                                    : (isDark
                                        ? AppColors.gamingSurfaceElevated
                                        : const Color(0xFFF1F5FB)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? accent
                                      : (isDark
                                          ? AppColors.gamingBorder
                                          : const Color(0xFFE4E9F0)),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? AppColors.gamingBg
                                      : (isDark
                                          ? AppColors.gamingTextSecondary
                                          : AppColors.textSecondaryLight),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Quick Play Label
                  Text(
                    quickPlayLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: isDark
                          ? AppColors.gamingTextSecondary
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick start action buttons (5, 10, 20 Questions)
                  Row(
                    children: [
                      _buildQuickStartButton(context, 5, Icons.bolt_rounded),
                      const SizedBox(width: 8),
                      _buildQuickStartButton(context, 10, Icons.emoji_events_rounded),
                      const SizedBox(width: 8),
                      _buildQuickStartButton(context, 20, Icons.local_fire_department_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStartButton(BuildContext context, int count, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = AppColors.gamingCyan;
    return Expanded(
      child: AnimatedScaleButton(
        onTap: () => _startPracticeMode(context, ref, count, _selectedDifficulty),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.gamingSurfaceElevated : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.gamingBorder : const Color(0xFFE4E9F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isDark ? accent : Color.lerp(accent, Colors.black, 0.35),
              ),
              const SizedBox(height: 4),
              Text(
                '$count Q',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPracticeBottomSheet(
      BuildContext context, bool isDark, bool isBn, bool isHi) {
    int selectedCount = 10;
    String selectedDifficulty = _selectedDifficulty;

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
    // Sync silently in background (non-blocking)
    PracticeQuizService.instance.syncWithFirestore();

    // Fetch instantly from the local database using smart weighted selection
    final practiceQuiz = await PracticeQuizService.instance.fetchPracticeQuiz(
      questionCount: questionCount,
      difficulty: difficulty == 'All' ? null : difficulty.toLowerCase(),
    );

    if (context.mounted) {
      ref.read(quizSessionProvider.notifier).startQuiz(practiceQuiz);
      Navigator.pushNamed(context, '/quiz');
    }
  }
}
