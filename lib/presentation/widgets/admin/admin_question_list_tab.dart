// lib/presentation/widgets/admin/admin_question_list_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_models.dart';
import '../../../core/theme/app_colors.dart';

class AdminQuestionListTab extends StatefulWidget {
  final String selectedExamMode;

  const AdminQuestionListTab({
    super.key,
    required this.selectedExamMode,
  });

  @override
  State<AdminQuestionListTab> createState() => _AdminQuestionListTabState();
}

class _AdminQuestionListTabState extends State<AdminQuestionListTab> {
  bool _isLoading = false;
  List<QuestionModel> _questions = [];
  List<QuestionModel> _filteredQuestions = [];
  
  // Pagination variables
  int _currentPage = 0;
  static const int _pageSize = 10;
  
  // Filter variables
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];
  
  // Duplicate detection list
  Set<String> _duplicateTexts = {};

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  @override
  void didUpdateWidget(AdminQuestionListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedExamMode != widget.selectedExamMode) {
      _fetchQuestions();
    }
  }

  Future<void> _fetchQuestions() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
    });

    try {
      final doc = await FirebaseFirestore.instance.collection('practice').doc(widget.selectedExamMode).get();
      if (doc.exists) {
        final questionsData = doc.data()?['questions'] as List?;
        if (questionsData != null) {
          final loaded = questionsData.map((e) {
            final m = e as Map<String, dynamic>;
            return QuestionModel(
              id: m['id'] ?? '',
              text: Map<String, String>.from(m['text'] ?? {}),
              options: (m['options'] as Map).map(
                (k, v) => MapEntry(k as String, List<String>.from(v ?? [])),
              ),
              correctIndex: m['correct_index'] ?? 0,
              explanation: Map<String, String>.from(m['explanation'] ?? {}),
              category: m['category'] ?? 'General Knowledge',
              difficulty: m['difficulty'] ?? 'medium',
              examTags: List<String>.from(m['exam_tags'] ?? []),
              order: m['order'] ?? 0,
            );
          }).toList();

          _detectDuplicates(loaded);
          
          final cats = {'All'};
          for (final q in loaded) {
            cats.add(q.category);
          }

          setState(() {
            _questions = loaded;
            _categories = cats.toList()..sort();
            _selectedCategory = 'All';
            _applyFilters();
          });
        }
      } else {
        setState(() {
          _questions = [];
          _filteredQuestions = [];
          _categories = ['All'];
          _selectedCategory = 'All';
        });
      }
    } catch (_) {
      // Handle error gracefully
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _detectDuplicates(List<QuestionModel> list) {
    final seen = <String>{};
    final dupes = <String>{};
    for (final q in list) {
      final text = q.text['en']?.trim().toLowerCase() ?? '';
      if (text.isNotEmpty) {
        if (seen.contains(text)) {
          dupes.add(text);
        } else {
          seen.add(text);
        }
      }
    }
    _duplicateTexts = dupes;
  }

  void _applyFilters() {
    if (_selectedCategory == 'All') {
      _filteredQuestions = _questions;
    } else {
      _filteredQuestions = _questions.where((q) => q.category == _selectedCategory).toList();
    }
    _currentPage = 0;
  }

  Future<void> _deleteQuestion(QuestionModel q) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    setState(() => _isLoading = true);

    try {
      final practiceRef = FirebaseFirestore.instance.collection('practice').doc(widget.selectedExamMode);
      final updatedList = _questions.where((item) => item.id != q.id).map((e) => e.toFirestore()).toList();
      
      await practiceRef.set({
        'exam_mode': widget.selectedExamMode,
        'questions': updatedList,
        'updated_at': FieldValue.serverTimestamp(),
      });

      _fetchQuestions();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question deleted!'), backgroundColor: AppColors.success),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete question'), backgroundColor: AppColors.error),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final startIndex = _currentPage * _pageSize;
    final pageCount = (_filteredQuestions.length / _pageSize).ceil();
    final paginatedQuestions = _filteredQuestions.skip(startIndex).take(_pageSize).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter dropdown
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDark : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            isExpanded: true,
                            dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                            items: _categories
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _selectedCategory = v!;
                                _applyFilters();
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _fetchQuestions,
                    )
                  ],
                ),
                const SizedBox(height: 16),
                
                // Question list
                Expanded(
                  child: paginatedQuestions.isEmpty
                      ? const Center(child: Text('No questions found.'))
                      : ListView.builder(
                          itemCount: paginatedQuestions.length,
                          itemBuilder: (ctx, index) {
                            final q = paginatedQuestions[index];
                            final textEn = q.text['en'] ?? '';
                            final isDuplicate = _duplicateTexts.contains(textEn.toLowerCase().trim());
                            return Card(
                              color: isDark ? AppColors.cardDark : Colors.white,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isDuplicate 
                                      ? AppColors.warning 
                                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                  width: isDuplicate ? 1.5 : 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            q.category,
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.success.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            q.difficulty,
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success),
                                          ),
                                        ),
                                        if (isDuplicate) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.warning.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.warning_amber_rounded, size: 10, color: AppColors.warning),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Duplicate',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warning),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const Spacer(),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                          onPressed: () => _deleteQuestion(q),
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        )
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      textEn,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 8),
                                    ...List.generate(
                                      q.options['en']?.length ?? 0,
                                      (idx) {
                                        final isCorrect = idx == q.correctIndex;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isCorrect ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                                size: 14,
                                                color: isCorrect ? AppColors.success : Colors.grey,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  q.options['en']![idx],
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isCorrect ? AppColors.success : (isDark ? Colors.white70 : Colors.black54),
                                                    fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                
                // Pagination controls
                if (pageCount > 1) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: _currentPage > 0
                            ? () => setState(() => _currentPage--)
                            : null,
                        child: const Text('Prev'),
                      ),
                      Text('Page ${_currentPage + 1} of $pageCount'),
                      ElevatedButton(
                        onPressed: _currentPage < pageCount - 1
                            ? () => setState(() => _currentPage++)
                            : null,
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}
