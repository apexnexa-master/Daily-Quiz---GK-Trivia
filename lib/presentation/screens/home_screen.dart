// lib/presentation/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_animations.dart';
import '../../core/services/quiz_scheduler_service.dart';
import '../../core/utils/offline_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _countdownTimer;
  String _savedUsername = 'Explorer';
  String _savedPhotoUrl = '';

  @override
  void initState() {
    super.initState();
    _loadSavedIdentity();
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    QuizSchedulerService.instance.refreshTiming(force: true).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadSavedIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedUsername = prefs.getString('temp_username') ?? 'Explorer';
      _savedPhotoUrl = prefs.getString('temp_photo_url') ?? '';
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final lang = ref.watch(languageProvider);
    final quizAsync = ref.watch(todayQuizProvider);
    final statsAsync = ref.watch(userStatsProvider);
    final streakAsync = ref.watch(localStreakProvider);
    final accuracyAsync = ref.watch(overallAccuracyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    // Retrieve username and photo from currentUserProvider
    final currentUser = ref.watch(currentUserProvider).value;
    final username = currentUser?.displayName ?? _savedUsername;
    final photoUrl = currentUser?.photoUrl ?? _savedPhotoUrl;

    // Retrieve streak
    final streak = streakAsync.when(
      data: (d) => d.currentStreak,
      loading: () => 0,
      error: (_, __) => 0,
    );

    // Retrieve accuracy percentage
    final accuracy = accuracyAsync.when(
      data: (acc) => acc,
      loading: () => 0.0,
      error: (_, __) => 0.0,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.homeBackdropDark : AppColors.homeBackdropGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Header Bar matching Mind Gym
              _buildTopAppBar(photoUrl, context),
              const NetworkStatusBanner(),
              
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    ref.invalidate(todayQuizProvider);
                    ref.invalidate(localStreakProvider);
                    ref.invalidate(localLeaderboardProvider);
                    ref.invalidate(localPersonalBestProvider);
                    ref.invalidate(totalQuizzesProvider);
                    ref.invalidate(totalScoreProvider);
                    ref.invalidate(gamificationNotifierProvider);
                    ref.invalidate(overallAccuracyProvider);
                    ref.invalidate(currentUserProvider);
                    await _loadSavedIdentity();
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // Welcome Section
                            _buildWelcomeHeader(username, streak, isBn, isHi, isDark),
                            const SizedBox(height: 20),

                            // Main Bento Layout
                            // Recommended Workout Card (Bento Large)
                            _buildWorkoutCard(quizAsync, context, isBn, isHi, isDark),
                            const SizedBox(height: 16),

                            // Today's Progress Card (Bento Small)
                            _buildProgressCard(accuracy, isBn, isHi, isDark),
                            const SizedBox(height: 16),

                            // 1v1 Battle Arena Bento Card
                            _buildBattleBentoCard(context, isBn, isHi, isDark),
                            const SizedBox(height: 24),

                            // Pillars title
                            Text(
                              isBn ? 'মানসিক দক্ষতার স্তম্ভসমূহ' : isHi ? 'संज्ञानात्मक कौशल के स्तंभ' : 'Pillars of Cognitive Fitness',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Pillars Grid
                            _buildPillarsGrid(context, isBn, isHi, isDark),
                            const SizedBox(height: 24),
                          ]),
                        ),
                      ),
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

  Widget _buildTopAppBar(String photoUrl, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDark : AppColors.bgLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.outlineVariant.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.primary.withValues(alpha: 0.5) : AppColors.primaryDark.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    image: photoUrl.isNotEmpty
                        ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                        : null,
                  ),
                  child: photoUrl.isEmpty
                      ? Icon(
                          Icons.person_rounded,
                          color: isDark ? AppColors.primary : AppColors.primaryDark,
                          size: 20,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'MIND GYM',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/leaderboard'),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceElevatedDark.withValues(alpha: 0.5) : AppColors.surfaceElevatedLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.outlineVariant : Colors.black12,
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.leaderboard_rounded,
                color: isDark ? AppColors.primary : AppColors.primaryDark,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(String username, int streak, bool isBn, bool isHi, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isBn ? 'স্বাগতম, $username' : isHi ? 'स्वागत है, $username' : 'Welcome back, $username',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                isBn ? 'আপনার মস্তিষ্ক আজকের প্রশিক্ষণের জন্য প্রস্তুত।' : isHi ? 'आपका दिमाग आज के वर्कआउट के लिए तैयार है।' : 'Your brain is ready for its morning routine.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceElevatedDark.withValues(alpha: 0.6) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? AppColors.outlineVariant : Colors.black12, width: 1),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                '$streak ${isBn ? 'দিন' : isHi ? 'दिन' : 'Days'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.streak,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutCard(AsyncValue<dynamic> quizAsync, BuildContext context, bool isBn, bool isHi, bool isDark) {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final difference = midnight.difference(now);
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    final timeLeftStr = isBn
        ? '$hours ঘণ্টা $minutes মিনিট বাকি'
        : isHi
            ? '$hours घंटे $minutes मिनट शेष'
            : '$hours h $minutes m left';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.outlineVariant : Colors.black12, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.05 : 0.02),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PulseWidget(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.8),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isBn ? 'লাইভ জিকে কুইজ' : isHi ? 'लाइव जीके क्विज़' : 'LIVE GK QUIZ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppColors.primary : AppColors.primaryDark,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                timeLeftStr,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isBn ? 'আজকের জিকে চ্যালেঞ্জ' : isHi ? 'आज की जीके चुनौती' : "Today's GK Challenge",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isBn ? 'আপনার সাধারণ জ্ঞান ও বুদ্ধিমত্তা পরীক্ষা করতে আজকের লাইভ কুইজে অংশ নিন।' : isHi ? 'अपने सामान्य ज्ञान का परीक्षण करने के लिए आज की लाइव चुनौती खेलें।' : 'Test your general fluid intelligence across current affairs, history, and science categories today.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 20),
          AnimatedScaleButton(
            onTap: () {
              quizAsync.whenData((quiz) {
                if (quiz != null) {
                  ref.read(quizSessionProvider.notifier).startQuiz(quiz);
                  Navigator.pushNamed(context, '/quiz');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Today\'s challenge is not available yet.')),
                  );
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isBn ? 'অনুশীলন শুরু করুন' : isHi ? 'अभ्यास शुरू करें' : 'Begin Training',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(double accuracy, bool isBn, bool isHi, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.outlineVariant : Colors.black12, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.05 : 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          // SVG Circular Progress simulation
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: accuracy > 0 ? (accuracy / 100) : 0.15,
                  strokeWidth: 7,
                  backgroundColor: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
                  color: AppColors.primary,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                '${accuracy.toInt()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBn ? 'আজকের অগ্রগতি' : isHi ? 'आज की प्रगति' : "Today's Accuracy",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isBn ? 'আপনার কুইজের সঠিকতার পরিমাপের গড় স্কোর।' : isHi ? 'पिछले खेलों में आपके सटीकता स्तर की गणना।' : 'Average performance level across recent training logs.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattleBentoCard(BuildContext context, bool isBn, bool isHi, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.outlineVariant : Colors.black12, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.05 : 0.02),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, color: isDark ? AppColors.primary : AppColors.primaryDark, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      isBn ? 'মাল্টিপ্লেয়ার' : isHi ? 'मल्टीप्लेयर' : 'MULTIPLAYER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppColors.primary : AppColors.primaryDark,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                isBn ? '৫ মিনিট' : isHi ? '5 मिनट' : '5m',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isBn ? '১ বনাম ১ কুইজ যুদ্ধ' : isHi ? '1 बनाम 1 क्विज़ युद्ध' : '1v1 Quiz Battle Arena',
            style: TextStyle(
               fontSize: 20,
               fontWeight: FontWeight.w900,
               color: isDark ? Colors.white : AppColors.textPrimaryLight,
               letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isBn
                ? 'বন্ধুদের সাথে সরাসরি লাইভ দ্বৈরথ লড়ুন বা বটের সাথে অনুশীলন করুন।'
                : isHi
                    ? 'दोस्तों के साथ लाइव खेलें या बॉट के साथ अभ्यास करें।'
                    : 'Duel friends in real-time online, or train offline against a bot.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 20),
          AnimatedScaleButton(
            onTap: () {
              Navigator.pushNamed(context, '/battle');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.flash_on_rounded, color: Colors.black, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    isBn ? 'যুদ্ধক্ষেত্রে প্রবেশ করুন' : isHi ? 'युद्ध में शामिल हों' : 'Enter Battle Arena',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarsGrid(BuildContext context, bool isBn, bool isHi, bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildPillarItem(
          icon: Icons.menu_book_rounded,
          title: isBn ? 'জ্ঞান' : isHi ? 'ज्ञान' : 'Knowledge',
          subtitle: isBn ? 'সাধারণ বুদ্ধি' : isHi ? 'सामान्य ज्ञान' : 'General fluid intelligence',
          onTap: () {
            // Existing GK Quiz navigation (switch bottom nav or open selection)
            Navigator.pushNamed(context, '/home'); // Home default
          },
        ),
        _buildPillarItem(
          icon: Icons.bolt_rounded,
          title: isBn ? 'গতি' : isHi ? 'गति' : 'Speed',
          subtitle: isBn ? 'প্রতিক্রিয়া গতি' : isHi ? 'त्वरित गणना' : 'Reaction & calculation',
          onTap: () {
            Navigator.pushNamed(context, '/game-placeholder', arguments: {
              'title': 'Math Speed Sprint',
              'description': 'A 60-second mental arithmetic sprint to sharpen focus and operational cognitive processing.',
            });
          },
        ),
        _buildPillarItem(
          icon: Icons.account_tree_rounded,
          title: isBn ? 'যুক্তি' : isHi ? 'तर्क' : 'Logic',
          subtitle: isBn ? 'প্যাটার্ন খোঁজা' : isHi ? 'तार्किक भूलभुलैया' : 'Directional orientation',
          onTap: () {
            Navigator.pushNamed(context, '/game-placeholder', arguments: {
              'title': 'Arrow Path Maze',
              'description': 'Navigate complex direction shifts. Tap the same direction for blue, opposite direction for orange.',
            });
          },
        ),
        _buildPillarItem(
          icon: Icons.psychology_rounded,
          title: isBn ? 'স্মৃতিশক্তি' : isHi ? 'स्मृति' : 'Memory',
          subtitle: isBn ? 'সক্রিয় স্মরণ' : isHi ? 'ग्रिड विजुअल रिकॉल' : 'Active recall performance',
          onTap: () {
            Navigator.pushNamed(context, '/game-placeholder', arguments: {
              'title': 'Synapse Recall',
              'description': 'Memorize the flashing green pattern on the grid matrix. Recreate it accurately as grid size expands.',
            });
          },
        ),
      ],
    );
  }

  Widget _buildPillarItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.outlineVariant : Colors.black12, width: 1),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isDark ? AppColors.primary : AppColors.primaryDark,
                size: 20,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsSection(bool isBn, bool isHi, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isBn ? 'সাম্প্রতিক অর্জন' : isHi ? 'हाल की उपलब्धियां' : 'Recent Achievements',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/achievements'),
                child: Text(
                  isBn ? 'সব দেখুন' : isHi ? 'सभी देखें' : 'View All',
                  style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAchievementBadge(
                  icon: Icons.emoji_events_rounded,
                  title: 'Focus Master',
                  desc: '10 games without error',
                  color: Colors.amber,
                ),
                const SizedBox(width: 12),
                _buildAchievementBadge(
                  icon: Icons.timer_rounded,
                  title: 'Speed Demon',
                  desc: 'Top 1% in Reaction Test',
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                _buildAchievementBadge(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Logic Leap',
                  desc: 'Leveled up to Tier 3',
                  color: Colors.purpleAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementBadge({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiaryDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
