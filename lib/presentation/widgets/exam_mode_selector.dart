// lib/presentation/widgets/exam_mode_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../providers/app_providers.dart';

class ExamModeSelector extends ConsumerWidget {
  final bool isDark;

  const ExamModeSelector({
    super.key,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(examModeProvider);
    final modes = [
      ('GENERAL', '📚'),
      ('UPSC', '🎯'),
      ('BANK', '💰')
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.school_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Exam Mode',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white60 : Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: modes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final mode = modes[i].$1;
              final emoji = modes[i].$2;
              final selected = mode == current;
              return GestureDetector(
                onTap: () {
                  ref.read(examModeProvider.notifier).state = mode;
                  ref.invalidate(todayQuizProvider);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? (isDark
                            ? AppColors.primaryGradientDark
                            : AppColors.primaryGradient)
                        : null,
                    color: selected
                        ? null
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.2)),
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$emoji $mode',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
