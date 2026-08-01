// lib/presentation/screens/play_zone_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_animations.dart';
import '../providers/app_providers.dart';
import '../../core/services/quiz/practice_quiz_service.dart';

class PlayZoneScreen extends ConsumerStatefulWidget {
  const PlayZoneScreen({super.key});

  @override
  ConsumerState<PlayZoneScreen> createState() => _PlayZoneScreenState();
}

class _PlayZoneScreenState extends ConsumerState<PlayZoneScreen> {
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'Knowledge', 'Logic', 'Memory', 'Focus', 'Math'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(languageProvider);
    final quizAsync = ref.watch(todayQuizProvider);
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    final screenTitle = isBn ? 'অ্যারেনা চ্যালেঞ্জ' : isHi ? 'एरिना चुनौतियाँ' : 'Arena Challenges';
    final screenSubtitle = isBn
        ? 'আপনার মানসিক দক্ষতা বৃদ্ধি করতে অংশ নিন দৈনিক অনুশীলনে।'
        : isHi
            ? 'दैनिक प्रदर्शन अभ्यासों के साथ अपनी मानसिक तीक्ष्णता को बढ़ाएं।'
            : 'Hone your mental acuity with daily performance drills.';

    // Challenge data list
    final allChallenges = [
      ChallengeData(
        title: isBn ? 'অনুশীলন ট্রিভিয়া' : isHi ? 'अभ्यास ट्रिविया' : 'Practice Trivia',
        description: isBn
            ? 'অসীমিত অনুশীলনের মাধ্যমে আপনার সাধারণ জ্ঞান উন্নত করুন।'
            : isHi
                ? 'असीमित अभ्यास के साथ अपने सामान्य ज्ञान को तेज करें।'
                : 'Sharpen your knowledge with unlimited GK, history, and science practice sessions.',
        category: 'Knowledge',
        duration: 'Self',
        icon: Icons.history_edu_rounded,
        isLocked: false,
        onTap: () {
          _showPracticeBottomSheet(context, isDark, isBn, isHi);
        },
      ),
      ChallengeData(
        title: isBn ? 'দিকনির্দেশক গোলকধাঁধা' : isHi ? 'दिशात्मक भूलभुलैया' : 'Arrow Path Maze',
        description: isBn
            ? 'দিকপরিবর্তন দ্রুত সনাক্ত করে লজিক্যাল ও ভিজ্যুয়াল প্রক্রিয়া তীক্ষ্ণ করুন।'
            : isHi
                ? 'तीव्र दिशात्मक बदलावों को पहचानकर तार्किक संरचनाओं को नेविगेट करें।'
                : 'Navigate complex logical structures by identifying rapid directional shifts.',
        category: 'Logic',
        duration: '2m',
        icon: Icons.extension_rounded,
        isLocked: false,
        onTap: () {
          Navigator.pushNamed(context, '/game-placeholder', arguments: {
            'title': 'Arrow Path Maze',
            'description': 'Navigate complex direction shifts. Tap the same direction for blue, opposite direction for orange.',
          });
        },
      ),
      ChallengeData(
        title: isBn ? 'সিন্যাপ্স রিকল' : isHi ? 'सिनैप्स रिकॉल' : 'Synapse Recall',
        description: isBn
            ? 'গ্রিড ম্যাট্রিক্সের ফ্ল্যাশিং প্যাটার্ন মনে রেখে সিকোয়েন্স রিকল ক্ষমতা বাড়ান।'
            : isHi
                ? 'प्रकाश और ध्वनि के जटिल पैटर्न को फिर से बनाकर काम करने की स्मृति को मजबूत करें।'
                : 'Strengthen working memory by recreating complex patterns of flashing tiles.',
        category: 'Memory',
        duration: '5m',
        icon: Icons.psychology_rounded,
        isLocked: false,
        onTap: () {
          Navigator.pushNamed(context, '/game-placeholder', arguments: {
            'title': 'Synapse Recall',
            'description': 'Memorize the flashing green pattern on the grid matrix. Recreate it accurately as grid size expands.',
          });
        },
      ),
      ChallengeData(
        title: isBn ? 'ডিস্ট্রাকশন ব্লক' : isHi ? 'डिस्ट्रैक्शन ब्लॉक' : 'Distraction Block',
        description: isBn
            ? 'চারপাশের অপ্রাসঙ্গিক বিভ্রান্তি উপেক্ষা করে নির্দিষ্ট বিষয়ে ফোকাস করুন।'
            : isHi
                ? 'संज्ञानात्मक शोर के क्षेत्र में प्रासंगिक संकेतों को अलग करके ध्यान बढ़ाएं।'
                : 'Enhance focus by isolating relevant signals in a field of cognitive noise.',
        category: 'Focus',
        duration: '3m',
        icon: Icons.track_changes_rounded,
        isLocked: false,
        onTap: () {
          Navigator.pushNamed(context, '/game-placeholder', arguments: {
            'title': 'Distraction Block',
            'description': 'Enhance focus by isolating relevant signals in a field of cognitive noise.',
          });
        },
      ),
      ChallengeData(
        title: isBn ? 'ম্যাথ স্প্রিন্ট' : isHi ? 'मैथ स्प्रिंट' : 'Math Speed Sprint',
        description: isBn
            ? '৬০ সেকেন্ডের দ্রুত গাণিতিক সমস্যা সমাধানের দক্ষতা পরীক্ষা।'
            : isHi
                ? '60 सेकंड का त्वरित मानसिक अंकगणितीय कौशल परीक्षण।'
                : 'A 60-second mental arithmetic sprint to test rapid operational speed.',
        category: 'Math',
        duration: '1m',
        icon: Icons.calculate_rounded,
        isLocked: false,
        onTap: () {
          Navigator.pushNamed(context, '/game-placeholder', arguments: {
            'title': 'Math Speed Sprint',
            'description': 'A 60-second mental arithmetic sprint to sharpen focus and operational cognitive processing.',
          });
        },
      ),
      ChallengeData(
        title: isBn ? 'নিউরন নেভিগেটর' : isHi ? 'न्यूरॉन नेविगेटर' : 'Neural Navigator',
        description: isBn
            ? 'লেভেল ১৫ এ পৌঁছালে খুলবে। স্থানিক ও ঘূর্ণন দক্ষতা বৃদ্ধির খেলা।'
            : isHi
                ? 'स्तर 15 पर अनलॉक करें। स्थानिक अभिविन्यास और मानसिक रोटेशन का परीक्षण।'
                : 'Unlock at Level 15 to test your spatial orientation and mental rotation skills.',
        category: 'Focus',
        duration: '4m',
        icon: Icons.explore_rounded,
        isLocked: true,
        onTap: () {},
      ),
    ];

    // Filtered challenges list
    final filteredChallenges = _selectedCategory == 'All'
        ? allChallenges
        : allChallenges.where((c) => c.category == _selectedCategory).toList();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.homeBackdropDark : AppColors.homeBackdropGradient,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      screenTitle,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      screenSubtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),

              // Filter horizontal scroll bar
              SizedBox(
                height: 56,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedCategory = cat);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : (isDark ? AppColors.outlineVariant : Colors.black12),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.black
                                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Vertically Scrollable List of Cards
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: filteredChallenges.length,
                  itemBuilder: (context, index) {
                    final challenge = filteredChallenges[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: StaggeredListItem(
                        index: index,
                        child: _buildChallengeCard(context, challenge, isDark, isBn, isHi),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeCard(BuildContext context, ChallengeData data, bool isDark, bool isBn, bool isHi) {
    final cardBg = isDark ? AppColors.cardDark : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.outlineVariant : Colors.black12,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Opacity(
        opacity: data.isLocked ? 0.6 : 1.0,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon box
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.outlineVariant : Colors.black12),
              ),
              child: Icon(
                data.isLocked ? Icons.lock_rounded : data.icon,
                color: data.isLocked
                    ? (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)
                    : (isDark ? AppColors.primary : AppColors.primaryDark),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        data.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      if (data.isLocked) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isBn ? 'লকড' : isHi ? 'बंद' : 'LOCKED',
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildBadge(Icons.bookmark_border_rounded, data.category, isDark),
                      const SizedBox(width: 8),
                      _buildBadge(Icons.timer_outlined, data.duration, isDark),
                      const Spacer(),
                      
                      // Play Button
                      GestureDetector(
                        onTap: data.onTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: data.isLocked ? AppColors.outlineVariant : AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            data.isLocked ? (isBn ? 'লকড' : isHi ? 'बंद' : 'Locked') : (isBn ? 'খেলুন' : isHi ? 'खेलें' : 'Play'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: data.isLocked ? AppColors.textSecondaryDark : Colors.black,
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildBadge(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppColors.outlineVariant : Colors.black12, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            ),
          ),
        ],
      ),
    );
  }

  void _showPracticeBottomSheet(
      BuildContext context, bool isDark, bool isBn, bool isHi) {
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

class ChallengeData {
  final String title;
  final String description;
  final String category;
  final String duration;
  final IconData icon;
  final bool isLocked;
  final VoidCallback onTap;

  ChallengeData({
    required this.title,
    required this.description,
    required this.category,
    required this.duration,
    required this.icon,
    required this.isLocked,
    required this.onTap,
  });
}
