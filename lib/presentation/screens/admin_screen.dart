// lib/presentation/screens/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/question_service.dart';
import '../../core/services/admin_service.dart';
import '../../core/services/quiz_scheduler_service.dart';
import '../../data/models/firestore_models.dart';

enum AdminFlowStep { email, password, dashboard }

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _bulkQuestionsController = TextEditingController();

  AdminFlowStep _currentStep = AdminFlowStep.email;
  String? _errorMessage;
  bool _isLoading = false;

  String _selectedExamMode = 'GENERAL';
  bool _isQuizMode = true;
  bool _isDailyQuiz = true;

  // Quiz timing configuration
  int _quizStartHour = 6;
  int _quizStartMinute = 0;
  int _quizEndHour = 23;
  int _quizEndMinute = 45;

  final List<String> _examModes = ['GENERAL', 'WBPSC', 'SSC', 'UPSC', 'BANK'];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _bulkQuestionsController.dispose();
    super.dispose();
  }

  Future<void> _verifyEmail() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter email');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isValid = await AdminService.instance.verifyEmailOnly(
      _emailController.text.trim(),
    );

    if (!mounted) return;

    if (isValid) {
      setState(() {
        _currentStep = AdminFlowStep.password;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = 'Invalid admin email';
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyPassword() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await AdminService.instance
          .verifyAdmin(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (result) {
        setState(() {
          _currentStep = AdminFlowStep.dashboard;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = AdminService.instance.lastError ?? 'Invalid password';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _logout() {
    AdminService.instance.logout();
    Navigator.pushReplacementNamed(context, '/');
  }

  Future<void> _uploadBulkQuestions() async {
    final input = _bulkQuestionsController.text.trim();
    if (input.isEmpty) {
      _showSnackBar('Please paste questions', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final questions = _parseBulkQuestions(input);
      if (questions.isEmpty) {
        _showSnackBar('No valid questions found. Check format!', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      if (_isDailyQuiz) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        await QuestionService.instance.uploadQuestions(
          examMode: _selectedExamMode,
          questions: questions,
          date: today,
        );
        _showSnackBar('${questions.length} questions added to $today quiz!');
      } else {
        await QuestionService.instance.uploadPracticeQuestions(
          examMode: _selectedExamMode,
          questions: questions,
        );
        _showSnackBar('${questions.length} questions added to practice!');
      }

      _bulkQuestionsController.clear();
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<QuestionModel> _parseBulkQuestions(String input) {
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

        // Check for language-specific prefixes FIRST (more specific patterns)
        if (l.toLowerCase().startsWith('q:en') ||
            l.toLowerCase().startsWith('a:en') ||
            l.toLowerCase().startsWith('b:en') ||
            l.toLowerCase().startsWith('c:en') ||
            l.toLowerCase().startsWith('d:en') ||
            l.toLowerCase().startsWith('exp:en')) {
          // Handle English-specific (q:en, a:en, etc.) - extract full prefix
          final colonIndex = l.indexOf(':');
          // For "A:en Lion", colonIndex=1, need to get "a:en" which is 4 chars
          final prefix = l.substring(0, colonIndex + 3).toLowerCase();
          final value = l.substring(colonIndex + 3).trim();

          if (prefix == 'q:en')
            questionEn = value;
          else if (prefix == 'a:en')
            optionsEn.add(value);
          else if (prefix == 'b:en')
            optionsEn.add(value);
          else if (prefix == 'c:en')
            optionsEn.add(value);
          else if (prefix == 'd:en')
            optionsEn.add(value);
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

          if (prefix == 'q:hi')
            questionHi = value;
          else if (prefix == 'a:hi')
            optionsHi.add(value);
          else if (prefix == 'b:hi')
            optionsHi.add(value);
          else if (prefix == 'c:hi')
            optionsHi.add(value);
          else if (prefix == 'd:hi')
            optionsHi.add(value);
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

          if (prefix == 'q:bn')
            questionBn = value;
          else if (prefix == 'a:bn')
            optionsBn.add(value);
          else if (prefix == 'b:bn')
            optionsBn.add(value);
          else if (prefix == 'c:bn')
            optionsBn.add(value);
          else if (prefix == 'd:bn')
            optionsBn.add(value);
          else if (prefix == 'exp:bn') expBn = value;
          continue;
        }

        // Now handle general prefixes (without language code)
        final lower = l.toLowerCase();
        final colonIndex = l.indexOf(':');
        final prefix =
            colonIndex >= 0 ? lower.substring(0, colonIndex + 1) : '';
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
          if (ans == 'A' || ans == '1') {
            correctIndex = 0;
          } else if (ans == 'B' || ans == '2') {
            correctIndex = 1;
          } else if (ans == 'C' || ans == '3') {
            correctIndex = 2;
          } else if (ans == 'D' || ans == '4') {
            correctIndex = 3;
          }
        }
      }

      if (questionEn == null && questionHi == null && questionBn == null) {
        continue;
      }
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
        category: category ?? 'general',
        difficulty: diff,
        examTags: [_selectedExamMode],
        order: questions.length,
      ));
    }
    return questions;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showFormatHelp() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 550, maxHeight: 650),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.help_outline, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Text('Question Format Guide',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _formatSection(
                          'FORMAT 1: Simple (English Only)',
                          '''
Q: What is the capital of India?
A: Mumbai
B: New Delhi
C: Kolkata
D: Chennai
ANS: B

Q: What is 2+2?
A: 3
B: 4
C: 5
D: 6
ANS: B
DIFF: easy''',
                          Colors.green),
                      _formatSection(
                          'FORMAT: Multi-Language with All Details',
                          '''
Q:en Which is the largest planet?
Q:hi हमारे सौर मंडल का सबसे बड़ा ग्रह कौन सा है?
Q:bn আমাদের সৌরজগতের সবচেয়ে বড় গ্রহ কোনটি?
A:en Earth
B:en Mars
C:en Jupiter
D:en Venus
A:hi पृथ्वी
B:hi मंगल
C:hi बृहस्पति
D:hi शुक্র
A:bn পৃথিবী
B:bn মঙ্গল
C:bn বৃহস্পতি
D:bn শুক্র
ANS: C
CAT: Science
DIFF: easy
EXP:en Jupiter is the largest planet.
EXP:hi बृहस्पति सबसे बड़ा ग्रह है।
EXP:bn বৃহস্পতি সবচেয়ে বড় গ্রহ।''',
                          Colors.blue),
                      _formatSection(
                          'FORMAT 3: With Category',
                          '''
Q: What is the capital of India?
A: Mumbai
B: New Delhi
C: Kolkata
D: Chennai
ANS: B
CAT: Geography
DIFF: easy''',
                          Colors.orange),
                      _formatSection(
                          'FORMAT 4: With Explanation',
                          '''
Q: What is the capital of India?
A: Mumbai
B: New Delhi
C: Kolkata
D: Chennai
ANS: B
EXP: New Delhi is the capital of India.
EXP:hi नई दिल्ली भारत की राजधानी है।''',
                          Colors.teal),
                      const SizedBox(height: 12),
                      const Text('FIELDS:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const Text('Q: or Q:en  - Question (English)'),
                      const Text('Q:hi          - Question in Hindi'),
                      const Text('Q:bn          - Question in Bengali'),
                      const Text('A: B: C: D: - Options (English)'),
                      const Text('A:hi B:hi    - Options in Hindi'),
                      const Text('A:bn B:bn    - Options in Bengali'),
                      const Text('ANS:         - Answer (A/B/C/D or 1/2/3/4)'),
                      const Text(
                          'DIFF:        - Difficulty (easy/medium/hard)'),
                      const Text('CAT:         - Category (optional)'),
                      const Text('EXP:         - Explanation (all langs)'),
                      const Text('EXP:hi      - Explanation in Hindi'),
                      const Text('EXP:bn      - Explanation in Bengali'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AUTO-GENERATED:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple)),
                            Text('✓ id, order, examTags'),
                            Text('✓ Missing translations use English'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it!'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formatSection(String title, String example, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 8),
          SelectableText(example,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text(
          _getTitle(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: _currentStep == AdminFlowStep.dashboard
            ? [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: TextButton.icon(
                    onPressed: _logout,
                    icon:
                        const Icon(Icons.logout, color: Colors.white, size: 20),
                    label: const Text('Logout',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: _buildBody(),
    );
  }

  String _getTitle() {
    switch (_currentStep) {
      case AdminFlowStep.email:
        return 'Admin Login';
      case AdminFlowStep.password:
        return 'Enter Password';
      case AdminFlowStep.dashboard:
        return 'Admin Dashboard';
    }
  }

  Widget _buildBody() {
    switch (_currentStep) {
      case AdminFlowStep.email:
        return _buildEmailScreen();
      case AdminFlowStep.password:
        return _buildPasswordScreen();
      case AdminFlowStep.dashboard:
        return _buildDashboard();
    }
  }

  Widget _buildEmailScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: 0.2),
                    const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.admin_panel_settings,
                  size: 64, color: Color(0xFF6366F1)),
            ),
            const SizedBox(height: 32),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ).createShader(bounds),
              child: const Text('Admin Access',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
            const SizedBox(height: 8),
            Text('Enter your admin email',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
            const SizedBox(height: 32),
            Container(
              width: 340,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Admin Email',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  prefixIcon: Icon(Icons.email_outlined,
                      color: const Color(0xFF6366F1).withValues(alpha: 0.7)),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: 340,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Continue',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: 0.2),
                    const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.lock, size: 64, color: Color(0xFF6366F1)),
            ),
            const SizedBox(height: 32),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ).createShader(bounds),
              child: const Text('Welcome Back',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
            const SizedBox(height: 8),
            Text(_emailController.text,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
            const SizedBox(height: 8),
            Text('Enter your password',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
            const SizedBox(height: 32),
            Container(
              width: 340,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: TextField(
                controller: _passwordController,
                obscureText: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  prefixIcon: Icon(Icons.lock,
                      color: const Color(0xFF6366F1).withValues(alpha: 0.7)),
                ),
                onSubmitted: (_) => _verifyPassword(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: 340,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Login',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() {
                _currentStep = AdminFlowStep.email;
                _errorMessage = null;
              }),
              child: const Text('Change Email'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF1A1A2E), const Color(0xFF0F0F1A)]
              : [Colors.white, const Color(0xFFF5F5F7)],
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.quiz,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                _isQuizMode ? 'Add Questions' : 'Quiz Settings',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            const SizedBox(height: 4),
                            Text(
                                _isQuizMode
                                    ? 'Upload quiz questions to database'
                                    : 'Configure quiz timing',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white70)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildModeChip('Add Questions', true),
                      const SizedBox(width: 8),
                      _buildModeChip('Quiz Settings', false),
                    ],
                  ),
                ],
              ),
            ),
            if (_isQuizMode)
              _buildQuestionUploadSection()
            else
              _buildQuizTimingSettings(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionUploadSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedExamMode,
                      isExpanded: true,
                      dropdownColor:
                          isDark ? const Color(0xFF1A1A2E) : Colors.white,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      items: _examModes
                          .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedExamMode = v!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  ),
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Color(0xFF6366F1)),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Click "Format" for help with languages, categories and difficulty')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 250,
            decoration: BoxDecoration(
              color:
                  isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              ),
            ),
            child: TextField(
              controller: _bulkQuestionsController,
              maxLines: null,
              expands: false,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                hintText: _getExampleInput(),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _uploadBulkQuestions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.cloud_upload, size: 20),
                label: Text(
                  _isDailyQuiz ? 'Upload to Daily Quiz' : 'Upload to Practice',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizTypeChip(String label, bool isDaily) {
    final selected = isDaily == _isDailyQuiz;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _isDailyQuiz = isDaily),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : (dark ? Colors.grey.shade400 : Colors.grey.shade600),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildModeChip(String label, bool isQuizMode) {
    final selected = isQuizMode == _isQuizMode;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _isQuizMode = isQuizMode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : (dark ? Colors.grey.shade400 : Colors.grey.shade600),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildQuizTimingSettings() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: const Color(0xFF6366F1)),
              const SizedBox(width: 8),
              const Text('Quiz Timing Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quiz Start Time',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<int>(
                            value: _quizStartHour,
                            dropdownColor:
                                isDark ? const Color(0xFF1E1E2E) : Colors.white,
                            underline: const SizedBox(),
                            items: List.generate(24, (i) => i)
                                .map((h) => DropdownMenuItem(
                                    value: h, child: Text('$h')))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _quizStartHour = v!),
                          ),
                        ),
                        const Text(' : '),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<int>(
                            value: _quizStartMinute,
                            dropdownColor:
                                isDark ? const Color(0xFF1E1E2E) : Colors.white,
                            underline: const SizedBox(),
                            items: [0, 15, 30, 45]
                                .map((m) => DropdownMenuItem(
                                    value: m, child: Text('$m')))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _quizStartMinute = v!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quiz End Time',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<int>(
                            value: _quizEndHour,
                            dropdownColor:
                                isDark ? const Color(0xFF1E1E2E) : Colors.white,
                            underline: const SizedBox(),
                            items: List.generate(24, (i) => i)
                                .map((h) => DropdownMenuItem(
                                    value: h, child: Text('$h')))
                                .toList(),
                            onChanged: (v) => setState(() => _quizEndHour = v!),
                          ),
                        ),
                        const Text(' : '),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<int>(
                            value: _quizEndMinute,
                            dropdownColor:
                                isDark ? const Color(0xFF1E1E2E) : Colors.white,
                            underline: const SizedBox(),
                            items: [0, 15, 30, 45]
                                .map((m) => DropdownMenuItem(
                                    value: m, child: Text('$m')))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _quizEndMinute = v!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveQuizTimingConfig,
              icon: const Icon(Icons.save),
              label: const Text('Save Timing Configuration'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
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
      _showSnackBar('Quiz timing configuration saved!');
    } catch (e) {
      _showSnackBar('Error saving: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getExampleInput() {
    return '''Q: What is the capital of India?
A: Mumbai
B: New Delhi
C: Kolkata
D: Chennai
ANS: B
DIFF: easy

Q:en What is the capital of India?
Q:hi भारत की राजधानी क्या है?
Q:bn ভারতের রাজধানী কোনটি?
A: Mumbai
B: New Delhi
C: Kolkata
D: Chennai
ANS: B''';
  }
}
