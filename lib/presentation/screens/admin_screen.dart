// lib/presentation/screens/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/admin_service.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/admin/admin_upload_tab.dart';
import '../widgets/admin/admin_timing_tab.dart';
import '../widgets/admin/admin_question_list_tab.dart';
import '../../core/services/quiz_scheduler_service.dart';

enum AdminFlowStep { email, password, dashboard }

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  AdminFlowStep _currentStep = AdminFlowStep.email;
  String? _errorMessage;
  bool _isLoading = false;

  String _selectedExamMode = 'GENERAL';
  bool _isDailyQuiz = true;

  @override
  void initState() {
    super.initState();
    if (AdminService.instance.isVerified) {
      _currentStep = AdminFlowStep.dashboard;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
        appBar: AppBar(
          title: Text(
            _getTitle(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          centerTitle: true,
          automaticallyImplyLeading: _currentStep != AdminFlowStep.dashboard,
          elevation: 0,
          backgroundColor: isDark ? AppColors.cardDark : AppColors.primary,
          foregroundColor: Colors.white,
          actions: _currentStep == AdminFlowStep.dashboard
              ? [
                  IconButton(
                    onPressed: _isLoading ? null : _refreshActiveTab,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  ),
                ]
              : null,
          bottom: _currentStep == AdminFlowStep.dashboard
              ? const TabBar(
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  tabs: [
                    Tab(icon: Icon(Icons.cloud_upload_rounded), text: 'Upload'),
                    Tab(icon: Icon(Icons.storage_rounded), text: 'Database'),
                    Tab(icon: Icon(Icons.schedule_rounded), text: 'Timing'),
                  ],
                )
              : null,
        ),
        body: _buildBody(),
      ),
    );
  }

  int _refreshCounter = 0;

  Future<void> _refreshActiveTab() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await QuizSchedulerService.instance.refreshTiming();
      setState(() {
        _refreshCounter++;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Data refreshed successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
        return TabBarView(
          children: [
            AdminUploadTab(
              key: ValueKey('upload_$_refreshCounter'),
              selectedExamMode: _selectedExamMode,
              onExamModeChanged: (val) => setState(() => _selectedExamMode = val),
              isDailyQuiz: _isDailyQuiz,
              onQuizTypeChanged: (val) => setState(() => _isDailyQuiz = val),
            ),
            AdminQuestionListTab(
              key: ValueKey('db_$_refreshCounter'),
              selectedExamMode: _selectedExamMode,
            ),
            AdminTimingTab(
              key: ValueKey('timing_$_refreshCounter'),
            ),
          ],
        );
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
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.admin_panel_settings_rounded,
                  size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: 32),
            Text(
              'Admin Access',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text('Enter your admin email',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
            const SizedBox(height: 32),
            Container(
              width: 340,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
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
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_errorMessage!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: 340,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Continue',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
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
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: 32),
            Text(
              'Welcome Back',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(_emailController.text,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
            const SizedBox(height: 8),
            Text('Enter your password',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
            const SizedBox(height: 32),
            Container(
              width: 340,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
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
                  prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.primary),
                ),
                onSubmitted: (_) => _verifyPassword(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_errorMessage!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: 340,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Login',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
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
}
