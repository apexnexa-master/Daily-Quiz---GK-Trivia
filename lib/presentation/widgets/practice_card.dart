// lib/presentation/widgets/practice_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_animations.dart';
import '../../core/services/quiz/practice_quiz_service.dart';
import '../providers/app_providers.dart';

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
    final diffLabel = isBn ? 'অসুবিধা স্তর:' : isHi ? 'कठिनाई स्तर:' : 'Difficulty:';
    final quickPlayLabel = isBn ? 'দ্রুত খেলা শুরু করুন' : isHi ? 'त्वरित खेल शुरू करें' : 'Quick Play';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81), const Color(0xFF4C1D95)] 
              : [const Color(0xFF4F46E5), const Color(0xFF6366F1), const Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.35 : 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Ambient glow graphics
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: isDark ? 0.08 : 0.04),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -40,
              bottom: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.04),
                  shape: BoxShape.circle,
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
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      // Custom Config Icon
                      InkWell(
                        onTap: () => _showPracticeBottomSheet(context, isDark, isBn, isHi),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  
                  // Difficulty Selector Label
                  Text(
                    diffLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
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
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? Colors.white 
                                    : Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected 
                                      ? Colors.transparent 
                                      : Colors.white.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected 
                                      ? const Color(0xFF4F46E5) 
                                      : Colors.white.withValues(alpha: 0.9),
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
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick start action buttons (5, 10, 20 Questions)
                  Row(
                    children: [
                      _buildQuickStartButton(context, 5, '⚡'),
                      const SizedBox(width: 8),
                      _buildQuickStartButton(context, 10, '🏆'),
                      const SizedBox(width: 8),
                      _buildQuickStartButton(context, 20, '🔥'),
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

  Widget _buildQuickStartButton(BuildContext context, int count, String emoji) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: AnimatedScaleButton(
        onTap: () => _startPracticeMode(context, ref, count, _selectedDifficulty),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE0E7FF),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                '$count Q',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF4F46E5),
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
