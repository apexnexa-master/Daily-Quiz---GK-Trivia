// lib/presentation/screens/play_zone_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
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
  late final TextEditingController _searchController;
  String _searchQuery = '';

  final List<String> _categories = const ['All', 'Knowledge', 'Logic', 'Memory', 'Focus', 'Math'];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
          Navigator.pushNamed(context, '/arrow-puzzle');
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

    // Filtered challenges list based on category tab & search query
    final filteredChallenges = allChallenges.where((c) {
      final matchesCategory = _selectedCategory == 'All' || c.category == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();

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
                padding: const EdgeInsets.fromLTRB(16, 16, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              ref.read(navigationTabProvider.notifier).state = 0;
                            }
                          },
                          icon: Icon(Icons.arrow_back_rounded,
                              color: isDark ? Colors.white : AppColors.textPrimaryLight),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          screenTitle,
                          style: GoogleFonts.montserrat(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        screenSubtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark 
                        ? const Color(0xFF151D1E).withValues(alpha: 0.65) 
                        : Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark 
                          ? AppColors.outlineVariant.withValues(alpha: 0.2) 
                          : Colors.black.withValues(alpha: 0.05),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: isBn 
                          ? 'গেম খুঁজুন...' 
                          : isHi 
                              ? 'खेल खोजें...' 
                              : 'Search games, puzzles...',
                      hintStyle: TextStyle(
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),

              // Filter horizontal scroll bar
              SizedBox(
                height: 52,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? (isDark ? AppColors.primary : AppColors.primary)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : (isDark ? AppColors.outlineVariant.withValues(alpha: 0.4) : Colors.black12),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
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

              // Bento Split fashion grid area
              Expanded(
                child: filteredChallenges.isEmpty
                    ? _buildEmptyState(isDark, isBn, isHi)
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                        child: Column(
                          children: _buildBentoSplitGrid(context, filteredChallenges, isDark, isBn, isHi),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Generate non-uniform bento grid layout widgets
  List<Widget> _buildBentoSplitGrid(
      BuildContext context, List<ChallengeData> list, bool isDark, bool isBn, bool isHi) {
    final List<Widget> children = [];

    // Slice 0: Large Hero Card (Item 1)
    if (list.isNotEmpty) {
      children.add(
        StaggeredListItem(
          index: 0,
          child: _buildBentoHeroCard(context, list[0], isDark, isBn, isHi),
        ),
      );
      children.add(const SizedBox(height: 14));
    }

    // Slice 1: Row of 2 Split Cards (Item 2 & 3)
    if (list.length > 1) {
      final item1 = list[1];
      final item2 = list.length > 2 ? list[2] : null;

      children.add(
        Row(
          children: [
            Expanded(
              child: StaggeredListItem(
                index: 1,
                child: _buildBentoSplitCard(context, item1, isDark, isBn, isHi),
              ),
            ),
            if (item2 != null) ...[
              const SizedBox(width: 14),
              Expanded(
                child: StaggeredListItem(
                  index: 2,
                  child: _buildBentoSplitCard(context, item2, isDark, isBn, isHi),
                ),
              ),
            ] else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
      children.add(const SizedBox(height: 14));
    }

    // Slice 2: Full-width Landscape Banner Card (Item 4)
    if (list.length > 3) {
      children.add(
        StaggeredListItem(
          index: 3,
          child: _buildBentoBannerCard(context, list[3], isDark, isBn, isHi),
        ),
      );
      children.add(const SizedBox(height: 14));
    }

    // Slice 3: Row of 2 Split Cards (Item 5 & 6)
    if (list.length > 4) {
      final item1 = list[4];
      final item2 = list.length > 5 ? list[5] : null;

      children.add(
        Row(
          children: [
            Expanded(
              child: StaggeredListItem(
                index: 4,
                child: _buildBentoSplitCard(context, item1, isDark, isBn, isHi),
              ),
            ),
            if (item2 != null) ...[
              const SizedBox(width: 14),
              Expanded(
                child: StaggeredListItem(
                  index: 5,
                  child: _buildBentoSplitCard(context, item2, isDark, isBn, isHi),
                ),
              ),
            ] else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
      children.add(const SizedBox(height: 14));
    }

    // Capture remaining items beyond 6 just in case
    if (list.length > 6) {
      for (int i = 6; i < list.length; i++) {
        children.add(
          StaggeredListItem(
            index: i,
            child: _buildBentoBannerCard(context, list[i], isDark, isBn, isHi),
          ),
        );
        children.add(const SizedBox(height: 14));
      }
    }

    return children;
  }

  // 1. Large Bento Hero Card (Spans full width, double height visual detail)
  Widget _buildBentoHeroCard(
      BuildContext context, ChallengeData data, bool isDark, bool isBn, bool isHi) {
    final Color highlightColor = AppColors.primary;

    return AnimatedScaleButton(
      onTap: data.isLocked ? null : data.onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [highlightColor.withValues(alpha: 0.15), highlightColor.withValues(alpha: 0.02)]
                : [highlightColor.withValues(alpha: 0.1), highlightColor.withValues(alpha: 0.02)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: highlightColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: highlightColor.withValues(alpha: isDark ? 0.08 : 0.03),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.01),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: highlightColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    data.icon,
                    color: highlightColor,
                    size: 24,
                  ),
                ),
                _buildBadge(Icons.timer_outlined, data.duration, isDark),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              data.title,
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              data.description,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBadge(Icons.bookmark_border_rounded, data.category, isDark),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: highlightColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: highlightColor.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 2. Compact Bento Grid split card (Fits side-by-side)
  Widget _buildBentoSplitCard(
      BuildContext context, ChallengeData data, bool isDark, bool isBn, bool isHi) {
    final highlightColor = data.category.toLowerCase().contains('logic') 
        ? const Color(0xFF00F1FE) // Cyan
        : (data.category.toLowerCase().contains('memory') 
            ? const Color(0xFFECB2FF) // Pink
            : AppColors.primary); // Yellow/Violet default

    return AnimatedScaleButton(
      onTap: data.isLocked ? null : data.onTap,
      child: Container(
        height: 155,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark 
              ? const Color(0xFF151D1E).withValues(alpha: 0.6) 
              : Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: data.isLocked
                ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))
                : highlightColor.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  data.isLocked ? Icons.lock_outline_rounded : data.icon,
                  color: data.isLocked
                      ? (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)
                      : highlightColor,
                  size: 20,
                ),
                if (data.isLocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                  )
                else
                  Text(
                    data.duration,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              data.title,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: data.isLocked 
                    ? (isDark ? Colors.white38 : Colors.grey.shade400)
                    : (isDark ? Colors.white : AppColors.textPrimaryLight),
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              data.category,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: data.isLocked 
                        ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100)
                        : highlightColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    data.isLocked ? Icons.lock_outline_rounded : Icons.play_arrow_rounded,
                    color: data.isLocked
                        ? (isDark ? Colors.white24 : Colors.grey.shade400)
                        : Colors.black,
                    size: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 3. Landscape Banner Bento Card (Wide banner layout)
  Widget _buildBentoBannerCard(
      BuildContext context, ChallengeData data, bool isDark, bool isBn, bool isHi) {
    final highlightColor = data.category.toLowerCase().contains('focus')
        ? const Color(0xFFE2F0D9)
        : AppColors.primary;

    return AnimatedScaleButton(
      onTap: data.isLocked ? null : data.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isDark 
              ? const Color(0xFF151D1E).withValues(alpha: 0.6) 
              : Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: data.isLocked
                ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))
                : highlightColor.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(
                data.isLocked ? Icons.lock_outline_rounded : data.icon,
                color: data.isLocked
                    ? (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)
                    : highlightColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        data.title,
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: data.isLocked 
                              ? (isDark ? Colors.white38 : Colors.grey.shade400)
                              : (isDark ? Colors.white : AppColors.textPrimaryLight),
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (data.isLocked) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
                  const SizedBox(height: 2),
                  Text(
                    data.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: data.isLocked 
                    ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100)
                    : highlightColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                data.isLocked ? Icons.lock_outline_rounded : Icons.play_arrow_rounded,
                color: data.isLocked
                    ? (isDark ? Colors.white24 : Colors.grey.shade400)
                    : Colors.black,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 4. Empty state for query searches
  Widget _buildEmptyState(bool isDark, bool isBn, bool isHi) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
          ),
          const SizedBox(height: 16),
          Text(
            isBn 
                ? 'কোনো গেম পাওয়া যায়নি!' 
                : isHi 
                    ? 'कोई खेल नहीं मिला!' 
                    : 'No games matched your query',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isBn 
                ? 'দয়া করে অন্য কোনো শব্দ দিয়ে চেষ্টা করুন।' 
                : isHi 
                    ? 'कृपया अन्य शब्दों के साथ प्रयास करें।' 
                    : 'Try searching for different keywords.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
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
