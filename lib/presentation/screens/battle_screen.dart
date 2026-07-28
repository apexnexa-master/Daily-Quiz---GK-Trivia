// lib/presentation/screens/battle_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_animations.dart';
import '../../data/models/firestore_models.dart';
import '../../data/local_quiz_data.dart';
import '../../core/services/battle_service.dart';

enum BattleArenaState {
  selectMode,
  searchingOffline,
  lobbyWaiting,
  joinRoom,
  battleActive,
}

class BattleScreen extends ConsumerStatefulWidget {
  final String? roomId;
  const BattleScreen({super.key, this.roomId});

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen> {
  // Screen States
  BattleArenaState _arenaState = BattleArenaState.selectMode;
  bool _isOnlineMode = false;

  // Room / Match Info
  String? _roomId;
  StreamSubscription? _roomSubscription;
  List<QuestionModel> _questions = [];
  int _currentQuestion = 0;
  int _totalQuestions = 5;
  int? _selectedAnswer;
  bool _isAnswered = false;

  // Player Scores / Progress
  int _playerScore = 0;
  int _opponentScore = 0;
  String _opponentName = 'Training Bot';
  String _opponentAvatar = '';
  int _opponentCurrentQuestion = 0;
  bool _opponentFinished = false;

  // Timers
  Timer? _searchTimer;
  Timer? _opponentSimTimer;

  // Controllers
  final TextEditingController _codeController = TextEditingController();
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    if (widget.roomId != null) {
      Future.microtask(() async {
        final user = await ref.read(currentUserProvider.future);
        final lang = ref.read(languageProvider);
        if (user != null && !user.isAnonymous && mounted) {
          setState(() {
            _codeController.text = widget.roomId!;
            _isJoining = true;
          });
          _submitRoomCode(user);
        } else if (mounted) {
          _showLobbyAuthRequiredDialog(lang);
        }
      });
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _searchTimer?.cancel();
    _opponentSimTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  // --- Actions & Handlers ---

  void _startOfflineMode() {
    setState(() {
      _arenaState = BattleArenaState.searchingOffline;
      _isOnlineMode = false;
      _playerScore = 0;
      _opponentScore = 0;
      _opponentName = 'Training Bot';
      _currentQuestion = 0;
      _selectedAnswer = null;
      _isAnswered = false;
    });

    _searchTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _arenaState = BattleArenaState.battleActive;
          _questions = LocalQuizData.getAllQuestionsForMode('GENERAL');
          _questions.shuffle();
          _questions = _questions.take(5).toList();
          _totalQuestions = _questions.length;
        });
        _startOfflineOpponentSimulation();
      }
    });
  }

  void _startOfflineOpponentSimulation() {
    _opponentSimTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _arenaState == BattleArenaState.battleActive && !_isAnswered) {
        setState(() {
          _opponentScore += Random().nextInt(2);
          _opponentCurrentQuestion = min(_currentQuestion + 1, _totalQuestions - 1);
        });
      }
    });
  }

  Future<void> _createOnlineRoom(UserModel? user) async {
    if (user == null) return;
    setState(() {
      _arenaState = BattleArenaState.lobbyWaiting;
      _isOnlineMode = true;
      _playerScore = 0;
      _opponentScore = 0;
      _currentQuestion = 0;
      _selectedAnswer = null;
      _isAnswered = false;
    });

    try {
      final roomId = await BattleService().createRoom(
        playerNickname: user.displayName,
        playerId: user.uid,
        avatarUrl: user.photoUrl ?? '',
      );

      setState(() {
        _roomId = roomId;
      });

      _subscribeToRoom(roomId, user.uid);
    } catch (e, stack) {
      debugPrint('Error creating room: $e\n$stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create battle room: $e')),
      );
      setState(() {
        _arenaState = BattleArenaState.selectMode;
      });
    }
  }

  void _joinOnlineRoom(UserModel? user) {
    if (user == null) return;
    setState(() {
      _arenaState = BattleArenaState.joinRoom;
      _codeController.clear();
    });
  }

  Future<void> _submitRoomCode(UserModel? user) async {
    final code = _codeController.text.trim();
    if (code.length != 6) return;

    setState(() {
      _isJoining = true;
    });

    try {
      final success = await BattleService().joinRoom(
        roomId: code,
        playerNickname: user?.displayName ?? 'Challenger',
        playerId: user?.uid ?? 'guest_uid',
        avatarUrl: user?.photoUrl ?? '',
      );

      if (success) {
        setState(() {
          _roomId = code;
          _isOnlineMode = true;
          _playerScore = 0;
          _opponentScore = 0;
          _currentQuestion = 0;
          _selectedAnswer = null;
          _isAnswered = false;
          _arenaState = BattleArenaState.battleActive;
          _isJoining = false;
        });

        _subscribeToRoom(code, user?.uid ?? 'guest_uid');
      } else {
        setState(() {
          _isJoining = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid room code or room is full.')),
        );
      }
    } catch (e, stack) {
      debugPrint('Error joining room: $e\n$stack');
      setState(() {
        _isJoining = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining room: $e')),
      );
    }
  }

  void _subscribeToRoom(String roomId, String myUid) {
    _roomSubscription?.cancel();
    _roomSubscription = BattleService().watchRoom(roomId).listen((snapshot) {
      if (!snapshot.exists || !mounted) return;

      final data = snapshot.data();
      if (data == null) return;

      final status = data['status'];
      final players = Map<String, dynamic>.from(data['players'] ?? {});

      // Parse opponent info
      String? oppId;
      players.forEach((key, val) {
        if (key != myUid) {
          oppId = key;
        }
      });

      if (oppId != null) {
        final oppData = players[oppId];
        setState(() {
          _opponentName = oppData['name'] ?? 'Opponent';
          _opponentAvatar = oppData['avatar'] ?? '';
          _opponentScore = oppData['score'] ?? 0;
          _opponentCurrentQuestion = oppData['currentQuestion'] ?? 0;
          _opponentFinished = oppData['isFinished'] ?? false;
        });
      }

      // If status transitions to playing
      if (status == 'playing' && _arenaState == BattleArenaState.lobbyWaiting) {
        // Parse questions from room
        final list = List<dynamic>.from(data['questions'] ?? []);
        setState(() {
          _questions = list.map((q) => QuestionModel.fromMap(Map<String, dynamic>.from(q))).toList();
          _totalQuestions = _questions.length;
          _arenaState = BattleArenaState.battleActive;
        });
      }

      // If status transitions to finished, or opponent scores exceed
      if (status == 'finished') {
        _endBattle();
      }
    });
  }

  void _onAnswerSelected(int index) {
    if (_isAnswered) return;

    setState(() {
      _selectedAnswer = index;
      _isAnswered = true;
    });

    final isCorrect = _selectedAnswer == _questions[_currentQuestion].correctIndex;
    if (isCorrect) {
      setState(() {
        _playerScore += 1;
      });
      ref.read(gamificationNotifierProvider.notifier).addXP(20);
    }

    if (_isOnlineMode) {
      final user = ref.read(currentUserProvider).value;
      if (user != null && _roomId != null) {
        final isFinished = _currentQuestion >= _totalQuestions - 1;
        BattleService().updateProgress(
          roomId: _roomId!,
          playerId: user.uid,
          score: _playerScore,
          currentQuestion: _currentQuestion,
          isFinished: isFinished,
        );
      }
    }

    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        if (_currentQuestion < _totalQuestions - 1) {
          setState(() {
            _currentQuestion++;
            _selectedAnswer = null;
            _isAnswered = false;
          });
        } else {
          if (!_isOnlineMode) {
            _endBattle();
          } else {
            // Online: Wait for opponent to finish
            if (_opponentFinished) {
              _endBattle();
            } else {
              // Show waiting screen overlay
              setState(() {
                _isAnswered = true; // Lock UI
              });
            }
          }
        }
      }
    });
  }

  void _endBattle() {
    _opponentSimTimer?.cancel();
    _roomSubscription?.cancel();
    if (mounted) {
      _showResultDialog();
    }
  }

  void _leaveRoom() {
    if (_roomId != null) {
      BattleService().deleteRoom(_roomId!);
    }
    _roomSubscription?.cancel();
    setState(() {
      _arenaState = BattleArenaState.selectMode;
      _roomId = null;
    });
  }

  // --- Share Invite link ---
  void _shareCode(String code, bool isBn, bool isHi) {
    final link = 'https://dailyquiz.nexasoft.com/challenge/$code';
    final message = isBn
        ? 'আমার সাথে কুইজ চ্যালেঞ্জ খেলুন! জয়েন করতে এই লিঙ্কে ক্লিক করুন: $link\n(অথবা রুম কোড ব্যবহার করুন: $code)'
        : isHi
            ? 'मेरे साथ लाइव क्विज़ चुनौती खेलें! शामिल होने के लिए इस लिंक पर क्लिक करें: $link\n(या रूम कोड का उपयोग करें: $code)'
            : 'Play a 1v1 Live Quiz Battle with me! Click here to join: $link\n(Or use room code: $code)';
    
    Share.share(message);
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(languageProvider);
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.homeBackdropDark : AppColors.homeBackdropGradient,
        ),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildStateView(isDark, isBn, isHi, user),
          ),
        ),
      ),
    );
  }

  Widget _buildStateView(bool isDark, bool isBn, bool isHi, UserModel? user) {
    switch (_arenaState) {
      case BattleArenaState.selectMode:
        return _buildSelectModeView(isDark, isBn, isHi, user);
      case BattleArenaState.searchingOffline:
        return _buildSearchingState(isDark, isBn, isHi);
      case BattleArenaState.lobbyWaiting:
        return _buildLobbyWaitingView(isDark, isBn, isHi);
      case BattleArenaState.joinRoom:
        return _buildJoinRoomView(isDark, isBn, isHi, user);
      case BattleArenaState.battleActive:
        return _buildBattleState(isDark, isBn, isHi, user);
    }
  }

  // 1. Selector Mode Screen
  Widget _buildSelectModeView(bool isDark, bool isBn, bool isHi, UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppSpacing.paddingCardCondensed,
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back_rounded,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight),
              ),
              const SizedBox(width: 4),
              Text(
                isBn ? 'কুইজ যুদ্ধ' : isHi ? 'क्विज़ युद्ध' : 'Quiz Battle Arena',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  AppIcons.battle,
                  size: 80,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  isBn
                      ? 'যুদ্ধ ক্ষেত্র চয়ন করুন'
                      : isHi
                          ? 'युद्ध क्षेत्र चुनें'
                          : 'Select Your Battleground',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 32),

                // Offline Training mode
                _buildModeCard(
                  title: isBn ? 'বট প্রশিক্ষণ' : isHi ? 'बॉट प्रशिक्षण' : 'AI Bot Training',
                  subtitle: isBn
                      ? 'একটি সিমুলেটেড কুইজ বটে আপনার গতি ও দক্ষতা পরীক্ষা করুন।'
                      : isHi
                          ? 'एक सिम्युलेटेड क्विज़ बॉट में अपनी गति का परीक्षण करें।'
                          : 'Test your speed and precision against a training bot offline.',
                  gradient: AppColors.primaryGradient,
                  icon: Icons.psychology_rounded,
                  onTap: _startOfflineMode,
                  isDark: isDark,
                ),

                const SizedBox(height: 20),

                // Online 1v1 Mode
                _buildModeCard(
                  title: isBn ? 'অনলাইন ১ বনাম ১ কুইজ' : isHi ? 'ऑनलाइन 1 बनाम 1 क्विज़' : 'Online 1v1 Duel',
                  subtitle: isBn
                      ? 'রুম কোড শেয়ার করে সরাসরি বন্ধুর সাথে লাইভ লড়াইয়ে নামুন!'
                      : isHi
                          ? 'रूम कोड साझा करें और अपने दोस्त के साथ सीधे खेलें!'
                          : 'Create a room, share the code, and duel your friend in real-time!',
                  gradient: AppColors.successGradient,
                  icon: Icons.people_rounded,
                  onTap: () {
                    if (user?.isAnonymous ?? true) {
                      _showAnonymousWarning(isBn, isHi);
                    } else {
                      _showOnlineLobbyChoiceDialog(isDark, isBn, isHi, user);
                    }
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAnonymousWarning(bool isBn, bool isHi) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isBn ? 'লগইন প্রয়োজন' : isHi ? 'लॉगिन आवश्यक' : 'Sign In Required'),
        content: Text(
          isBn
              ? 'অনলাইন ১ বনাম ১ ম্যাচ খেলতে আপনাকে গুগল অ্যাকাউন্ট লিংক করতে হবে।'
              : isHi
                  ? 'ऑनलाइन 1 बनाम 1 खेलने के लिए आपको Google अकाउंट लिंक करना होगा।'
                  : 'You must link your Google account to host or join online matches.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isBn ? 'বন্ধ করুন' : isHi ? 'बंद करें' : 'Close'),
          ),
        ],
      ),
    );
  }

  void _showOnlineLobbyChoiceDialog(bool isDark, bool isBn, bool isHi, UserModel? user) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        title: Text(
          isBn ? '১ বনাম ১ দ্বৈরথ' : isHi ? '1 बनाम 1 द्वंद्व' : '1v1 Online Duel',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _createOnlineRoom(user);
            },
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  isBn ? 'রুম তৈরি করুন' : isHi ? 'रूम बनाएं' : 'Create Custom Room',
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                ),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _joinOnlineRoom(user);
            },
            child: Row(
              children: [
                const Icon(Icons.vpn_key_outlined, color: AppColors.success),
                const SizedBox(width: 12),
                Text(
                  isBn ? 'কোড দিয়ে জয়েন করুন' : isHi ? 'कोड के साथ जुड़ें' : 'Join with Code',
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white30 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  // 2. Searching Screen (Offline mode)
  Widget _buildSearchingState(bool isDark, bool isBn, bool isHi) {
    return Column(
      children: [
        Padding(
          padding: AppSpacing.paddingCardCondensed,
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  _searchTimer?.cancel();
                  setState(() {
                    _arenaState = BattleArenaState.selectMode;
                  });
                },
                icon: Icon(Icons.arrow_back_rounded,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight),
              ),
              const SizedBox(width: 4),
              Text(
                isBn ? 'বট অনুসন্ধান' : isHi ? 'बॉट खोज' : 'Opponent Search',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    strokeWidth: 4.5,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  isBn ? 'ট্রেনিং বটের সাথে যুক্ত হচ্ছে...' : isHi ? 'ट्रेनिंग बॉट से कनेक्ट हो रहा है...' : 'Connecting with Training Bot...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isBn ? 'অনুগ্রহ করে অপেক্ষা করুন।' : isHi ? 'कृपया प्रतीक्षा करें।' : 'Please wait while match is generated.',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey[500],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 3. Online Lobby Screen
  Widget _buildLobbyWaitingView(bool isDark, bool isBn, bool isHi) {
    final user = ref.read(currentUserProvider).value;

    return Column(
      children: [
        Padding(
          padding: AppSpacing.paddingCardCondensed,
          child: Row(
            children: [
              IconButton(
                onPressed: _leaveRoom,
                icon: Icon(Icons.close_rounded,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight),
              ),
              const SizedBox(width: 4),
              Text(
                isBn ? 'যুদ্ধের লবি' : isHi ? 'युद्ध लॉबी' : 'Battle Lobby',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isBn ? 'বন্ধু আমন্ত্রণ কোড' : isHi ? 'मित्र आमंत्रण कोड' : 'Invite Challenge Code',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 10),
                if (_roomId != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _roomId!,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _roomId!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isBn ? 'কোড কপি করা হয়েছে!' : isHi ? 'कोड कॉपी किया गया!' : 'Code copied!'),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _shareCode(_roomId!, isBn, isHi),
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    label: Text(isBn ? 'কোড শেয়ার করুন' : isHi ? 'कोड शेयर करें' : 'Share Room Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ] else ...[
                  const CircularProgressIndicator(),
                ],
                const SizedBox(height: 48),

                // Matchup Slots
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Player Slot
                    _buildLobbyPlayerSlot(
                      name: user?.displayName ?? 'You',
                      avatarUrl: user?.photoUrl ?? '',
                      isDark: isDark,
                      isReady: true,
                    ),
                    const Icon(Icons.bolt_rounded, color: AppColors.warning, size: 40),
                    // Opponent Slot
                    _buildLobbyPlayerSlot(
                      name: isBn ? 'অপেক্ষা করা হচ্ছে...' : isHi ? 'प्रतीक्षा...' : 'Waiting...',
                      avatarUrl: '',
                      isDark: isDark,
                      isReady: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLobbyPlayerSlot({
    required String name,
    required String avatarUrl,
    required bool isDark,
    required bool isReady,
  }) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isReady ? AppColors.success : (isDark ? Colors.white10 : Colors.grey.shade300),
              width: 3,
            ),
            color: isDark ? AppColors.cardDark : Colors.white,
          ),
          child: ClipOval(
            child: avatarUrl.isNotEmpty
                ? Image.network(avatarUrl, fit: BoxFit.cover)
                : Icon(
                    Icons.person_rounded,
                    color: isReady
                        ? AppColors.success
                        : (isDark ? Colors.white30 : Colors.grey.shade400),
                    size: 36,
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }

  // 4. Join Room Screen (Enter 6 digit code)
  Widget _buildJoinRoomView(bool isDark, bool isBn, bool isHi, UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppSpacing.paddingCardCondensed,
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() {
                  _arenaState = BattleArenaState.selectMode;
                }),
                icon: Icon(Icons.arrow_back_rounded,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight),
              ),
              const SizedBox(width: 4),
              Text(
                isBn ? 'কোড প্রবেশ করান' : isHi ? 'कोड दर्ज करें' : 'Enter Room Code',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isBn
                      ? 'খেলায় যোগ দিতে ৬ সংখ্যার চ্যালেঞ্জ রুম কোডটি টাইপ করুন।'
                      : isHi
                          ? 'खेल में शामिल होने के लिए 6 अंकों का चुनौती रूम कोड दर्ज करें।'
                          : 'Enter the 6-digit challenge code to join the live duel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    filled: true,
                    fillColor: isDark ? AppColors.cardDark : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white10 : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isJoining ? null : () => _submitRoomCode(user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isJoining
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            isBn ? 'জয়েন করুন' : isHi ? 'जुड़ें' : 'Join Match',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 5. Active Battle Playback
  Widget _buildBattleState(bool isDark, bool isBn, bool isHi, UserModel? user) {
    if (_questions.isEmpty) return const SizedBox();

    final question = _questions[_currentQuestion];
    final questionText = question.getText(isBn ? 'bn' : isHi ? 'hi' : 'en');
    final options = question.getOptions(isBn ? 'bn' : isHi ? 'hi' : 'en');

    final isWaitingForOpponent = _currentQuestion >= _totalQuestions - 1 && _isAnswered && _isOnlineMode && !_opponentFinished;

    return Column(
      children: [
        // Battle Header Progress Row
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Player Score Slot
              Expanded(
                child: _BattleScoreBar(
                  label: user?.displayName ?? 'You',
                  score: _playerScore,
                  color: AppColors.primary,
                  isDark: isDark,
                  avatarUrl: user?.photoUrl ?? '',
                  currentProgress: '${_currentQuestion + 1}/${_totalQuestions}',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt_rounded, color: AppColors.warning, size: 20),
              ),
              const SizedBox(width: 8),
              // Opponent Score Slot
              Expanded(
                child: _BattleScoreBar(
                  label: _opponentName,
                  score: _opponentScore,
                  color: AppColors.error,
                  isDark: isDark,
                  avatarUrl: _opponentAvatar,
                  currentProgress: '${min(_opponentCurrentQuestion + 1, _totalQuestions)}/${_totalQuestions}',
                ),
              ),
            ],
          ),
        ),

        // Live Question / Wait block
        Expanded(
          child: isWaitingForOpponent
              ? _buildWaitingForOpponentView(isDark, isBn, isHi)
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      // Question text
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDark : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Text(
                          questionText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Options mapping
                      ...List.generate(
                        options.length,
                        (i) => _BattleOptionTile(
                          index: i,
                          text: options[i],
                          isSelected: _selectedAnswer == i,
                          isCorrect: _isAnswered && i == question.correctIndex,
                          isWrong: _isAnswered && _selectedAnswer == i && i != question.correctIndex,
                          isDark: isDark,
                          onTap: _isAnswered ? null : () => _onAnswerSelected(i),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildWaitingForOpponentView(bool isDark, bool isBn, bool isHi) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isBn ? 'প্রতিপক্ষের জন্য অপেক্ষা করা হচ্ছে...' : isHi ? 'प्रतिद्वंद्वी की प्रतीक्षा कर रहा है...' : 'Waiting for opponent...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isBn
                  ? 'আপনি সব প্রশ্নের উত্তর দিয়েছেন! আপনার প্রতিপক্ষ লড়াই শেষ করলে ফলাফল দেখানো হবে।'
                  : isHi
                      ? 'आपने सभी उत्तर दे दिए हैं! जब आपका प्रतिद्वंद्वी समाप्त कर लेगा तब परिणाम दिखाए जाएंगे।'
                      : 'You finished all questions! Results will display as soon as your opponent submits their final answer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResultDialog() {
    final isWin = _playerScore > _opponentScore;
    final isDraw = _playerScore == _opponentScore;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final lang = ref.read(languageProvider);
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isWin ? '🏆' : isDraw ? '🤝' : '💪',
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 16),
            Text(
              isWin
                  ? (isBn ? 'আপনার জয়!' : isHi ? 'आपकी जीत!' : 'Victory!')
                  : isDraw
                      ? (isBn ? 'ড্র হয়েছে!' : isHi ? 'मुकाबला बराबरी का!' : 'Draw!')
                      : (isBn ? 'বটের জয়!' : isHi ? 'बॉट की जीत!' : 'Defeat!'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: isWin
                    ? AppColors.success
                    : isDraw
                        ? AppColors.warning
                        : AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildScoreColumnDialog('You', _playerScore, AppColors.primary),
                Text(
                  'vs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
                _buildScoreColumnDialog(_opponentName, _opponentScore, AppColors.error),
              ],
            ),
            const SizedBox(height: 24),
            if (isWin) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(AppIcons.xp, color: AppColors.xp),
                    const SizedBox(width: 8),
                    Text(
                      '+${_playerScore * 20} XP',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context); // Dialog
                      if (_isOnlineMode && _roomId != null) {
                        BattleService().deleteRoom(_roomId!);
                      }
                      Navigator.pop(context); // Screen
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(isBn ? 'বাহির' : isHi ? 'बाहर' : 'Exit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Dialog
                      if (_isOnlineMode && _roomId != null) {
                        BattleService().deleteRoom(_roomId!);
                      }
                      setState(() {
                        _arenaState = BattleArenaState.selectMode;
                        _roomId = null;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(isBn ? 'আবার খেলুন' : isHi ? 'पुनः खेलें' : 'Rematch'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreColumnDialog(String label, int score, Color color) {
    return Column(
      children: [
        Text(
          label.length > 10 ? '${label.substring(0, 8)}..' : label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Text(
            '$score',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  void _showLobbyAuthRequiredDialog(String lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = lang == 'bn';
    final isHi = lang == 'hi';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Text(
              isBn ? 'লগইন প্রয়োজন' : isHi ? 'लॉगिन आवश्यक' : 'Sign In Required',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
        content: Text(
          isBn
              ? 'অনলাইন ১ বনাম ১ কুইজ লড়াইয়ে যোগ দিতে আপনাকে অবশ্যই গুগল অ্যাকাউন্ট দিয়ে লগইন করতে হবে।'
              : isHi
                  ? 'ऑनलाइन 1 बनाम 1 क्विज़ लड़ाई में शामिल होने के लिए आपको Google अकाउंट से लॉगिन करना होगा।'
                  : 'To join this live 1v1 Quiz Battle, you must sign in with a Google account. Guest accounts are not allowed in online matches.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to Home
            },
            child: Text(
              isBn ? 'বন্ধ করুন' : isHi ? 'बंद करें' : 'Cancel',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushReplacementNamed(context, '/login'); // Go to login
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(
              isBn ? 'লগইন করুন' : isHi ? 'लॉगिन करें' : 'Sign In Now',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// Upgraded battle score header bar showing player photo, score, and current question
class _BattleScoreBar extends StatelessWidget {
  final String label;
  final int score;
  final Color color;
  final bool isDark;
  final String avatarUrl;
  final String currentProgress;

  const _BattleScoreBar({
    required this.label,
    required this.score,
    required this.color,
    required this.isDark,
    required this.avatarUrl,
    required this.currentProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Player Avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: avatarUrl.isNotEmpty
                  ? Image.network(avatarUrl, fit: BoxFit.cover)
                  : Icon(
                      Icons.person_rounded,
                      color: isDark ? Colors.white30 : Colors.grey.shade400,
                      size: 20,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  currentProgress,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$score',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BattleOptionTile extends StatelessWidget {
  final int index;
  final String text;
  final bool isSelected;
  final bool isCorrect;
  final bool isWrong;
  final bool isDark;
  final VoidCallback? onTap;

  const _BattleOptionTile({
    required this.index,
    required this.text,
    required this.isSelected,
    required this.isCorrect,
    required this.isWrong,
    required this.isDark,
    this.onTap,
  });

  static const _labels = ['A', 'B', 'C', 'D'];
  static const _colors = [
    Color(0xFF6366F1),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];

  @override
  Widget build(BuildContext context) {
    Color getColor() {
      if (isCorrect) return AppColors.success;
      if (isWrong) return AppColors.error;
      if (isSelected) return _colors[index % _colors.length];
      return isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected || isCorrect || isWrong
              ? getColor().withValues(alpha: 0.15)
              : (isDark ? AppColors.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected || isCorrect || isWrong
                ? getColor()
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.withValues(alpha: 0.15)),
            width: isSelected || isCorrect || isWrong ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Prefix badge
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isSelected || isCorrect || isWrong
                    ? getColor()
                    : _colors[index % _colors.length].withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _labels[index % _labels.length],
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: isSelected || isCorrect || isWrong
                      ? Colors.white
                      : _colors[index % _colors.length],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ),
            if (isCorrect)
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
            if (isWrong)
              const Icon(Icons.cancel_rounded, color: AppColors.error, size: 20),
          ],
        ),
      ),
    );
  }
}
