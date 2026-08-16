// lib/presentation/screens/play_zone_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../providers/app_providers.dart';
import '../../core/services/quiz/practice_quiz_service.dart';
import '../../routes/app_router.dart';
import '../widgets/game_card.dart';
import 'games/synapse_recall/synapse_art.dart';

class PlayZoneScreen extends ConsumerStatefulWidget {
  const PlayZoneScreen({super.key});

  @override
  ConsumerState<PlayZoneScreen> createState() => _PlayZoneScreenState();
}

class _PlayZoneScreenState extends ConsumerState<PlayZoneScreen> {
  String _selectedCategory = 'All';
  late final TextEditingController _searchController;
  String _searchQuery = '';

  final List<String> _categories = const [
    'All',
    'Knowledge',
    'Logic',
    'Memory',
    'Focus',
    'Math'
  ];

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
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    final screenTitle = isBn
        ? 'প্লে জোন'
        : isHi
            ? 'प्ले ज़ोन'
            : 'Play Zone';

    // Challenge data list
    final allChallenges = [
      ChallengeData(
        title: isBn
            ? 'অনুশীলন ট্রিভিয়া'
            : isHi
                ? 'अभ्यास ट्रिविया'
                : 'Practice Trivia',
        description: isBn
            ? 'অসীমিত অনুশীলনের মাধ্যমে আপনার সাধারণ জ্ঞান উন্নত করুন।'
            : isHi
                ? 'असीमित अभ्यास के साथ अपने सामान्य ज्ञान को तेज करें।'
                : 'Sharpen your knowledge with unlimited GK, history, and science practice sessions.',
        category: 'Knowledge',
        duration: 'Self',
        icon: Icons.history_edu_rounded,
        isLocked: false,
        isImplemented: true,
        onTap: () {
          _showPracticeBottomSheet(context, isDark, isBn, isHi);
        },
      ),
      ChallengeData(
        title: isBn
            ? 'দিকনির্দেশক গোলকধাঁধা'
            : isHi
                ? 'दिशात्मक भूलभुलैया'
                : 'Arrow Path Maze',
        description: isBn
            ? 'দিকপরিবর্তন দ্রুত সনাক্ত করে লজিক্যাল ও ভিজ্যুয়াল প্রক্রিয়া তীক্ষ্ণ করুন।'
            : isHi
                ? 'तीव्र दिशात्मक बदलावों को पहचानकर तार्किक संरचनाओं को नेविगेट करें।'
                : 'Navigate complex logical structures by identifying rapid directional shifts.',
        category: 'Logic',
        duration: '2m',
        icon: Icons.extension_rounded,
        imagePath: 'assets/icon/arrows3.PNG',
        isLocked: false,
        isImplemented: true,
        onTap: () {
          Navigator.pushNamed(context, '/arrow-puzzle');
        },
      ),
      ChallengeData(
        title: isBn
            ? 'সিন্যাপ্স রিকল'
            : isHi
                ? 'सिनैप्स रिकॉल'
                : 'Synapse Recall',
        description: isBn
            ? 'গ্রিড ম্যাট্রিক্সের ফ্ল্যাশিং প্যাটার্ন মনে রেখে সিকোয়েন্স রিকল ক্ষমতা বাড়ান।'
            : isHi
                ? 'प्रकाश और ध्वनि के जटिल पैटर्न को फिर से बनाकर काम करने की स्मृति को मजबूत करें।'
                : 'Strengthen working memory by recreating complex patterns of flashing tiles.',
        category: 'Memory',
        duration: '3m',
        icon: Icons.psychology_rounded,
        isLocked: false,
        isImplemented: true,
        onTap: () {
          Navigator.pushNamed(context, '/synapse-recall');
        },
      ),
      ChallengeData(
        title: isBn
            ? 'স্ট্রুপ রাশ'
            : isHi
                ? 'स्ट्रूप रश'
                : 'Stroop Rush',
        description: isBn
            ? 'শব্দ ও রঙের মিল দ্রুত চিহ্নিত করে মনোযোগ ও প্রতিক্রিয়া গতি বাড়ান।'
            : isHi
                ? 'शब्द और रंग के मेल को तेजी से पहचानकर फोकस और प्रतिक्रिया समय बढ़ाएं।'
                : 'Race the clock matching word meanings to ink colors to sharpen focus and reaction speed.',
        category: 'Focus',
        duration: '2.5s',
        icon: Icons.palette_rounded,
        imagePath: 'assets/icon/stroopRush2.PNG',
        accentColor: const Color(0xFFFF2D95),
        isLocked: false,
        isImplemented: true,
        onTap: () {
          Navigator.pushNamed(context, '/stroop-rush');
        },
      ),
      ChallengeData(
        title: isBn
            ? 'ম্যাথ স্প্রিন্ট'
            : isHi
                ? 'मैथ स्प्रिंट'
                : 'Math Speed Sprint',
        description: isBn
            ? '৬০ সেকেন্ডের দ্রুত গাণিতিক সমস্যা সমাধানের দক্ষতা পরীক্ষা।'
            : isHi
                ? '60 सेकंड का त्वरित मानसिक अंकगणितीय कौशल परीक्षण।'
                : 'A 60-second mental arithmetic sprint to test rapid operational speed.',
        category: 'Math',
        duration: '1m',
        icon: Icons.calculate_rounded,
        isLocked: false,
        isImplemented: true,
        onTap: () {
          Navigator.pushNamed(context, AppRouter.mathSprint);
        },
      ),
      ChallengeData(
        title: isBn
            ? 'নিউরন নেভিগেটর'
            : isHi
                ? 'न्यूरॉन नेविगेटर'
                : 'Neural Navigator',
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
      final matchesCategory =
          _selectedCategory == 'All' || c.category == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();

    final knowledgeGames =
        filteredChallenges.where((c) => c.category == 'Knowledge').toList();
    final logicMemoryGames = filteredChallenges
        .where((c) => c.category == 'Logic' || c.category == 'Memory')
        .toList();
    final focusGames =
        filteredChallenges.where((c) => c.category == 'Focus').toList();
    final mathGames =
        filteredChallenges.where((c) => c.category == 'Math').toList();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.homeBackdropDark
              : AppColors.homeBackdropGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
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
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        screenTitle,
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF151D1E).withValues(alpha: 0.65)
                        : Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? AppColors.outlineVariant.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.05),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.15 : 0.02),
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
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: isBn
                          ? 'গেম খুঁজুন...'
                          : isHi
                              ? 'खेल खोजें...'
                              : 'Search games, puzzles...',
                      hintStyle: TextStyle(
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        size: 18,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                size: 16,
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                  ),
                ),
              ),

              // Filter horizontal scroll bar
              SizedBox(
                height: 42,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    final label = _categoryLabel(cat, isBn, isHi);

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedCategory = cat);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                    ? AppColors.primary
                                    : AppColors.primary)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark
                                      ? AppColors.outlineVariant
                                          .withValues(alpha: 0.4)
                                      : Colors.black12),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.black
                                    : (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Topic 1: Trivia & Knowledge
                            if (knowledgeGames.isNotEmpty) ...[
                              _buildTopicHeader(
                                title: isBn
                                    ? 'জ্ঞান ও ট্রিভিয়া'
                                    : isHi
                                        ? 'ज्ञान और त्रिविया'
                                        : 'Knowledge & Trivia',
                                isDark: isDark,
                                isBn: isBn,
                                isHi: isHi,
                              ),
                              const SizedBox(height: 10),
                              GridView(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  mainAxisExtent: 172,
                                ),
                                children: knowledgeGames.map((game) {
                                  return _buildPlayZoneGameTile(
                                    context: context,
                                    isDark: isDark,
                                    data: game,
                                    isBn: isBn,
                                    isHi: isHi,
                                    imagePath: 'assets/icon/quiz3.png',
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 28),
                            ],

                            // Topic 2: Logic & Memory
                            if (logicMemoryGames.isNotEmpty) ...[
                              _buildTopicHeader(
                                title: isBn
                                    ? 'যুক্তি এবং মেমরি'
                                    : isHi
                                        ? 'तर्क और स्मृति'
                                        : 'Logic & Memory',
                                isDark: isDark,
                                isBn: isBn,
                                isHi: isHi,
                              ),
                              const SizedBox(height: 10),
                              GridView(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  mainAxisExtent: 172,
                                ),
                                children: logicMemoryGames.map((game) {
                                  return _buildPlayZoneGameTile(
                                    context: context,
                                    isDark: isDark,
                                    data: game,
                                    isBn: isBn,
                                    isHi: isHi,
                                    imagePath: isDark
                                        ? 'assets/icon/logic_mascot_dark.jpg'
                                        : 'assets/icon/logic_mascot_light.jpg',
                                    cover: game.category == 'Memory'
                                        ? const SynapseRecallCover()
                                        : null,
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 28),
                            ],

                            // Topic 3: Focus & Attention
                            if (focusGames.isNotEmpty) ...[
                              _buildTopicHeader(
                                title: isBn
                                    ? 'মনোযোগ ও ফোকাস'
                                    : isHi
                                        ? 'ध्यान और फोकस'
                                        : 'Focus & Attention',
                                isDark: isDark,
                                isBn: isBn,
                                isHi: isHi,
                              ),
                              const SizedBox(height: 10),
                              GridView(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  mainAxisExtent: 172,
                                ),
                                children: focusGames.map((game) {
                                  return _buildPlayZoneGameTile(
                                    context: context,
                                    isDark: isDark,
                                    data: game,
                                    isBn: isBn,
                                    isHi: isHi,
                                    imagePath: isDark
                                        ? 'assets/icon/logic_mascot_dark.jpg'
                                        : 'assets/icon/logic_mascot_light.jpg',
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 28),
                            ],

                            // Topic 4: Math & Numbers
                            if (mathGames.isNotEmpty) ...[
                              _buildTopicHeader(
                                title: isBn
                                    ? 'গণিত ও সংখ্যা'
                                    : isHi
                                        ? 'गणित और संख्याएँ'
                                        : 'Math & Numbers',
                                isDark: isDark,
                                isBn: isBn,
                                isHi: isHi,
                              ),
                              const SizedBox(height: 10),
                              GridView(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  mainAxisExtent: 172,
                                ),
                                children: mathGames.map((game) {
                                  return _buildPlayZoneGameTile(
                                    context: context,
                                    isDark: isDark,
                                    data: game,
                                    isBn: isBn,
                                    isHi: isHi,
                                    imagePath: 'assets/icon/mathSpeed2.PNG',
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicHeader({
    required String title,
    required bool isDark,
    required bool isBn,
    required bool isHi,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  String _categoryLabel(String key, bool isBn, bool isHi) {
    if (isBn) {
      switch (key) {
        case 'All':
          return 'সব';
        case 'Knowledge':
          return 'জ্ঞান';
        case 'Logic':
          return 'যুক্তি';
        case 'Memory':
          return 'স্মৃতি';
        case 'Focus':
          return 'ফোকাস';
        case 'Math':
          return 'গণিত';
      }
    }
    if (isHi) {
      switch (key) {
        case 'All':
          return 'सभी';
        case 'Knowledge':
          return 'ज्ञान';
        case 'Logic':
          return 'तर्क';
        case 'Memory':
          return 'स्मृति';
        case 'Focus':
          return 'फोकस';
        case 'Math':
          return 'गणित';
      }
    }
    return key;
  }

  Widget _buildPlayZoneGameTile({
    required BuildContext context,
    required bool isDark,
    required ChallengeData data,
    required bool isBn,
    required bool isHi,
    String? imagePath,
    Widget? cover,
  }) {
    final bool isImplemented = data.isImplemented;
    final String? resolvedImagePath = data.imagePath ?? imagePath;
    final categoryColor = (data.accentColor ??
        (data.isLocked || !isImplemented
            ? Colors.grey
            : (data.category.toLowerCase().contains('knowledge')
                ? AppColors.primary
                : (data.category.toLowerCase().contains('logic') ||
                        data.category.toLowerCase().contains('memory') ||
                        data.category.toLowerCase().contains('focus')
                    ? const Color(0xFF00F1FE)
                    : const Color(0xFFECB2FF)))));

    return GameCard(
      fillHeight: true,
      compact: true,
      coverHeight: 116,
      imagePath: cover == null ? resolvedImagePath : null,
      cover: cover,
      accent: categoryColor,
      badge: data.category.toUpperCase(),
      isLocked: data.isLocked,
      isComingSoon: !isImplemented,
      comingSoonLabel: isBn
          ? 'শীঘ্রই আসছে'
          : isHi
              ? 'जल्द ही आ रहा है'
              : 'COMING SOON',
      meta: data.duration,
      metaIcon: Icons.timer_outlined,
      title: data.title,
      subtitle: data.description,
      footer: data.isLocked
          ? (isBn
              ? 'লেভেল ১৫ খুলবে'
              : isHi
                  ? 'लेवल 15 पर खुलेगा'
                  : 'Unlocks Level 15')
          : !isImplemented
              ? (isBn
                  ? 'শীঘ্রই আসছে'
                  : isHi
                      ? 'जल्द ही आ रहा है'
                      : 'Coming soon')
              : (isBn
                  ? 'সক্রিয় চ্যালেঞ্জ'
                  : isHi
                      ? 'सक्रिय चुनौती'
                      : 'Active Challenge'),
      onTap: data.onTap,
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
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
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
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
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
                    isBn
                        ? 'অনুশীলন কনফিগার করুন'
                        : isHi
                            ? 'अभ्यास कॉन्फ़िगर करें'
                            : 'Configure Practice',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isBn
                        ? 'প্রশ্নের সংখ্যা'
                        : isHi
                            ? 'प्रश्नों की संख्या'
                            : 'Number of Questions',
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
                          color: selected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isBn
                        ? 'অসুবিধা স্তর'
                        : isHi
                            ? 'कठिनाई स्तर'
                            : 'Difficulty Level',
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
                            ? (diff == 'All'
                                ? 'সব'
                                : diff == 'Easy'
                                    ? 'সহজ'
                                    : diff == 'Medium'
                                        ? 'মাঝারি'
                                        : 'কঠিন')
                            : isHi
                                ? (diff == 'All'
                                    ? 'सभी'
                                    : diff == 'Easy'
                                        ? 'आसान'
                                        : diff == 'Medium'
                                            ? 'मध्यम'
                                            : 'कठिन')
                                : diff),
                        selected: selected,
                        onSelected: (val) {
                          if (val) {
                            setModalState(() => selectedDifficulty = diff);
                          }
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
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
                        _startPracticeMode(
                            context, ref, selectedCount, selectedDifficulty);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        isBn
                            ? 'অনুশীলন শুরু করুন'
                            : isHi
                                ? 'अभ्यास शुरू करें'
                                : 'Start Practice',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
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

  Future<void> _startPracticeMode(BuildContext context, WidgetRef ref,
      int questionCount, String difficulty) async {
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
  final String? imagePath;
  final bool isLocked;
  final bool isImplemented;
  final VoidCallback onTap;
  final Color? accentColor;

  ChallengeData({
    required this.title,
    required this.description,
    required this.category,
    required this.duration,
    required this.icon,
    required this.isLocked,
    this.imagePath,
    this.isImplemented = false,
    this.accentColor,
    required this.onTap,
  });
}
