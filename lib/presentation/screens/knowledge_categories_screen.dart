// lib/presentation/screens/knowledge_categories_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_animations.dart';
import '../providers/app_providers.dart';
import '../../core/services/quiz/practice_quiz_service.dart';

class KnowledgeCategoriesScreen extends ConsumerStatefulWidget {
  const KnowledgeCategoriesScreen({super.key});

  @override
  ConsumerState<KnowledgeCategoriesScreen> createState() => _KnowledgeCategoriesScreenState();
}

class _KnowledgeCategoriesScreenState extends ConsumerState<KnowledgeCategoriesScreen> {
  final List<Map<String, dynamic>> _categories = const [
    {
      'name': 'General Knowledge',
      'subtitle': 'Broad spectrum trivia and intelligence',
      'icon': Icons.menu_book_rounded,
    },
    {
      'name': 'Indian History',
      'subtitle': 'Chronicles, eras, and freedom struggles',
      'icon': Icons.history_edu_rounded,
    },
    {
      'name': 'Geography',
      'subtitle': 'World maps, topography, and climates',
      'icon': Icons.public_rounded,
    },
    {
      'name': 'Science',
      'subtitle': 'Physics, chemistry, biology, and tech',
      'icon': Icons.science_rounded,
    },
    {
      'name': 'Polity',
      'subtitle': 'Constitutions, governance, and rights',
      'icon': Icons.gavel_rounded,
    },
    {
      'name': 'Economy',
      'subtitle': 'Macroeconomics, trade, and finance',
      'icon': Icons.monetization_on_rounded,
    },
    {
      'name': 'Current Affairs',
      'subtitle': 'Recent global headlines and events',
      'icon': Icons.newspaper_rounded,
    },
    {
      'name': 'Art & Culture',
      'subtitle': 'Traditions, heritage, and monuments',
      'icon': Icons.palette_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(languageProvider);
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isBn ? 'জ্ঞান অ্যারেনা' : isHi ? 'ज्ञान एरिना' : 'Knowledge Arena',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isBn ? 'একটি বিভাগ চয়ন করুন' : isHi ? 'एक श्रेणी चुनें' : 'Choose a Category',
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isBn
                    ? 'আপনার সাধারণ জ্ঞান উন্নত করতে নির্দিষ্ট টপিক সিলেক্ট করে অনুশীলন শুরু করুন।'
                    : isHi
                        ? 'अपने सामान्य ज्ञान को बेहतर बनाने के लिए किसी भी विषय पर अभ्यास शुरू करें।'
                        : 'Select any core syllabus topic to begin structured cognitive training.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final String name = cat['name'];
                    final String subtitle = cat['subtitle'];
                    final IconData icon = cat['icon'];
                    final categoryColor = AppColors.categoryColor(name);

                    // Multi-lingual translations
                    String localizedName = name;
                    if (isBn) {
                      if (name == 'General Knowledge') localizedName = 'সাধারণ জ্ঞান';
                      if (name == 'Indian History') localizedName = 'ইতিহাস';
                      if (name == 'Geography') localizedName = 'ভূগোল';
                      if (name == 'Science') localizedName = 'বিজ্ঞান';
                      if (name == 'Polity') localizedName = 'রাষ্ট্রনীতি';
                      if (name == 'Economy') localizedName = 'অর্থনীতি';
                      if (name == 'Current Affairs') localizedName = 'সাম্প্রতিক ঘটনাবলী';
                      if (name == 'Art & Culture') localizedName = 'শিল্প ও সংস্কৃতি';
                    } else if (isHi) {
                      if (name == 'General Knowledge') localizedName = 'सामान्य ज्ञान';
                      if (name == 'Indian History') localizedName = 'इतिहास';
                      if (name == 'Geography') localizedName = 'भूगोल';
                      if (name == 'Science') localizedName = 'विज्ञान';
                      if (name == 'Polity') localizedName = 'राजव्यवस्था';
                      if (name == 'Economy') localizedName = 'अर्थशास्त्र';
                      if (name == 'Current Affairs') localizedName = 'सामयिकी';
                      if (name == 'Art & Culture') localizedName = 'कला और संस्कृति';
                    }

                    return StaggeredListItem(
                      index: index,
                      child: AnimatedScaleButton(
                        onTap: () {
                          _showPracticeBottomSheet(context, name, localizedName, isDark, isBn, isHi);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.cardDark.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: categoryColor.withValues(alpha: 0.25),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: categoryColor.withValues(alpha: 0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: categoryColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  icon,
                                  color: categoryColor,
                                  size: 20,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                localizedName,
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isBn
                                    ? 'অনুশীলন শুরু করুন'
                                    : isHi
                                        ? 'अभ्यास शुरू करें'
                                        : subtitle,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textTertiaryDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
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

  void _showPracticeBottomSheet(
      BuildContext context, String categoryName, String displayName, bool isDark, bool isBn, bool isHi) {
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
                color: const Color(0xFF151D1E), // OLED container matching DESIGN2
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.3),
                  width: 1.5,
                ),
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
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    displayName,
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isBn ? 'আপনার অনুশীলন কাস্টমাইজ করুন' : isHi ? 'अपना अभ्यास अनुकूलित करें' : 'Configure your practice session',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isBn ? 'প্রশ্নের সংখ্যা' : isHi ? 'प्रश्नों की संख्या' : 'Number of Questions',
                    style: GoogleFonts.montserrat(
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
                          color: selected ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isBn ? 'অসুবিধা স্তর' : isHi ? 'कठिनाई स्तर' : 'Difficulty Level',
                    style: GoogleFonts.montserrat(
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
                          color: selected ? Colors.black : Colors.white70,
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
                        _startPracticeMode(context, ref, categoryName, selectedCount, selectedDifficulty);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        isBn ? 'অনুশীলন শুরু করুন' : isHi ? 'अभ्यास शुरू करें' : 'Start Practice',
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16),
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
      BuildContext context, WidgetRef ref, String category, int questionCount, String difficulty) async {
    // Show a loading dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    // Sync silently in background (non-blocking)
    PracticeQuizService.instance.syncWithFirestore();

    try {
      // Fetch practice quiz using Hive sqlite fallback
      final practiceQuiz = await PracticeQuizService.instance.fetchPracticeQuiz(
        questionCount: questionCount,
        difficulty: difficulty,
        category: category,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ref.read(quizSessionProvider.notifier).startQuiz(practiceQuiz);
        Navigator.pushNamed(context, '/quiz');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load practice: $e')),
        );
      }
    }
  }
}
