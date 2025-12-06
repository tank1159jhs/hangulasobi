import 'package:flutter/material.dart';
import '../../models/korean_data.dart';
import '../../services/data_service.dart';
import '../../services/speech_service.dart';
import '../../widgets/speech_input_widget.dart';
import '../../widgets/pronunciation_guide_dialog.dart';
import 'dart:math';
import 'dart:async';

class BeginnerScreen extends StatefulWidget {
  const BeginnerScreen({super.key});

  @override
  State<BeginnerScreen> createState() => _BeginnerScreenState();
}

class _BeginnerScreenState extends State<BeginnerScreen> with SingleTickerProviderStateMixin {
  // ✅ 싱글톤 서비스 사용
  final DataService _dataService = DataService();
  final SpeechService _speechService = SpeechService();
  
  List<HangulCharacter> _allCharacters = [];
  List<HangulCharacter> _displayedCharacters = [];
  final Set<String> _correctCharacters = {};
  String _inputText = '';
  MatchResult? _lastResult;
  bool _isProcessing = false;
  bool _isSpeechReady = false;
  Timer? _speechCheckTimer;
  
  final Map<String, int> _wrongAnswers = {};
  int _totalAttempts = 0;
  
  late AnimationController _pullAnimationController;
  int? _pulledIndex;
  HangulCharacter? _lastPulledCharacter;
  
  int _selectedDuration = 120;
  int _remainingSeconds = 120;
  Timer? _gameTimer;
  bool _isGameOver = false;
  bool _isGameStarted = false;

  @override
  void initState() {
    super.initState();
    _pullAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _loadData();
    _initSpeech();
  }
  
  Future<void> _initSpeech() async {
    if (!_speechService.isAvailable) {
      await _speechService.initialize();
    }
    
    setState(() {
      _isSpeechReady = _speechService.isAvailable;
    });
    
    _speechCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) return;
      final isAvailable = _speechService.isAvailable;
      if (_isSpeechReady != isAvailable) {
        setState(() {
          _isSpeechReady = isAvailable;
        });
      }
    });
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _speechCheckTimer?.cancel();
    _pullAnimationController.dispose();
    _speechService.stopListening();
    super.dispose();
  }
  
  // ✅ 글자 학습 다이얼로그 표시
  void _showCharacterListDialog() {
    showDialog(
      context: context,
      builder: (context) => _CharacterListDialog(characters: _allCharacters),
    );
  }
  
  // ✅ 게임 시작
  void _startGame() {
    setState(() {
      _isGameStarted = true;
      _remainingSeconds = _selectedDuration;
      _isGameOver = false;
    });
    _startTimer();
  }
  
  // ✅ 타이머 시작
  void _startTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          if (!_isGameOver) {
            _isGameOver = true;
            timer.cancel();
            // 시간 종료 시 결과 화면 표시
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showGameResultDialog();
              }
            });
          }
        }
      });
    });
  }

  Future<void> _loadData() async {
    // 한 글자 문자 로드 (가, 나, 다, 구, 해, 메 등)
    final singleChars = await _dataService.loadSingleCharacters();
    
    setState(() {
      _allCharacters = singleChars;
      _generateNewSet();
    });
  }

  void _generateNewSet() {
    final random = Random();
    final shuffled = List<HangulCharacter>.from(_allCharacters)..shuffle(random);
    setState(() {
      _displayedCharacters = shuffled.take(8).toList();
      _correctCharacters.clear(); // 새 세트 시작 시 초기화
    });
  }

  void _onInputSubmit(String input) {
    if (input.isEmpty || _isGameOver || _isProcessing) return;

    _speechService.stopListening();

    setState(() {
      _isProcessing = true;
    });

    final targets = _displayedCharacters.map((c) => c.pronunciation).toList();
    final matchResult = _speechService.findBestMatch(input, targets);

    if (matchResult != null && matchResult.isNotEmpty) {
      final matchedPronunciation = matchResult.keys.first;
      final result = matchResult.values.first;
      
      final matchedIndex = _displayedCharacters.indexWhere(
        (c) => c.pronunciation == matchedPronunciation,
      );

      if (matchedIndex != -1) {
        if (result == MatchResult.perfect || result == MatchResult.close) {
          setState(() {
            _lastResult = result;
            _pulledIndex = matchedIndex;
            _lastPulledCharacter = _displayedCharacters[matchedIndex];
          });
          
          _pullAnimationController.forward(from: 0).then((_) {
            setState(() {
              _correctCharacters.add(_displayedCharacters[matchedIndex].character);
              _totalAttempts++;
            });
            
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() {
                  _displayedCharacters.removeAt(matchedIndex);
                  _pulledIndex = null;
                  _inputText = '';
                  _lastResult = null;
                  _lastPulledCharacter = null;
                  
                  if (_displayedCharacters.isEmpty) {
                    _generateNewSet();
                  }
                });
                
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    setState(() {
                      _isProcessing = false;
                    });
                  }
                });
              }
            });
          });
        } else {
          final wrongChar = _displayedCharacters[matchedIndex].character;
          _wrongAnswers[wrongChar] = (_wrongAnswers[wrongChar] ?? 0) + 1;
          _totalAttempts++;
          
          setState(() {
            _lastResult = result;
            _inputText = '';
          });
          
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              setState(() {
                _lastResult = null;
                _isProcessing = false;
              });
            }
          });
        }
      }
    } else {
      if (_displayedCharacters.isNotEmpty) {
        final wrongChar = _displayedCharacters.first.character;
        _wrongAnswers[wrongChar] = (_wrongAnswers[wrongChar] ?? 0) + 1;
      }
      
      setState(() {
        _isProcessing = false; // ✅ 처리 완료
      });
      _totalAttempts++;
      
      setState(() {
        _lastResult = MatchResult.wrong;
        _inputText = '';
      });
      // 1초 후 피드백 제거
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _lastResult = null;
          });
        }
      });
    }
  }

  void _showGameResultDialog() {
    // ✅ 틀린 글자 리스트 생성
    final mistakesList = <MapEntry<String, String>>[];
    
    _wrongAnswers.forEach((char, count) {
      mistakesList.add(MapEntry(char, '間違えた: $count回'));
    });

    // 정확도 계산
    final correctCount = _correctCharacters.length;
    final accuracy = _totalAttempts > 0 
        ? ((correctCount / _totalAttempts) * 100).toStringAsFixed(1)
        : '0.0';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BeginnerGameResultDialog(
        correctCount: correctCount,
        totalAttempts: _totalAttempts,
        accuracy: accuracy,
        mistakes: mistakesList,
        allCharacters: _allCharacters,
        onRestart: () {
          Navigator.pop(context);
          _restartGame();
        },
        onBack: () {
          Navigator.pop(context);
          setState(() {
            _isGameStarted = false;
            _correctCharacters.clear();
            _wrongAnswers.clear();
            _totalAttempts = 0;
            _inputText = '';
            _lastResult = null;
            _pulledIndex = null;
            _lastPulledCharacter = null;
            _remainingSeconds = _selectedDuration;
            _isGameOver = false;
          });
          _generateNewSet();
        },
      ),
    );
  }

  void _restartGame() {
    setState(() {
      _correctCharacters.clear();
      _wrongAnswers.clear();
      _totalAttempts = 0;
      _inputText = '';
      _lastResult = null;
      _pulledIndex = null;
      _lastPulledCharacter = null;
      _remainingSeconds = _selectedDuration;
      _isGameOver = false;
      _isGameStarted = false; // 설정 화면으로 돌아가기
    });
    _generateNewSet();
  }
  
  // ✅ 남은 시간 포맷팅 (분:초)
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 게임 시작 전 설정 화면
    if (!_isGameStarted) {
      return Scaffold(
        backgroundColor: Colors.pink.shade50,
        appBar: AppBar(
          backgroundColor: Colors.pink.shade200,
          title: const Text(
            '初級: クレーンゲーム 🎪',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.toys, size: 80, color: Colors.pink),
                const SizedBox(height: 30),
                const Text(
                  '遊び方',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade100,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🎤 1. マイクで発音', style: TextStyle(fontSize: 18)),
                      SizedBox(height: 8),
                      Text('✨ 2. 正しく読むと正解', style: TextStyle(fontSize: 18)),
                      SizedBox(height: 8),
                      Text('⏰ 3. 時間内にたくさん', style: TextStyle(fontSize: 18)),
                      SizedBox(height: 8),
                      Text('🏆 4. 高得点を目指す', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.pink.shade200, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '⏱️ 制限時間',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButton<int>(
                        value: _selectedDuration,
                        isExpanded: true,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.pink),
                        items: const [
                          DropdownMenuItem(value: 30, child: Text('30秒')),
                          DropdownMenuItem(value: 60, child: Text('1分')),
                          DropdownMenuItem(value: 90, child: Text('1分30秒')),
                          DropdownMenuItem(value: 120, child: Text('2分')),
                          DropdownMenuItem(value: 150, child: Text('2分30秒')),
                          DropdownMenuItem(value: 180, child: Text('3分')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedDuration = value;
                              _remainingSeconds = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showCharacterListDialog,
                      icon: const Icon(Icons.help_outline),
                      label: const Text('文字学習'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.pink,
                        side: const BorderSide(color: Colors.pink, width: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    ElevatedButton(
                      onPressed: _startGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink.shade300,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'スタート',
                        style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ✅ 게임 화면
    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      appBar: AppBar(
        backgroundColor: Colors.pink.shade200,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🎪',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            // ✅ 타이머 표시
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _remainingSeconds <= 30 ? Colors.red.shade100 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _remainingSeconds <= 30 ? Colors.red : Colors.black26,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer,
                    size: 18,
                    color: _remainingSeconds <= 30 ? Colors.red : Colors.black87,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _remainingSeconds <= 30 ? Colors.red : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const PronunciationGuideDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events),
            tooltip: '結果を見る',
            onPressed: _showGameResultDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '음성이나 키보드로 발음을 입력하세요!',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          
          // 인형뽑기 기계
          Expanded(
            child: Stack(
              children: [
                // 인형뽑기 기계
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.pink.shade100,
                        Colors.pink.shade50,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.pink.shade300, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // 인형뽑기 상단 (크레인 암시)
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.pink.shade300,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            '🎪 クレーンゲーム 🎪',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      // 인형들
                      Expanded(
                        child: _displayedCharacters.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : GridView.builder(
                                padding: const EdgeInsets.all(20),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                ),
                                itemCount: _displayedCharacters.length,
                                itemBuilder: (context, index) {
                                  final isPulled = _pulledIndex == index;
                                  
                                  return AnimatedBuilder(
                                    animation: _pullAnimationController,
                                    builder: (context, child) {
                                      if (!isPulled) return child!;
                                      
                                      // 뽑힐 때: 확대 → 아래로 떨어짐 → 사라짐
                                      final progress = _pullAnimationController.value;
                                      double scale = 1.0;
                                      double translateY = 0.0;
                                      double opacity = 1.0;
                                      
                                      if (progress < 0.3) {
                                        // 0-0.3: 확대
                                        scale = 1.0 + (progress / 0.3) * 0.5;
                                      } else if (progress < 0.7) {
                                        // 0.3-0.7: 아래로 떨어짐
                                        scale = 1.5;
                                        translateY = ((progress - 0.3) / 0.4) * 300;
                                      } else {
                                        // 0.7-1.0: 사라짐
                                        scale = 1.5;
                                        translateY = 300;
                                        opacity = (1.0 - ((progress - 0.7) / 0.3)).clamp(0.0, 1.0);
                                      }
                                      
                                      return Transform.translate(
                                        offset: Offset(0, translateY),
                                        child: Transform.scale(
                                          scale: scale,
                                          child: Opacity(
                                            opacity: opacity,
                                            child: child,
                                          ),
                                        ),
                                      );
                                    },
                                    child: _buildCharacterCard(_displayedCharacters[index]),
                                  );
                                },
                              ),
                      ),
                      // 인형뽑기 하단 (배출구)
                      Container(
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.pink.shade300,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: _lastPulledCharacter == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.arrow_downward, color: Colors.white, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          '배출구',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_downward, color: Colors.white, size: 20),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.catching_pokemon, color: Colors.yellow, size: 18),
                                          const SizedBox(width: 6),
                                          Text(
                                            '残り ${_displayedCharacters.length}個',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.check_circle, color: Colors.yellow, size: 20),
                                        const SizedBox(width: 6),
                                        Text(
                                          _lastPulledCharacter!.character,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 32,
                                            height: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getRomanizationDisplay(_lastPulledCharacter!.romanization),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    if (_lastPulledCharacter!.meaning != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        _lastPulledCharacter!.meaning!,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.95),
                                          fontSize: 11,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 입력 위젯
          SpeechInputWidget(
            onTextChanged: (text) {
              setState(() {
                _inputText = text;
              });
            },
            onSubmit: _onInputSubmit,
            lastResult: _lastResult,
            currentInput: _inputText,
            isDisabled: !_isSpeechReady || _isProcessing || _isGameOver, // ✅ 음성인식 준비 안됨, 처리 중, 게임오버일 때 비활성화
          ),
        ],
      ),
    );
  }

  // 영어 발음 표시 헬퍼 메서드
  String _getRomanizationDisplay(String romanization) {
    final lower = romanization.toLowerCase();
    
    // d/t 구분이 필요한 경우
    if (lower.startsWith('d')) {
      return romanization.replaceFirst(RegExp(r'^d', caseSensitive: false), 'd/t');
    }
    
    // r/l 구분이 필요한 경우
    if (lower.startsWith('r')) {
      return romanization.replaceFirst(RegExp(r'^r', caseSensitive: false), 'r/l');
    }
    
    // 그 외는 그대로
    return romanization;
  }

  Widget _buildCharacterCard(HangulCharacter character) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.pink.shade100,
            Colors.pink.shade200,
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.3),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          character.character,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// 초급 게임 결과 다이얼로그 (틀린 글자 표시)
class _BeginnerGameResultDialog extends StatelessWidget {
  final int correctCount;
  final int totalAttempts;
  final String accuracy;
  final List<MapEntry<String, String>> mistakes;
  final List<HangulCharacter> allCharacters;
  final VoidCallback onRestart;
  final VoidCallback onBack;

  const _BeginnerGameResultDialog({
    required this.correctCount,
    required this.totalAttempts,
    required this.accuracy,
    required this.mistakes,
    required this.allCharacters,
    required this.onRestart,
    required this.onBack,
  });

  HangulCharacter? _findCharacter(String charText) {
    try {
      return allCharacters.firstWhere((c) => c.character == charText);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 700, maxWidth: 450),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            const Text(
              '게임 결과 / ゲーム結果',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            
            // 통계
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    size: 50,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.check_circle, size: 24, color: Colors.green),
                          const SizedBox(height: 4),
                          Text(
                            '$correctCount個',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            '正解',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Icon(Icons.trending_up, size: 24, color: Colors.blue),
                          const SizedBox(height: 4),
                          Text(
                            '$accuracy%',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            '正確度',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Icon(Icons.quiz, size: 24, color: Colors.grey),
                          const SizedBox(height: 4),
                          Text(
                            '$totalAttempts回',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            '試行',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 틀린 글자 섹션
            if (mistakes.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '復習が必要な文字',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${mistakes.length}個',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              // 틀린 글자 리스트
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: mistakes.length,
                    itemBuilder: (context, index) {
                      final mistake = mistakes[index];
                      final character = _findCharacter(mistake.key);
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.pink.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                mistake.key,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            character?.pronunciation ?? mistake.key,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (character?.meaning != null)
                                Text(
                                  character!.meaning!,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              Text(
                                mistake.value,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.celebration,
                      size: 60,
                      color: Colors.green,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'パーフェクト！',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      '全ての文字を正しく読みました',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 15),
            
            // 버튼들
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onBack,
                    child: const Text('戻る', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onRestart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'もう一度',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 글자 리스트 다이얼로그
class _CharacterListDialog extends StatelessWidget {
  final List<HangulCharacter> characters;

  const _CharacterListDialog({required this.characters});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '文字リスト',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // 결과 개수 표시
            Text(
              '${characters.length}個の文字',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 15),
            
            // 글자 리스트
            Expanded(
              child: ListView.builder(
                itemCount: characters.length,
                itemBuilder: (context, index) {
                  final char = characters[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    elevation: 2,
                    child: ListTile(
                      title: Text(
                        char.character,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            char.pronunciation,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.blue,
                            ),
                          ),
                          if (char.meaning != null)
                            Text(
                              char.meaning!,
                              style: const TextStyle(fontSize: 14),
                            ),
                        ],
                      ),
                      trailing: Text(
                        char.romanization,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 15),
            
            // 닫기 버튼
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 12,
                ),
              ),
              child: const Text(
                '閉じる',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
