// lib/presentation/screens/bookmarks_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/firestore_models.dart';
import '../providers/app_providers.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider);
    final lang = ref.watch(languageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    final title = isBn
        ? 'সংরক্ষিত প্রশ্ন'
        : isHi
            ? 'सहेजे गए प्रश्न'
            : 'Saved Questions';

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
      ),
      body: bookmarks.isEmpty
          ? _buildEmptyState(context, isDark, isBn, isHi)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: bookmarks.length,
              itemBuilder: (context, index) {
                final map = bookmarks[index];
                final question = QuestionModel.fromMap(map);
                return _BookmarkQuestionCard(
                  question: question,
                  lang: lang,
                  isDark: isDark,
                  onRemove: () {
                    ref.read(bookmarksProvider.notifier).toggle(question.id, map);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isBn
                            ? 'সংরক্ষিত প্রশ্ন সরানো হয়েছে!'
                            : isHi
                                ? 'सहेजा गया प्रश्न हटा दिया गया!'
                                : 'Question removed from saved!'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, bool isDark, bool isBn, bool isHi) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.bookmarkInactive,
                size: 64,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isBn
                  ? 'কোনো প্রশ্ন সংরক্ষিত নেই'
                  : isHi
                      ? 'कोई सहेजा हुआ प्रश्न नहीं'
                      : 'No saved questions yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isBn
                  ? 'কুইজ খেলার সময় গুরুত্বপূর্ণ প্রশ্নগুলি এখানে সংরক্ষণ করুন।'
                  : isHi
                      ? 'क्विज़ खेलते समय महत्वपूर्ण प्रश्नों को यहाँ सहेजें।'
                      : 'Bookmark interesting or tricky questions during a quiz to review them here anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarkQuestionCard extends StatelessWidget {
  final QuestionModel question;
  final String lang;
  final bool isDark;
  final VoidCallback onRemove;

  const _BookmarkQuestionCard({
    required this.question,
    required this.lang,
    required this.isDark,
    required this.onRemove,
  });

  Color _difficultyColor(String d) {
    switch (d.toLowerCase()) {
      case 'easy':
        return AppColors.success;
      case 'hard':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final questionText = question.getText(lang);
    final options = question.getOptions(lang);
    final isBn = lang == 'bn';
    final isBengali = isBn;
    final isHi = lang == 'hi';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.withValues(alpha: 0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: Tags + Remove Action
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  question.category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _difficultyColor(question.difficulty)
                      .withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _difficultyColor(question.difficulty)
                        .withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  question.difficulty.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: _difficultyColor(question.difficulty),
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onRemove,
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error.withValues(alpha: 0.8),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Question Text
          Text(
            questionText,
            style: isBengali
                ? AppTheme.bengaliStyle(fontSize: 16, fontWeight: FontWeight.bold)
                : TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    height: 1.4,
                  ),
          ),
          const SizedBox(height: 16),
          // Options List
          ...options.asMap().entries.map((entry) {
            final i = entry.key;
            final text = entry.value;
            final isCorrect = i == question.correctIndex;
            final prefix = ['A', 'B', 'C', 'D'][i % 4];

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isCorrect
                    ? AppColors.success.withValues(alpha: isDark ? 0.15 : 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCorrect
                      ? AppColors.success.withValues(alpha: 0.3)
                      : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1)),
                  width: isCorrect ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCorrect
                          ? AppColors.success
                          : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
                    ),
                    child: Text(
                      prefix,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCorrect
                            ? Colors.white
                            : (isDark ? Colors.white60 : AppColors.textSecondaryLight),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: isBengali
                          ? AppTheme.bengaliStyle(
                              fontSize: 13,
                              color: isCorrect
                                  ? (isDark ? Colors.white : Colors.green.shade800)
                                  : (isDark ? Colors.white70 : AppColors.textPrimaryLight),
                            )
                          : TextStyle(
                              fontSize: 13,
                              fontWeight: isCorrect ? FontWeight.bold : FontWeight.w500,
                              color: isCorrect
                                  ? (isDark ? Colors.white : Colors.green.shade800)
                                  : (isDark ? Colors.white70 : AppColors.textPrimaryLight),
                            ),
                    ),
                  ),
                  if (isCorrect)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 16,
                    ),
                ],
              ),
            );
          }),
          // Explanation
          if (question.getExplanation(lang).trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBn
                        ? 'ব্যাখ্যা'
                        : isHi
                            ? 'विवरण'
                            : 'Explanation',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    question.getExplanation(lang),
                    style: isBengali
                        ? AppTheme.bengaliStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          )
                        : TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
