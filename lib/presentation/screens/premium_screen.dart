// lib/presentation/screens/premium_screen.dart
// Premium subscription and in-app purchases screen

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';

class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(languageProvider);
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF8FAFC), Color(0xFFEEF2FF)],
                ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, isDark, isBn, isHi),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildCurrentPlanCard(isDark, isBn, isHi),
                    const SizedBox(height: 20),
                    _buildPremiumFeatures(isDark, isBn, isHi),
                    const SizedBox(height: 20),
                    _buildSubscriptionPlans(context, isDark, isBn, isHi),
                    const SizedBox(height: 20),
                    _buildCoinsStore(context, isDark, isBn, isHi),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, bool isBn, bool isHi) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_rounded,
                color: isDark ? Colors.white : Colors.black),
          ),
          Text(
            isBn
                ? 'প্রিমিয়াম'
                : isHi
                    ? 'प्रीमियम'
                    : 'Premium',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanCard(bool isDark, bool isBn, bool isHi) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Free Plan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  isBn
                      ? 'সীমিত বৈশিষ্ট্য'
                      : isHi
                          ? 'सीमित सुविधाएं'
                          : 'Limited features',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isBn
                  ? 'আপগ্রেড'
                  : isHi
                      ? 'अपग्रेड'
                      : 'Upgrade',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeatures(bool isDark, bool isBn, bool isHi) {
    final features = [
      (
        Icons.block_rounded,
        isBn
            ? 'বিজ্ঞাপন মুক্ত'
            : isHi
                ? 'विज्ञापन-मुक्त'
                : 'Ad-Free Experience',
        true
      ),
      (
        Icons.all_inclusive_rounded,
        isBn
            ? 'অসীম প্র্যাকটিস'
            : isHi
                ? 'असीमित अभ्यास'
                : 'Unlimited Practice',
        true
      ),
      (
        Icons.analytics_rounded,
        isBn
            ? 'বিস্তারিত বিশ্লেষণ'
            : isHi
                ? 'विस्तृत विश्लेषण'
                : 'Detailed Analytics',
        true
      ),
      (
        Icons.offline_bolt_rounded,
        isBn
            ? 'অফলাইন কুইজ'
            : isHi
                ? 'ऑफ़लाइन क्विज़'
                : 'Offline Quizzes',
        true
      ),
      (
        Icons.emoji_events_rounded,
        isBn
            ? 'বিশেষ প্রতিযোগিতা'
            : isHi
                ? 'विशेष प्रतियोगिताएं'
                : 'Exclusive Contests',
        false
      ),
      (
        Icons.headset_mic_rounded,
        isBn
            ? 'অগ্রাধিকার সহায়তা'
            : isHi
                ? 'प्राथमिकता सहायता'
                : 'Priority Support',
        false
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isBn
                ? 'প্রিমিয়াম সুবিধা'
                : isHi
                    ? 'प्रीमियम सुविधाएं'
                    : 'Premium Features',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...features.asMap().entries.map((entry) {
            final f = entry.value;
            final icon = f.$1;
            final title = f.$2;
            final isAvailable = f.$3;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? AppTheme.successColor.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon,
                        color:
                            isAvailable ? AppTheme.successColor : Colors.grey,
                        size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  if (isAvailable)
                    const Icon(Icons.check_circle_rounded,
                        color: AppTheme.successColor, size: 20)
                  else
                    const Icon(Icons.lock_outline_rounded,
                        color: Colors.grey, size: 20),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSubscriptionPlans(
      BuildContext context, bool isDark, bool isBn, bool isHi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isBn
              ? 'সাবস্ক্রিপশন'
              : isHi
                  ? 'सदस्यता'
                  : 'Subscriptions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PlanCard(
                title: isBn
                    ? 'মাসিক'
                    : isHi
                        ? 'मासिक'
                        : 'Monthly',
                price: isBn
                    ? '₹49'
                    : isHi
                        ? '₹49'
                        : '₹49',
                period: isBn
                    ? '/মাস'
                    : isHi
                        ? '/माह'
                        : '/month',
                isDark: isDark,
                isPopular: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PlanCard(
                title: isBn
                    ? 'বার্ষিক'
                    : isHi
                        ? 'वार्षिक'
                        : 'Yearly',
                price: isBn
                    ? '₹399'
                    : isHi
                        ? '₹399'
                        : '₹399',
                period: isBn
                    ? '/বছর'
                    : isHi
                        ? '/वर्ष'
                        : '/year',
                isDark: isDark,
                isPopular: true,
                discount: '65%',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCoinsStore(
      BuildContext context, bool isDark, bool isBn, bool isHi) {
    final coins = [
      (100, 50, '₹29'),
      (500, 100, '₹99'),
      (1000, 300, '₹179'),
      (2500, 1000, '₹399'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isBn
              ? 'কয়েন স্টোর'
              : isHi
                  ? 'सिक्का स्टोर'
                  : 'Coins Store',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...coins.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🪙', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c.$1} Coins',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            '+${c.$2} Bonus',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.successColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        c.$3,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final bool isDark;
  final bool isPopular;
  final String? discount;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.isDark,
    this.isPopular = false,
    this.discount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isPopular ? AppTheme.primaryGradient : null,
        color: isPopular
            ? null
            : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular
              ? Colors.transparent
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.1)),
        ),
        boxShadow: isPopular
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          if (isPopular)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'POPULAR',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isPopular
                  ? Colors.white
                  : (isDark ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: isPopular
                  ? Colors.white
                  : (isDark ? Colors.white : Colors.black87),
            ),
          ),
          Text(
            period,
            style: TextStyle(
              fontSize: 12,
              color: isPopular
                  ? Colors.white70
                  : (isDark ? Colors.white54 : Colors.grey),
            ),
          ),
          if (discount != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPopular
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppTheme.successColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Save $discount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isPopular ? Colors.white : AppTheme.successColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
