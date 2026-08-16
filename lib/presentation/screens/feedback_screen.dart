// lib/presentation/screens/feedback_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_animations.dart';
import '../providers/app_providers.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final TextEditingController _feedbackController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _sendFeedback(String lang) async {
    final text = _feedbackController.text.trim();
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBn 
                ? 'অনুগ্রহ করে আপনার মতামত টাইপ করুন' 
                : isHi 
                    ? 'कृपया अपनी प्रतिक्रिया टाइप करें' 
                    : 'Please enter your feedback',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String email = 'support.nexasoft@gmail.com';
      final String subject = 'Feedback & Suggestions';
      
      final String encodedSubject = Uri.encodeComponent(subject);
      final String encodedBody = Uri.encodeComponent(text);
      final Uri mailUri = Uri.parse('mailto:$email?subject=$encodedSubject&body=$encodedBody');

      if (await canLaunchUrl(mailUri)) {
        await launchUrl(mailUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isBn 
                    ? 'কোনো মেইল অ্যাপ খুঁজে পাওয়া যায়নি' 
                    : isHi 
                        ? 'कोई ईमेल ऐप नहीं मिला' 
                        : 'No email app found to send feedback',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    final titleStr = isBn ? 'মতামত ও পরামর্শ' : isHi ? 'प्रतिक्रिया और सुझाव' : 'Feedback & Suggestions';
    final descStr = isBn 
        ? 'আপনার গুরুত্বপূর্ণ মতামত ও পরামর্শ টাইপ করুন। এটি আমাদের অ্যাপটিকে আরও উন্নত করতে সাহায্য করবে।' 
        : isHi 
            ? 'अपनी बहुमूल्य प्रतिक्रिया और सुझाव टाइप करें। यह हमारे ऐप को बेहतर बनाने में मदद करेगा।' 
            : 'Type your valuable feedback and suggestions here. Your input helps us make the Daily Quiz App even better.';
    final buttonStr = isBn ? 'পাঠান' : isHi ? 'भेजें' : 'Send Feedback';
    final hintStr = isBn 
        ? 'আপনার বার্তা এখানে লিখুন...' 
        : isHi 
            ? 'अपना संदेश यहाँ लिखें...' 
            : 'Write your message here...';

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          titleStr,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
            fontFamily: 'Outfit',
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              descStr,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            
            // Text feedback box
            Container(
              decoration: BoxDecoration(
                color: isDark 
                    ? AppColors.cardDark.withValues(alpha: 0.55) 
                    : Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.08) 
                      : Colors.black.withValues(alpha: 0.06),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TextField(
                controller: _feedbackController,
                maxLines: 8,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: hintStr,
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                  contentPadding: const EdgeInsets.all(20),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Send button
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : AnimatedScaleButton(
                    onTap: () => _sendFeedback(lang),
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(27),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        buttonStr,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
