// lib/presentation/widgets/admin/admin_timing_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/quiz_scheduler_service.dart';
import '../../../core/theme/app_colors.dart';

class AdminTimingTab extends StatefulWidget {
  const AdminTimingTab({super.key});

  @override
  State<AdminTimingTab> createState() => _AdminTimingTabState();
}

class _AdminTimingTabState extends State<AdminTimingTab> {
  bool _isLoading = false;
  int _quizStartHour = 6;
  int _quizStartMinute = 0;
  int _quizEndHour = 23;
  int _quizEndMinute = 45;

  int _savedStartHour = 6;
  int _savedStartMinute = 0;
  int _savedEndHour = 23;
  int _savedEndMinute = 45;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    final sched = QuizSchedulerService.instance;
    setState(() {
      _quizStartHour = sched.quizStartHour;
      _quizStartMinute = sched.quizStartMinute;
      _quizEndHour = sched.quizEndHour;
      _quizEndMinute = sched.quizEndMinute;

      _savedStartHour = sched.quizStartHour;
      _savedStartMinute = sched.quizStartMinute;
      _savedEndHour = sched.quizEndHour;
      _savedEndMinute = sched.quizEndMinute;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _saveQuizTimingConfig() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('quiz_timing')
          .set({
        'start_hour': _quizStartHour,
        'start_minute': _quizStartMinute,
        'end_hour': _quizEndHour,
        'end_minute': _quizEndMinute,
        'updated_at': FieldValue.serverTimestamp(),
      });
      await QuizSchedulerService.instance.refreshTiming();
      setState(() {
        _savedStartHour = _quizStartHour;
        _savedStartMinute = _quizStartMinute;
        _savedEndHour = _quizEndHour;
        _savedEndMinute = _quizEndMinute;
      });
      _showSnackBar('Quiz timing configuration saved successfully!');
    } catch (e) {
      _showSnackBar('Error saving: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.schedule_rounded, color: AppColors.primary, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Quiz Availability Window',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Configure the hours during which the Daily Quiz remains active in Indian Standard Time (IST).',
                style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildCurrentConfigCard(isDark),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Start Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildDropdown<int>(
                        value: _get12Hour(_quizStartHour),
                        items: List.generate(12, (i) => i + 1),
                        onChanged: (v) => setState(() => _quizStartHour = _get24Hour(v!, _getPeriod(_quizStartHour))),
                        isDark: isDark,
                      ),
                      const Text(' : ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      _buildDropdown<int>(
                        value: _quizStartMinute,
                        items: [0, 15, 30, 45],
                        onChanged: (v) => setState(() => _quizStartMinute = v!),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildDropdown<String>(
                        value: _getPeriod(_quizStartHour),
                        items: ['AM', 'PM'],
                        onChanged: (v) => setState(() => _quizStartHour = _get24Hour(_get12Hour(_quizStartHour), v!)),
                        isDark: isDark,
                        displayMapper: (s) => s,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('End Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildDropdown<int>(
                        value: _get12Hour(_quizEndHour),
                        items: List.generate(12, (i) => i + 1),
                        onChanged: (v) => setState(() => _quizEndHour = _get24Hour(v!, _getPeriod(_quizEndHour))),
                        isDark: isDark,
                      ),
                      const Text(' : ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      _buildDropdown<int>(
                        value: _quizEndMinute,
                        items: [0, 15, 30, 45],
                        onChanged: (v) => setState(() => _quizEndMinute = v!),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildDropdown<String>(
                        value: _getPeriod(_quizEndHour),
                        items: ['AM', 'PM'],
                        onChanged: (v) => setState(() => _quizEndHour = _get24Hour(_get12Hour(_quizEndHour), v!)),
                        isDark: isDark,
                        displayMapper: (s) => s,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveQuizTimingConfig,
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded),
                  label: const Text('Save Timing Config', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _get12Hour(int hour24) {
    int hour12 = hour24 % 12;
    return hour12 == 0 ? 12 : hour12;
  }

  String _getPeriod(int hour24) {
    return hour24 >= 12 ? 'PM' : 'AM';
  }

  int _get24Hour(int hour12, String period) {
    if (period == 'AM') {
      return hour12 == 12 ? 0 : hour12;
    } else {
      return hour12 == 12 ? 12 : hour12 + 12;
    }
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required bool isDark,
    String Function(T)? displayMapper,
  }) {
    final dropdownItems = List<T>.from(items);
    if (!dropdownItems.contains(value)) {
      dropdownItems.add(value);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
      ),
      child: DropdownButton<T>(
        value: value,
        dropdownColor: isDark ? AppColors.cardDark : Colors.white,
        underline: const SizedBox(),
        items: dropdownItems.map((h) => DropdownMenuItem<T>(
          value: h,
          child: Text(displayMapper != null ? displayMapper(h) : h.toString().padLeft(2, '0')),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildCurrentConfigCard(bool isDark) {
    final startPeriod = _getPeriod(_savedStartHour);
    final startHour12 = _get12Hour(_savedStartHour).toString().padLeft(2, '0');
    final startMin = _savedStartMinute.toString().padLeft(2, '0');

    final endPeriod = _getPeriod(_savedEndHour);
    final endHour12 = _get12Hour(_savedEndHour).toString().padLeft(2, '0');
    final endMin = _savedEndMinute.toString().padLeft(2, '0');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Active Timing',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$startHour12:$startMin $startPeriod to $endHour12:$endMin $endPeriod (IST)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
