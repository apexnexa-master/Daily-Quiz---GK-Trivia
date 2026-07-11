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

  // Date selection states
  bool _isGlobalDefault = true; // true: quiz_timing, false: quiz_timing_YYYY-MM-DD
  DateTime _selectedTimingDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadQuizTimingConfig();
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

  Future<void> _loadQuizTimingConfig() async {
    setState(() => _isLoading = true);
    try {
      final docId = _isGlobalDefault
          ? 'quiz_timing'
          : 'quiz_timing_${_selectedTimingDate.year}-${_selectedTimingDate.month.toString().padLeft(2, '0')}-${_selectedTimingDate.day.toString().padLeft(2, '0')}';

      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc(docId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _quizStartHour = data['start_hour'] ?? 6;
          _quizStartMinute = data['start_minute'] ?? 0;
          _quizEndHour = data['end_hour'] ?? 23;
          _quizEndMinute = data['end_minute'] ?? 45;

          _savedStartHour = _quizStartHour;
          _savedStartMinute = _quizStartMinute;
          _savedEndHour = _quizEndHour;
          _savedEndMinute = _quizEndMinute;
        });
      } else {
        // Fallback or templates if no document exists
        if (!_isGlobalDefault) {
          // If a specific date override doesn't exist yet, fetch current global timing as template
          final globalDoc = await FirebaseFirestore.instance
              .collection('settings')
              .doc('quiz_timing')
              .get();
          if (globalDoc.exists) {
            final data = globalDoc.data()!;
            setState(() {
              _quizStartHour = data['start_hour'] ?? 6;
              _quizStartMinute = data['start_minute'] ?? 0;
              _quizEndHour = data['end_hour'] ?? 23;
              _quizEndMinute = data['end_minute'] ?? 45;
            });
          }
        } else {
          // Absolute defaults
          setState(() {
            _quizStartHour = 6;
            _quizStartMinute = 0;
            _quizEndHour = 23;
            _quizEndMinute = 45;
          });
        }
      }
    } catch (e) {
      _showSnackBar('Failed to load timing: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveQuizTimingConfig() async {
    setState(() => _isLoading = true);
    try {
      final docId = _isGlobalDefault
          ? 'quiz_timing'
          : 'quiz_timing_${_selectedTimingDate.year}-${_selectedTimingDate.month.toString().padLeft(2, '0')}-${_selectedTimingDate.day.toString().padLeft(2, '0')}';

      await FirebaseFirestore.instance
          .collection('settings')
          .doc(docId)
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

  Future<void> _selectTimingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedTimingDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTimingDate = picked;
      });
      _loadQuizTimingConfig();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Padding(
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
                  'Configure start and end hours for the Daily Quiz in Indian Standard Time (IST). You can set a global default schedule or overrides for specific dates.',
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 16),

                // Timing Type Selector Row
                Row(
                  children: [
                    Expanded(
                      child: _buildTimingTypeChip('Global Default', true, isDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTimingTypeChip('Specific Date', false, isDark),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date Picker row for specific date
                if (!_isGlobalDefault) ...[
                  GestureDetector(
                    onTap: _selectTimingDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Timing Override Date',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_selectedTimingDate.year}-${_selectedTimingDate.month.toString().padLeft(2, '0')}-${_selectedTimingDate.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                _isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _saveQuizTimingConfig,
                                  icon: const Icon(Icons.save_rounded),
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
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimingTypeChip(String label, bool isGlobal, bool isDark) {
    final selected = isGlobal == _isGlobalDefault;
    return GestureDetector(
      onTap: () {
        if (_isGlobalDefault != isGlobal) {
          setState(() {
            _isGlobalDefault = isGlobal;
          });
          _loadQuizTimingConfig();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : (isDark ? Colors.white10 : Colors.grey[200]),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentConfigCard(bool isDark) {
    final startPeriod = _getPeriod(_savedStartHour);
    final endPeriod = _getPeriod(_savedEndHour);
    final startH12 = _get12Hour(_savedStartHour);
    final endH12 = _get12Hour(_savedEndHour);
    final startMinStr = _savedStartMinute.toString().padLeft(2, '0');
    final endMinStr = _savedEndMinute.toString().padLeft(2, '0');

    final title = _isGlobalDefault
        ? 'Global Default Schedule'
        : 'Override for ${_selectedTimingDate.year}-${_selectedTimingDate.month.toString().padLeft(2, '0')}-${_selectedTimingDate.day.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
          ),
          const SizedBox(height: 6),
          Text(
            'Active from: $startH12:$startMinStr $startPeriod  to  $endH12:$endMinStr $endPeriod',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
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
      dropdownItems.insert(0, value);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: false,
          dropdownColor: isDark ? AppColors.cardDark : Colors.white,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          items: dropdownItems.map((item) {
            final text = displayMapper != null
                ? displayMapper(item)
                : (item is int ? item.toString().padLeft(2, '0') : item.toString());
            return DropdownMenuItem<T>(
              value: item,
              child: Text(text),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
