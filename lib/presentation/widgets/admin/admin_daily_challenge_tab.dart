// lib/presentation/widgets/admin/admin_daily_challenge_tab.dart
import 'package:flutter/material.dart';

import '../../../core/scoring/daily_challenge_service.dart';
import '../../../core/theme/app_colors.dart';

class AdminDailyChallengeTab extends StatefulWidget {
  const AdminDailyChallengeTab({super.key});

  @override
  State<AdminDailyChallengeTab> createState() => _AdminDailyChallengeTabState();
}

class _AdminDailyChallengeTabState extends State<AdminDailyChallengeTab> {
  bool _isLoading = true;
  bool _isDefault = false;
  DateTime _selectedDate = DailyChallengeService.challengeDate();
  final Set<String> _selectedIds = <String>{};

  String get _documentId => _isDefault
      ? DailyChallengeService.defaultConfigId
      : _dateId(_selectedDate);

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(DailyChallengeService.fallbackGameIds);
    _loadSchedule();
  }

  String _dateId(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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

  Future<void> _loadSchedule() async {
    setState(() => _isLoading = true);
    try {
      final ids = await DailyChallengeService.instance.loadSchedule(_documentId);
      setState(() => _selectedIds
        ..clear()
        ..addAll(ids));
    } catch (e) {
      _showSnackBar('Failed to load daily games: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSchedule() async {
    if (_selectedIds.isEmpty) {
      _showSnackBar('Select at least one game.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await DailyChallengeService.instance.saveSchedule(
        _documentId,
        DailyChallengeService.dailyGames
            .map((game) => game.gameId)
            .where(_selectedIds.contains)
            .toList(),
      );
      _showSnackBar(_isDefault
          ? 'Default daily games saved.'
          : 'Daily games saved for ${_dateId(_selectedDate)}.');
    } catch (e) {
      _showSnackBar('Error saving: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Theme.of(context).brightness,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
    await _loadSchedule();
  }

  IconData _iconFor(String gameId) {
    switch (gameId) {
      case 'quiz':
        return Icons.quiz_rounded;
      case 'synapse':
        return Icons.psychology_rounded;
      case 'stroop':
        return Icons.palette_rounded;
      case 'math':
        return Icons.calculate_rounded;
      case 'flowFree':
        return Icons.water_drop_rounded;
      case 'oneLine':
        return Icons.draw_rounded;
      case 'arrowSilhouette':
        return Icons.alt_route_rounded;
      case 'dualDrive':
        return Icons.directions_car_rounded;
      default:
        return Icons.sports_esports_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.emoji_events_rounded,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Challenge Games',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Choose any number of play-zone games. Every selected game gets its own official score.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildModeChip(
                      label: 'Specific date',
                      icon: Icons.calendar_today_rounded,
                      selected: !_isDefault,
                      onTap: () {
                        if (_isDefault) {
                          setState(() => _isDefault = false);
                          _loadSchedule();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildModeChip(
                      label: 'Every day default',
                      icon: Icons.repeat_rounded,
                      selected: _isDefault,
                      onTap: () {
                        if (!_isDefault) {
                          setState(() => _isDefault = true);
                          _loadSchedule();
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (!_isDefault) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range_rounded,
                            color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text(
                          _dateId(_selectedDate),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.expand_more_rounded),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Column(
                  children: DailyChallengeService.dailyGames.map((game) {
                    final selected = _selectedIds.contains(game.gameId);
                    return Card(
                      color: cardColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: selected
                              ? AppColors.primary
                              : (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.08),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: CheckboxListTile(
                        value: selected,
                        onChanged: (value) {
                          setState(() {
                            if (value ?? false) {
                              _selectedIds.add(game.gameId);
                            } else {
                              _selectedIds.remove(game.gameId);
                            }
                          });
                        },
                        secondary: Icon(_iconFor(game.gameId),
                            color: AppColors.primary),
                        title: Text(
                          game.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        subtitle: Text(
                          '${game.badge} · ${game.gameId}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                        ),
                        activeColor: AppColors.primary,
                        checkColor: Colors.black,
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveSchedule,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('SAVE DAILY GAMES'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? AppColors.primary : Colors.grey),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.primary : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
