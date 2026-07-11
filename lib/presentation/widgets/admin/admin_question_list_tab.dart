// lib/presentation/widgets/admin/admin_question_list_tab.dart
import 'dart:convert';
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
  Map<String, String> _questionPaths = {}; // docId -> Firestore doc path

  // Filters State
  late String _selectedExamMode;
  String _selectedSourceType = 'Practice'; // 'Practice' or 'Quiz'
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];
  String _searchQuery = '';
  String _viewLanguage = 'en'; // 'en', 'hi', 'bn'

  // Daily Quiz Dates dropdown state
  List<String> _quizDates = [];
  String? _selectedQuizDate;

  // Pagination State
  int _currentPage = 0;
  static const int _pageSize = 10;

  // Bulk Selection State
  final Set<String> _selectedQuestionKeys = {};

  // Duplicate detection list
  Set<String> _duplicateTexts = {};

  @override
  void initState() {
    super.initState();
    _selectedExamMode = widget.selectedExamMode;
    _fetchQuestions();
  }

  @override
  void didUpdateWidget(AdminQuestionListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedExamMode != widget.selectedExamMode) {
      setState(() {
        _selectedExamMode = widget.selectedExamMode;
        _selectedQuizDate = null;
        _quizDates.clear();
        _selectedQuestionKeys.clear();
      });
      _fetchQuestions();
    }
  }

  Future<void> _fetchQuizDates() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('quizzes')
          .get()
          .timeout(const Duration(seconds: 8));

      // Filter document IDs that correspond to the active exam mode (e.g. ending in _GENERAL, _BANK, _UPSC)
      final suffix = '_$_selectedExamMode';
      final dates = snap.docs
          .map((doc) => doc.id)
          .where((id) => id.endsWith(suffix))
          .toList()
        ..sort((a, b) => b.compareTo(a)); // Sort descending (latest dates first)

      setState(() {
        _quizDates = dates;
        if (dates.isNotEmpty) {
          _selectedQuizDate = dates.first;
        } else {
          _selectedQuizDate = null;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load quiz dates: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _fetchQuestions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _selectedQuestionKeys.clear();
    });

    try {
      _questionPaths.clear();
      List<QuestionModel> loaded = [];

      if (_selectedSourceType == 'Practice') {
        // Fetch from practice collection
        final doc = await FirebaseFirestore.instance
            .collection('practice')
            .doc(_selectedExamMode)
            .get();

        if (doc.exists) {
          final questionsData = doc.data()?['questions'] as List?;
          if (questionsData != null) {
            loaded = questionsData.map((e) {
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
          }
        }
      } else {
        // Daily Quiz Mode
        if (_quizDates.isEmpty) {
          await _fetchQuizDates();
        }

        if (_selectedQuizDate != null) {
          // Fetch questions directly from the subcollection of the selected quiz date
          final questionsSnapshot = await FirebaseFirestore.instance
              .collection('quizzes')
              .doc(_selectedQuizDate)
              .collection('questions')
              .orderBy('order')
              .get();

          loaded = questionsSnapshot.docs.map((doc) {
            // Cache the document path for edit/delete operations
            _questionPaths[doc.id] = doc.reference.path;
            return QuestionModel.fromFirestore(doc);
          }).toList();
        }
      }

      _detectDuplicates(loaded);

      final cats = {'All'};
      for (final q in loaded) {
        cats.add(q.category);
      }

      if (mounted) {
        setState(() {
          _questions = loaded;
          _categories = cats.toList()..sort();
          _selectedCategory = 'All';
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading questions: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
    List<QuestionModel> temp = _questions;

    // Category Filter
    if (_selectedCategory != 'All') {
      temp = temp.where((q) => q.category == _selectedCategory).toList();
    }

    // Search Query Filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      temp = temp.where((q) {
        final textEn = q.text['en']?.toLowerCase() ?? '';
        final textHi = q.text['hi']?.toLowerCase() ?? '';
        final textBn = q.text['bn']?.toLowerCase() ?? '';
        return textEn.contains(query) ||
            textHi.contains(query) ||
            textBn.contains(query);
      }).toList();
    }

    setState(() {
      _filteredQuestions = temp;
      _currentPage = 0;
    });
  }

  Future<void> _deleteQuestion(QuestionModel q) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    setState(() => _isLoading = true);

    try {
      if (_selectedSourceType == 'Practice') {
        final practiceRef = FirebaseFirestore.instance
            .collection('practice')
            .doc(_selectedExamMode);

        final updatedList = _questions
            .where((item) => item.id != q.id)
            .map((e) => e.toFirestore())
            .toList();

        await practiceRef.set({
          'exam_mode': _selectedExamMode,
          'questions': updatedList,
          'updated_at': FieldValue.serverTimestamp(),
        });
      } else {
        // Daily Quiz: delete by path
        final path = _questionPaths[q.id];
        if (path != null) {
          await FirebaseFirestore.instance.doc(path).delete();
        } else {
          throw 'Could not resolve question Firestore path';
        }
      }

      _selectedQuestionKeys.remove("${q.id}@@@${q.text['en']}");
      _fetchQuestions();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Question deleted!'),
            backgroundColor: AppColors.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to delete question: $e'),
            backgroundColor: AppColors.error),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSelectedQuestions() async {
    final count = _selectedQuestionKeys.length;
    if (count == 0) return;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bulk Delete'),
        content: Text('Are you sure you want to delete the $count selected questions?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    setState(() => _isLoading = true);

    try {
      if (_selectedSourceType == 'Practice') {
        final practiceRef = FirebaseFirestore.instance
            .collection('practice')
            .doc(_selectedExamMode);

        final updatedList = _questions
            .where((item) => !_selectedQuestionKeys.contains("${item.id}@@@${item.text['en']}"))
            .map((e) => e.toFirestore())
            .toList();

        await practiceRef.set({
          'exam_mode': _selectedExamMode,
          'questions': updatedList,
          'updated_at': FieldValue.serverTimestamp(),
        });
      } else {
        // Daily Quiz: bulk delete using batch write
        final batch = FirebaseFirestore.instance.batch();
        for (final key in _selectedQuestionKeys) {
          final id = key.split('@@@').first;
          final path = _questionPaths[id];
          if (path != null) {
            batch.delete(FirebaseFirestore.instance.doc(path));
          }
        }
        await batch.commit();
      }

      setState(() {
        _selectedQuestionKeys.clear();
      });
      _fetchQuestions();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$count questions deleted!'),
            backgroundColor: AppColors.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to delete questions: $e'),
            backgroundColor: AppColors.error),
      );
      setState(() => _isLoading = false);
    }
  }

  void _showEditDialog(QuestionModel q) {
    // Localization Controllers
    final textEnController = TextEditingController(text: q.text['en'] ?? '');
    final textHiController = TextEditingController(text: q.text['hi'] ?? '');
    final textBnController = TextEditingController(text: q.text['bn'] ?? '');

    final enOpts = q.options['en'] ?? ['', '', '', ''];
    final hiOpts = q.options['hi'] ?? ['', '', '', ''];
    final bnOpts = q.options['bn'] ?? ['', '', '', ''];

    final optControllersEn = List.generate(
        4, (i) => TextEditingController(text: i < enOpts.length ? enOpts[i] : ''));
    final optControllersHi = List.generate(
        4, (i) => TextEditingController(text: i < hiOpts.length ? hiOpts[i] : ''));
    final optControllersBn = List.generate(
        4, (i) => TextEditingController(text: i < bnOpts.length ? bnOpts[i] : ''));

    final expEnController = TextEditingController(text: q.explanation['en'] ?? '');
    final expHiController = TextEditingController(text: q.explanation['hi'] ?? '');
    final expBnController = TextEditingController(text: q.explanation['bn'] ?? '');

    // Metadata Controllers
    final categoryController = TextEditingController(text: q.category);
    String difficulty = q.difficulty.toLowerCase();
    if (difficulty != 'easy' && difficulty != 'medium' && difficulty != 'hard') {
      difficulty = 'medium';
    }
    int correctIndex = q.correctIndex;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return DefaultTabController(
              length: 4,
              child: AlertDialog(
                title: Row(
                  children: [
                    const Text('Edit Question', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(dialogCtx),
                    )
                  ],
                ),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.95,
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Column(
                    children: [
                      const TabBar(
                        isScrollable: true,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: AppColors.primary,
                        tabs: [
                          Tab(text: 'English'),
                          Tab(text: 'Hindi'),
                          Tab(text: 'Bengali'),
                          Tab(text: 'Metadata'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // English Fields
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Question Text (EN)'),
                                  TextField(
                                    controller: textEnController,
                                    maxLines: 2,
                                    decoration: _inputDecoration('Question text in English'),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildFieldLabel('Options (EN)'),
                                  ...List.generate(4, (i) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: TextField(
                                        controller: optControllersEn[i],
                                        decoration: _inputDecoration('Option ${['A','B','C','D'][i]} (EN)'),
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 12),
                                  _buildFieldLabel('Explanation (EN)'),
                                  TextField(
                                    controller: expEnController,
                                    maxLines: 2,
                                    decoration: _inputDecoration('Explanation in English'),
                                  ),
                                ],
                              ),
                            ),
                            // Hindi Fields
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Question Text (HI)'),
                                  TextField(
                                    controller: textHiController,
                                    maxLines: 2,
                                    decoration: _inputDecoration('Question text in Hindi'),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildFieldLabel('Options (HI)'),
                                  ...List.generate(4, (i) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: TextField(
                                        controller: optControllersHi[i],
                                        decoration: _inputDecoration('Option ${['A','B','C','D'][i]} (HI)'),
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 12),
                                  _buildFieldLabel('Explanation (HI)'),
                                  TextField(
                                    controller: expHiController,
                                    maxLines: 2,
                                    decoration: _inputDecoration('Explanation in Hindi'),
                                  ),
                                ],
                              ),
                            ),
                            // Bengali Fields
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Question Text (BN)'),
                                  TextField(
                                    controller: textBnController,
                                    maxLines: 2,
                                    decoration: _inputDecoration('Question text in Bengali'),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildFieldLabel('Options (BN)'),
                                  ...List.generate(4, (i) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: TextField(
                                        controller: optControllersBn[i],
                                        decoration: _inputDecoration('Option ${['A','B','C','D'][i]} (BN)'),
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 12),
                                  _buildFieldLabel('Explanation (BN)'),
                                  TextField(
                                    controller: expBnController,
                                    maxLines: 2,
                                    decoration: _inputDecoration('Explanation in Bengali'),
                                  ),
                                ],
                              ),
                            ),
                            // Metadata Fields
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Category'),
                                  TextField(
                                    controller: categoryController,
                                    decoration: _inputDecoration('e.g. History, Science'),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildFieldLabel('Difficulty'),
                                  DropdownButtonFormField<String>(
                                    value: difficulty,
                                    decoration: _inputDecoration(''),
                                    items: ['easy', 'medium', 'hard'].map((d) {
                                      return DropdownMenuItem(value: d, child: Text(d.toUpperCase()));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDialogState(() => difficulty = val);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _buildFieldLabel('Correct Option'),
                                  DropdownButtonFormField<int>(
                                    value: correctIndex,
                                    decoration: _inputDecoration(''),
                                    items: List.generate(4, (i) {
                                      return DropdownMenuItem(
                                        value: i,
                                        child: Text('Option ${['A','B','C','D'][i]}'),
                                      );
                                    }),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDialogState(() => correctIndex = val);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final updatedQ = QuestionModel(
                        id: q.id,
                        text: {
                          'en': textEnController.text.trim(),
                          'hi': textHiController.text.trim(),
                          'bn': textBnController.text.trim(),
                        },
                        options: {
                          'en': optControllersEn.map((c) => c.text.trim()).toList(),
                          'hi': optControllersHi.map((c) => c.text.trim()).toList(),
                          'bn': optControllersBn.map((c) => c.text.trim()).toList(),
                        },
                        correctIndex: correctIndex,
                        explanation: {
                          'en': expEnController.text.trim(),
                          'hi': expHiController.text.trim(),
                          'bn': expBnController.text.trim(),
                        },
                        category: categoryController.text.trim(),
                        difficulty: difficulty,
                        examTags: q.examTags,
                        order: q.order,
                      );

                      Navigator.pop(dialogCtx);
                      await _saveEditedQuestion(updatedQ);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Future<void> _saveEditedQuestion(QuestionModel updatedQ) async {
    setState(() => _isLoading = true);

    try {
      if (_selectedSourceType == 'Practice') {
        final practiceRef = FirebaseFirestore.instance
            .collection('practice')
            .doc(_selectedExamMode);

        final updatedList = _questions.map((item) {
          return item.id == updatedQ.id ? updatedQ : item;
        }).map((e) => e.toFirestore()).toList();

        await practiceRef.set({
          'exam_mode': _selectedExamMode,
          'questions': updatedList,
          'updated_at': FieldValue.serverTimestamp(),
        });
      } else {
        // Daily Quiz: save in Firestore by path
        final path = _questionPaths[updatedQ.id];
        if (path != null) {
          await FirebaseFirestore.instance.doc(path).set(updatedQ.toFirestore());
        } else {
          throw 'Could not resolve question Firestore path';
        }
      }

      _fetchQuestions();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Question updated successfully!'),
            backgroundColor: AppColors.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to save changes: $e'),
            backgroundColor: AppColors.error),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final startIndex = _currentPage * _pageSize;
    final pageCount = (_filteredQuestions.length / _pageSize).ceil();
    final paginatedQuestions =
        _filteredQuestions.skip(startIndex).take(_pageSize).toList();

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Filters Section
              Card(
                color: isDark ? AppColors.cardDark : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      // Filter Row 1: Exam Mode and Source Type
                      Row(
                        children: [
                          // Exam Mode Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedExamMode,
                              isExpanded: true,
                              decoration: _filterDecoration('Exam Mode'),
                              dropdownColor:
                                  isDark ? AppColors.cardDark : Colors.white,
                              items: ['GENERAL', 'BANK', 'UPSC'].map((mode) {
                                return DropdownMenuItem(
                                    value: mode, child: Text(mode));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedExamMode = val;
                                    _selectedQuizDate = null;
                                    _quizDates.clear();
                                    _selectedQuestionKeys.clear();
                                  });
                                  _fetchQuestions();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Source Type Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedSourceType,
                              isExpanded: true,
                              decoration: _filterDecoration('Type'),
                              dropdownColor:
                                  isDark ? AppColors.cardDark : Colors.white,
                              items: ['Practice', 'Quiz'].map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(type == 'Practice'
                                      ? 'Practice Mode'
                                      : 'Daily Quiz'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedSourceType = val;
                                    _selectedQuizDate = null;
                                    _quizDates.clear();
                                    _selectedQuestionKeys.clear();
                                  });
                                  _fetchQuestions();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Conditional Filter Row: Quiz Date Selector (Visible only for Daily Quiz)
                      if (_selectedSourceType == 'Quiz' && _quizDates.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          value: _selectedQuizDate,
                          isExpanded: true,
                          decoration: _filterDecoration('Quiz Date / Document'),
                          dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                          items: _quizDates.map((date) {
                            // Extract pretty date format if possible (e.g. 2026-04-12)
                            final pretty = date.split('_').first;
                            return DropdownMenuItem(
                              value: date,
                              child: Text('$pretty ($_selectedExamMode)'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedQuizDate = val;
                                _selectedQuestionKeys.clear();
                              });
                              _fetchQuestions();
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Filter Row 2: Category and Language
                      Row(
                        children: [
                          // Category Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              isExpanded: true,
                              decoration: _filterDecoration('Category'),
                              dropdownColor:
                                  isDark ? AppColors.cardDark : Colors.white,
                              items: _categories.map((c) {
                                return DropdownMenuItem(
                                    value: c, child: Text(c));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedCategory = val;
                                  });
                                  _applyFilters();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // View Language Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _viewLanguage,
                              isExpanded: true,
                              decoration: _filterDecoration('View Language'),
                              dropdownColor:
                                  isDark ? AppColors.cardDark : Colors.white,
                              items: const [
                                DropdownMenuItem(value: 'en', child: Text('English (EN)')),
                                DropdownMenuItem(value: 'hi', child: Text('Hindi (HI)')),
                                DropdownMenuItem(value: 'bn', child: Text('Bengali (BN)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _viewLanguage = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Search Box Row
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search text...',
                          labelText: 'Search',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded,
                                      size: 16),
                                  onPressed: () {
                                    setState(() => _searchQuery = '');
                                    _applyFilters();
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val);
                          _applyFilters();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Selection / Bulk delete headers
              if (_filteredQuestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _filteredQuestions.isNotEmpty &&
                            _selectedQuestionKeys.length ==
                                _filteredQuestions.length,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedQuestionKeys.addAll(_filteredQuestions
                                  .map((q) => "${q.id}@@@${q.text['en']}"));
                            } else {
                              _selectedQuestionKeys.clear();
                            }
                          });
                        },
                      ),
                      const Text('Select All',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: _fetchQuestions,
                        tooltip: 'Refresh Questions',
                      ),
                      if (_selectedQuestionKeys.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _deleteSelectedQuestions,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                          label: Text('Delete (${_selectedQuestionKeys.length})'),
                        ),
                      ],
                    ],
                  ),
                ),

              // Questions List
              Expanded(
                child: paginatedQuestions.isEmpty
                    ? const Center(child: Text('No questions found.'))
                    : ListView.builder(
                        itemCount: paginatedQuestions.length,
                        itemBuilder: (ctx, index) {
                          final q = paginatedQuestions[index];
                          final textToShow = q.getText(_viewLanguage);
                          final optionsToShow = q.getOptions(_viewLanguage);
                          final textEn = q.text['en'] ?? '';
                          final isDuplicate = _duplicateTexts
                              .contains(textEn.toLowerCase().trim());
                          final selectionKey = "${q.id}@@@${q.text['en']}";
                          final isSelected =
                              _selectedQuestionKeys.contains(selectionKey);

                          final categoryColor = AppColors.categoryColor(q.category);
                          final diffColor = _difficultyColor(q.difficulty);

                          return Card(
                            color: isDark ? AppColors.cardDark : Colors.white,
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shadowColor: isSelected
                                ? AppColors.primary.withValues(alpha: 0.4)
                                : Colors.black.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isDuplicate
                                    ? AppColors.warning
                                    : isSelected
                                        ? AppColors.primary
                                        : (isDark
                                            ? Colors.white10
                                            : Colors.black
                                                .withValues(alpha: 0.05)),
                                width: isDuplicate || isSelected ? 1.8 : 1.0,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Warning Banner for Duplicate
                                  if (isDuplicate) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: AppColors.warning
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.warning_amber_rounded,
                                              size: 14,
                                              color: AppColors.warning),
                                          SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Potential Duplicate question detected in database!',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.warning),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  Row(
                                    children: [
                                      // Bulk checkbox selection
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: isSelected,
                                          activeColor: AppColors.primary,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4)),
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedQuestionKeys.add(selectionKey);
                                              } else {
                                                _selectedQuestionKeys.remove(selectionKey);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Category Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: categoryColor
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: categoryColor
                                                  .withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          q.category,
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: categoryColor),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Difficulty Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: diffColor
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: diffColor
                                                  .withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          q.difficulty.toUpperCase(),
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: diffColor),
                                        ),
                                      ),
                                      const Spacer(),
                                      // Edit Button
                                      IconButton(
                                        icon: const Icon(Icons.edit_rounded,
                                            color: AppColors.primary, size: 18),
                                        onPressed: () => _showEditDialog(q),
                                        tooltip: 'Edit Question',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                      ),
                                      const SizedBox(width: 6),
                                      // Delete Button
                                      IconButton(
                                        icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: AppColors.error,
                                            size: 18),
                                        onPressed: () => _deleteQuestion(q),
                                        tooltip: 'Delete Question',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Question Text (Active language selection)
                                  Text(
                                    textToShow,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isDark ? Colors.white : Colors.black87),
                                  ),
                                  const SizedBox(height: 12),
                                  // Option list (Active language selection)
                                  ...List.generate(
                                    optionsToShow.length,
                                    (idx) {
                                      final isCorrect = idx == q.correctIndex;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 3.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isCorrect
                                                ? AppColors.success
                                                    .withValues(alpha: 0.08)
                                                : (isDark
                                                    ? Colors.white
                                                        .withValues(alpha: 0.02)
                                                    : Colors.black
                                                        .withValues(alpha: 0.015)),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isCorrect
                                                  ? AppColors.success
                                                      .withValues(alpha: 0.3)
                                                  : (isDark
                                                      ? Colors.white10
                                                      : Colors.black
                                                          .withValues(alpha: 0.05)),
                                              width: isCorrect ? 1.2 : 1.0,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isCorrect
                                                    ? Icons.check_circle_rounded
                                                    : Icons
                                                        .radio_button_unchecked_rounded,
                                                size: 14,
                                                color: isCorrect
                                                    ? AppColors.success
                                                    : Colors.grey,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  optionsToShow[idx],
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isCorrect
                                                        ? AppColors.success
                                                        : (isDark
                                                            ? Colors.white70
                                                            : Colors.black54),
                                                    fontWeight: isCorrect
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
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
                const SizedBox(height: 12),
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
          );
  }

  Color _difficultyColor(String diff) {
    switch (diff.toLowerCase().trim()) {
      case 'easy':
        return AppColors.success;
      case 'medium':
        return AppColors.warning;
      case 'hard':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  InputDecoration _filterDecoration(String label) {
    return InputDecoration(
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
