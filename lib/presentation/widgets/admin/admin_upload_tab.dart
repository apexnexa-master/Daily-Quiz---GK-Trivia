// lib/presentation/widgets/admin/admin_upload_tab.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/question_service.dart';
import '../../../data/models/firestore_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class AdminUploadTab extends StatefulWidget {
  final String selectedExamMode;
  final ValueChanged<String> onExamModeChanged;
  final bool isDailyQuiz;
  final ValueChanged<bool> onQuizTypeChanged;

  const AdminUploadTab({
    super.key,
    required this.selectedExamMode,
    required this.onExamModeChanged,
    required this.isDailyQuiz,
    required this.onQuizTypeChanged,
  });

  @override
  State<AdminUploadTab> createState() => _AdminUploadTabState();
}

class _AdminUploadTabState extends State<AdminUploadTab> {
  final _bulkQuestionsController = TextEditingController();
  bool _isLoading = false;
  bool _showGuide = false;
  final List<String> _examModes = ['GENERAL', 'WBPSC', 'SSC', 'UPSC', 'BANK'];

  @override
  void dispose() {
    _bulkQuestionsController.dispose();
    super.dispose();
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

  Future<void> _uploadBulkQuestions() async {
    final input = _bulkQuestionsController.text.trim();
    if (input.isEmpty) {
      _showSnackBar('Please paste questions', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final questions = _parseQuestions(input);
      if (questions.isEmpty) {
        _showSnackBar('No valid questions found. Check format!', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      // Check duplicates
      final duplicates = _findDuplicates(questions);
      if (duplicates.isNotEmpty) {
        final proceed = await _showDuplicateWarningDialog(duplicates);
        if (proceed != true) {
          setState(() => _isLoading = false);
          return;
        }
      }

      if (widget.isDailyQuiz) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        await QuestionService.instance.uploadQuestions(
          examMode: widget.selectedExamMode,
          questions: questions,
          date: today,
        );
        _showSnackBar('${questions.length} questions uploaded to $today quiz!');
      } else {
        await QuestionService.instance.uploadPracticeQuestions(
          examMode: widget.selectedExamMode,
          questions: questions,
        );
        _showSnackBar('${questions.length} questions uploaded to practice list!');
      }

      _bulkQuestionsController.clear();
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<QuestionModel> _parseQuestions(String input) {
    // 1. JSON List detection
    if (input.startsWith('[') && input.endsWith(']')) {
      try {
        final list = jsonDecode(input) as List;
        return list.map((item) {
          final m = item as Map<String, dynamic>;
          final id = m['id'] ?? 'q_${DateTime.now().millisecondsSinceEpoch}_${m['order'] ?? 0}';
          return QuestionModel(
            id: id,
            text: Map<String, String>.from(m['text'] ?? {}),
            options: (m['options'] as Map).map(
              (k, v) => MapEntry(k as String, List<String>.from(v ?? [])),
            ),
            correctIndex: m['correctIndex'] ?? m['correct_index'] ?? 0,
            explanation: Map<String, String>.from(m['explanation'] ?? {}),
            category: m['category'] ?? 'General Knowledge',
            difficulty: m['difficulty'] ?? 'medium',
            examTags: [widget.selectedExamMode],
            order: m['order'] ?? 0,
          );
        }).toList();
      } catch (_) {
        // Fallback to text parsing if JSON decoding fails
      }
    }

    // 2. CSV parsing detection
    if (input.toLowerCase().startsWith('question,') || input.split('\n')[0].contains(',')) {
      final lines = input.split('\n');
      final questions = <QuestionModel>[];
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty || line.toLowerCase().startsWith('question,')) continue;
        
        final parts = _parseCsvLine(line);
        if (parts.length >= 6) {
          final questionText = parts[0];
          final options = parts.sublist(1, 5);
          final ans = parts[5].toUpperCase();
          int correctIndex = 0;
          if (ans == 'B' || ans == '2') correctIndex = 1;
          if (ans == 'C' || ans == '3') correctIndex = 2;
          if (ans == 'D' || ans == '4') correctIndex = 3;

          final difficulty = parts.length > 6 ? parts[6].toLowerCase() : 'medium';
          final category = parts.length > 7 ? parts[7] : 'General Knowledge';

          questions.add(QuestionModel(
            id: 'q_${DateTime.now().millisecondsSinceEpoch}_$i',
            text: {'en': questionText, 'hi': questionText, 'bn': questionText},
            options: {'en': options, 'hi': options, 'bn': options},
            correctIndex: correctIndex,
            explanation: {'en': '', 'hi': '', 'bn': ''},
            category: category,
            difficulty: difficulty,
            examTags: [widget.selectedExamMode],
            order: questions.length,
          ));
        }
      }
      if (questions.isNotEmpty) return questions;
    }

    // 3. Fallback: Custom text format parser
    final questions = <QuestionModel>[];
    final blocks = input.split(RegExp(r'\n\s*\n'));

    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i].trim();
      if (block.isEmpty) continue;

      final lines = block.split('\n');
      String? questionEn, questionHi, questionBn;
      final optionsEn = <String>[];
      final optionsHi = <String>[];
      final optionsBn = <String>[];
      String diff = 'medium';
      int correctIndex = 0;
      String? category;
      String? expEn, expHi, expBn;

      for (final line in lines) {
        final l = line.trim();
        if (l.isEmpty) continue;

        if (l.toLowerCase().startsWith('q:en') ||
            l.toLowerCase().startsWith('a:en') ||
            l.toLowerCase().startsWith('b:en') ||
            l.toLowerCase().startsWith('c:en') ||
            l.toLowerCase().startsWith('d:en') ||
            l.toLowerCase().startsWith('exp:en')) {
          final colonIndex = l.indexOf(':');
          final prefix = l.substring(0, colonIndex + 3).toLowerCase();
          final value = l.substring(colonIndex + 3).trim();

          if (prefix == 'q:en') questionEn = value;
          else if (prefix == 'a:en') optionsEn.add(value);
          else if (prefix == 'b:en') optionsEn.add(value);
          else if (prefix == 'c:en') optionsEn.add(value);
          else if (prefix == 'd:en') optionsEn.add(value);
          else if (prefix == 'exp:en') expEn = value;
          continue;
        }

        if (l.toLowerCase().startsWith('q:hi') ||
            l.toLowerCase().startsWith('a:hi') ||
            l.toLowerCase().startsWith('b:hi') ||
            l.toLowerCase().startsWith('c:hi') ||
            l.toLowerCase().startsWith('d:hi') ||
            l.toLowerCase().startsWith('exp:hi')) {
          final colonIndex = l.indexOf(':');
          final prefix = l.substring(0, colonIndex + 3).toLowerCase();
          final value = l.substring(colonIndex + 3).trim();

          if (prefix == 'q:hi') questionHi = value;
          else if (prefix == 'a:hi') optionsHi.add(value);
          else if (prefix == 'b:hi') optionsHi.add(value);
          else if (prefix == 'c:hi') optionsHi.add(value);
          else if (prefix == 'd:hi') optionsHi.add(value);
          else if (prefix == 'exp:hi') expHi = value;
          continue;
        }

        if (l.toLowerCase().startsWith('q:bn') ||
            l.toLowerCase().startsWith('a:bn') ||
            l.toLowerCase().startsWith('b:bn') ||
            l.toLowerCase().startsWith('c:bn') ||
            l.toLowerCase().startsWith('d:bn') ||
            l.toLowerCase().startsWith('exp:bn')) {
          final colonIndex = l.indexOf(':');
          final prefix = l.substring(0, colonIndex + 3).toLowerCase();
          final value = l.substring(colonIndex + 3).trim();

          if (prefix == 'q:bn') questionBn = value;
          else if (prefix == 'a:bn') optionsBn.add(value);
          else if (prefix == 'b:bn') optionsBn.add(value);
          else if (prefix == 'c:bn') optionsBn.add(value);
          else if (prefix == 'd:bn') optionsBn.add(value);
          else if (prefix == 'exp:bn') expBn = value;
          continue;
        }

        final lower = l.toLowerCase();
        final colonIndex = l.indexOf(':');
        final prefix = colonIndex >= 0 ? lower.substring(0, colonIndex + 1) : '';
        final value = colonIndex >= 0 ? l.substring(colonIndex + 1).trim() : l;

        if (prefix == 'q:' || prefix == 'q') {
          questionEn ??= value;
          questionHi ??= value;
          questionBn ??= value;
        } else if (prefix == 'a:') {
          optionsEn.add(value);
        } else if (prefix == 'b:') {
          optionsEn.add(value);
        } else if (prefix == 'c:') {
          optionsEn.add(value);
        } else if (prefix == 'd:') {
          optionsEn.add(value);
        } else if (prefix == 'exp:') {
          expEn ??= value;
        } else if (lower.startsWith('cat:') || lower.startsWith('category:')) {
          category = value;
        } else if (lower.startsWith('diff:')) {
          diff = value.toLowerCase();
        } else if (lower.startsWith('ans:') || lower.startsWith('answer:')) {
          final ans = value.toUpperCase();
          if (ans == 'A' || ans == '1') correctIndex = 0;
          else if (ans == 'B' || ans == '2') correctIndex = 1;
          else if (ans == 'C' || ans == '3') correctIndex = 2;
          else if (ans == 'D' || ans == '4') correctIndex = 3;
        }
      }

      if (questionEn == null && questionHi == null && questionBn == null) continue;
      if (optionsEn.length < 4) continue;

      final finalOptionsEn = optionsEn.length >= 4 ? optionsEn : <String>[];
      final finalOptionsHi = optionsHi.length >= 4 ? optionsHi : optionsEn;
      final finalOptionsBn = optionsBn.length >= 4 ? optionsBn : optionsEn;

      questions.add(QuestionModel(
        id: 'q_${DateTime.now().millisecondsSinceEpoch}_$i',
        text: {
          'en': questionEn ?? questionHi ?? questionBn ?? '',
          'hi': questionHi ?? questionEn ?? '',
          'bn': questionBn ?? questionEn ?? '',
        },
        options: {
          'en': finalOptionsEn,
          'hi': finalOptionsHi,
          'bn': finalOptionsBn,
        },
        correctIndex: correctIndex.clamp(0, 3),
        explanation: {
          'en': expEn ?? '',
          'hi': expHi ?? expEn ?? '',
          'bn': expBn ?? expEn ?? '',
        },
        category: category ?? 'General Knowledge',
        difficulty: diff,
        examTags: [widget.selectedExamMode],
        order: questions.length,
      ));
    }
    return questions;
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    StringBuffer sb = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(char);
      }
    }
    result.add(sb.toString().trim());
    return result;
  }

  List<String> _findDuplicates(List<QuestionModel> newQuestions) {
    final dupes = <String>[];
    // Find internal duplicates within the pasted list
    final seenText = <String>{};
    for (final q in newQuestions) {
      final englishText = q.text['en']?.toLowerCase().trim() ?? '';
      if (seenText.contains(englishText)) {
        dupes.add(q.text['en'] ?? '');
      } else {
        seenText.add(englishText);
      }
    }
    return dupes;
  }

  Future<bool?> _showDuplicateWarningDialog(List<String> dupes) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplicate Questions Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('We found ${dupes.length} potential duplicate questions in your list:'),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              width: double.maxFinite,
              child: ListView.builder(
                itemCount: dupes.length,
                itemBuilder: (_, idx) => Text(
                  '- ${dupes[idx]}',
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Do you still want to upload them?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Upload Anyway'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
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
                        value: widget.selectedExamMode,
                        isExpanded: true,
                        dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.bold,
                        ),
                        items: _examModes
                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) => widget.onExamModeChanged(v!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildQuizTypeChip('Daily Quiz', true),
                      _buildQuizTypeChip('Practice', false),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildGuideCard(context, isDark),
            const SizedBox(height: 12),
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: TextField(
                controller: _bulkQuestionsController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Paste JSON list, CSV, or plain text questions here...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _uploadBulkQuestions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(
                  widget.isDailyQuiz ? 'Upload to Daily Quiz' : 'Upload to Practice',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizTypeChip(String label, bool isDaily) {
    final selected = isDaily == widget.isDailyQuiz;
    return GestureDetector(
      onTap: () => widget.onQuizTypeChanged(isDaily),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade600),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCard(BuildContext context, bool isDark) {
    final fgColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 20),
            title: Text(
              'AI Prompt & Question Format Guide',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: fgColor,
              ),
            ),
            trailing: Icon(
              _showGuide ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: fgColor.withValues(alpha: 0.6),
            ),
            onTap: () => setState(() => _showGuide = !_showGuide),
          ),
          if (_showGuide) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'To get perfectly translated questions in English, Hindi, and Bengali, copy the prompt below and paste it in ChatGPT, Claude, or Gemini:',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.psychology_rounded, size: 16, color: Colors.purple),
                            const SizedBox(width: 8),
                            Text(
                              'AI System Prompt Template',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: fgColor.withValues(alpha: 0.7),
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(const ClipboardData(text: _aiPromptText));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('AI Prompt copied to clipboard!'),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: const Row(
                                children: [
                                  Icon(Icons.copy_rounded, size: 12, color: AppColors.primary),
                                  SizedBox(width: 4),
                                  Text(
                                    'Copy',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Act as a professional GK Quiz developer. Generate 10 high-quality questions for GK Quiz App in Indian context. Output strictly as a JSON list matching this format...',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '⚠️ Crucial Checkpoints:\n'
                    '• Ensure correctIndex matches correct options in all three languages.\n'
                    '• The tags will automatically default to the selected exam mode.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
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

  static const String _aiPromptText = '''
Act as a professional GK Quiz developer. Generate 10 high-quality questions for GK Quiz App in Indian context.
You must provide the output strictly as a JSON list matching this structure:

[
  {
    "text": {
      "en": "English question text here",
      "hi": "Hindi translation of the question",
      "bn": "Bengali translation of the question"
    },
    "options": {
      "en": ["Option A", "Option B", "Option C", "Option D"],
      "hi": ["विकल्प A", "विकल्प B", "विकल्प C", "विकल्प D"],
      "bn": ["অপশন A", "অপশন B", "অপশন C", "অপশন D"]
    },
    "correctIndex": 1, // 0-indexed correct option (0=A, 1=B, 2=C, 3=D) across all translation options lists
    "explanation": {
      "en": "English explanation here",
      "hi": "Hindi translation of the explanation",
      "bn": "Bengali translation of the explanation"
    },
    "category": "General Knowledge", // Must match: General Knowledge, Indian History, Geography, Science, Polity, Economy, Current Affairs, Art & Culture
    "difficulty": "medium", // easy, medium, hard
    "order": 0
  }
]

Make sure:
1. Options order is exactly aligned across all languages (e.g. Option B in English matches Option B in Hindi/Bengali).
2. Output ONLY the raw JSON list, no extra markdown or introduction text.
''';
}
