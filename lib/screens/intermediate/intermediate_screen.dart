import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../models/korean_data.dart';
import '../../services/speech_service.dart';
import '../../services/data_service.dart';
import '../../widgets/speech_input_widget.dart';

class IntermediateScreen extends StatefulWidget {
  const IntermediateScreen({super.key});

  @override
  State<IntermediateScreen> createState() => _IntermediateScreenState();
}

class _IntermediateScreenState extends State<IntermediateScreen>
    with TickerProviderStateMixin {
  // ✅ 싱글톤 서비스 사용
  final SpeechService _speechService = SpeechService();
  final DataService _dataService = DataService();
  final Random _random = Random();

  List<KoreanWord> _allWords = [];
  final List<FallingWord> _fallingWords = [];
  Timer? _spawnTimer;
  Timer? _updateTimer;

  int _score = 0;
  int _missedCount = 0;
  final int _maxMissed = 10;
  bool _isGameOver = false;
  bool _isLoading = true;
  bool _showInstructions = true;
  String _currentInput = '';
  MatchResult? _lastResult;
  int _combo = 0;
  int _gameTime = 0;
  bool _isSpeechReady = false;
  bool _isProcessing = false;
  Timer? _speechCheckTimer;
  
  final Map<String, int> _missedWords = {};
  final Map<String, int> _wrongAnswers = {};

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    _allWords = await _dataService.loadWords();

    if (!_speechService.isAvailable) {
      await _speechService.initialize();
    }

    setState(() {
      _isLoading = false;
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

  void _startGame() {
    // 게임 시간 타이머
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isGameOver) {
        timer.cancel();
      } else {
        setState(() {
          _gameTime++;
        });
      }
    });

    // ✅ 단어 생성 타이머 (3초마다, 최대 3개로 제한)
    _spawnTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isGameOver && _fallingWords.length < 3) {
        _spawnWord();
      }
    });

    // 화면 업데이트 타이머 (60fps)
    _updateTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_isGameOver) {
        _updateWords();
      }
    });
  }

  void _spawnWord() {
    if (_allWords.isEmpty) return;

    final word = _allWords[_random.nextInt(_allWords.length)];
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = 120.0;

    final baseSpeed = 0.5 + (_gameTime / 120.0).clamp(0.0, 0.3);
    final speed = baseSpeed + _random.nextDouble() * 0.2;

    double newX;
    int attempts = 0;
    const minDistance = 140.0;
    
    do {
      newX = _random.nextDouble() * (screenWidth - cardWidth);
      attempts++;
      
      if (attempts > 10) break;
      
      final tooClose = _fallingWords.any((existing) {
        final isInTopThird = existing.y < MediaQuery.of(context).size.height / 3;
        return isInTopThird && (existing.x - newX).abs() < minDistance;
      });
      
      if (!tooClose) break;
    } while (true);

    final fallingWord = FallingWord(
      word: word,
      x: newX,
      y: -100,
      speed: speed,
    );

    setState(() {
      _fallingWords.add(fallingWord);
    });
  }

  void _updateWords() {
    setState(() {
      final screenHeight = MediaQuery.of(context).size.height;

      _fallingWords.removeWhere((word) {
        word.y += word.speed;

        if (word.y > screenHeight - 200) {
          _missedCount++;
          _missedWords[word.word.word] = (_missedWords[word.word.word] ?? 0) + 1;
          
          if (_missedCount >= _maxMissed) {
            _gameOver();
          }
          return true;
        }
        return false;
      });
    });
  }

  void _onTextChanged(String text) {
    if (_isProcessing || _isGameOver) return;
    
    // 단순히 입력 표시만 업데이트 (매칭은 하지 않음)
    setState(() {
      _currentInput = text;
    });
  }

  void _onSubmit(String recognized) {
    if (_isProcessing || _isGameOver) return;
    
    if (recognized.isEmpty || _fallingWords.isEmpty) {
      setState(() {
        _lastResult = null;
        _currentInput = '';
      });
      return;
    }

    // 마이크를 놓았을 때만 매칭 시도
    _tryMatchWord(recognized);
  }

  void _tryMatchWord(String input) {
    if (_isProcessing || _fallingWords.isEmpty) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    final targets = _fallingWords.map((w) => w.word.word).toList();
    final matchResult = _speechService.findBestMatch(input, targets);

    if (matchResult != null) {
      final matchedWord = matchResult.keys.first;
      final result = matchResult.values.first;

      if (result == MatchResult.perfect || result == MatchResult.close) {
        _combo++;
        
        final comboBonus = _combo >= 3 ? (_combo - 2) * 10 : 0;
        final baseScore = result == MatchResult.perfect ? 100 : 70;
        
        setState(() {
          _fallingWords.removeWhere((w) => w.word.word == matchedWord);
          _score += baseScore + comboBonus;
          _lastResult = result;
          _currentInput = '';
        });

        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _lastResult = null;
              _isProcessing = false;
            });
          }
        });
      } else {
        _combo = 0;
        _wrongAnswers[matchedWord] = (_wrongAnswers[matchedWord] ?? 0) + 1;
        
        setState(() {
          _lastResult = result;
          _currentInput = '';
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _lastResult = null;
              _isProcessing = false;
            });
          }
        });
      }
    } else {
      // 매칭 실패
      _combo = 0;
      
      setState(() {
        _lastResult = MatchResult.wrong;
        _currentInput = '';
      });
      
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _lastResult = null;
            _isProcessing = false;
          });
        }
      });
    }
  }

  void _gameOver() {
    setState(() {
      _isGameOver = true;
    });

    _spawnTimer?.cancel();
    _updateTimer?.cancel();

    _showGameOverDialog();
  }

  void _showGameOverDialog() {
    final minutes = _gameTime ~/ 60;
    final seconds = _gameTime % 60;
    final timeStr = minutes > 0 
        ? '$minutes分$seconds秒' 
        : '$seconds秒';

    // ✅ 틀린 단어 리스트 생성
    final mistakesList = <MapEntry<String, String>>[];
    
    // 놓친 단어 추가
    _missedWords.forEach((word, count) {
      mistakesList.add(MapEntry(word, '落とした: $count回'));
    });
    
    // 틀린 단어 추가
    _wrongAnswers.forEach((word, count) {
      if (!_missedWords.containsKey(word)) {
        mistakesList.add(MapEntry(word, '間違えた: $count回'));
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _GameResultDialog(
        score: _score,
        timeStr: timeStr,
        mistakes: mistakesList,
        allWords: _allWords,
        onRestart: () {
          Navigator.pop(context);
          _restartGame();
        },
        onBack: () {
          Navigator.pop(context);
          _resetToInstructions();
        },
      ),
    );
  }



  void _restartGame() {
    setState(() {
      _score = 0;
      _missedCount = 0;
      _isGameOver = false;
      _fallingWords.clear();
      _currentInput = '';
      _lastResult = null;
      _combo = 0;
      _gameTime = 0;
      _missedWords.clear(); // ✅ 틀린 단어 기록 초기화
      _wrongAnswers.clear();
    });

    _startGame();
  }

  void _resetToInstructions() {
    setState(() {
      _score = 0;
      _missedCount = 0;
      _isGameOver = false;
      _fallingWords.clear();
      _currentInput = '';
      _lastResult = null;
      _combo = 0;
      _gameTime = 0;
      _missedWords.clear(); // ✅ 틀린 단어 기록 초기화
      _wrongAnswers.clear();
      _showInstructions = true; // 설명 화면으로 돌아가기
    });
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _updateTimer?.cancel();
    _speechCheckTimer?.cancel();
    // ✅ 화면 떠날 때 음성인식 완전히 정리
    _speechService.stopListening();
    super.dispose();
  }

  void _startGameAfterInstructions() {
    setState(() {
      _showInstructions = false;
    });
    _startGame();
  }

  void _showWordListDialog() {
    showDialog(
      context: context,
      builder: (context) => _WordListDialog(words: _allWords),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            '中級: 単語雨ゲーム 🌧️',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_showInstructions) {
      return Scaffold(
        backgroundColor: Colors.blue.shade50,
        appBar: AppBar(
          backgroundColor: Colors.blue.shade200,
          title: const Text(
            '中級: 単語雨ゲーム 🌧️',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud, size: 80, color: Colors.blue),
                const SizedBox(height: 30),
                const Text(
                  '遊び方',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🌧️ 1. 単語が降ってきます', style: TextStyle(fontSize: 18)),
                      SizedBox(height: 8),
                      Text('🎤 2. マイクで発音', style: TextStyle(fontSize: 18)),
                      SizedBox(height: 8),
                      Text('⚡ 3. コンボでボーナス', style: TextStyle(fontSize: 18)),
                      SizedBox(height: 8),
                      Text('🏆 4. 高得点を目指す', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showWordListDialog,
                      icon: const Icon(Icons.help_outline),
                      label: const Text('単語学習'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue, width: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    ElevatedButton(
                      onPressed: _startGameAfterInstructions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade300,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '中級: 単語雨ゲーム 🌧️',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        actions: [
          // 점수 표시
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '$_score点',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 배경
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade100,
                  Colors.blue.shade50,
                ],
              ),
            ),
          ),

          // 떨어지는 단어들
          ..._fallingWords.map((word) => Positioned(
                left: word.x,
                top: word.y,
                child: _buildWordCard(word.word),
              )),

          // 상단 정보 표시
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '失敗: $_missedCount / $_maxMissed',
                    style: TextStyle(
                      fontSize: 16,
                      color: _missedCount >= _maxMissed - 1
                          ? Colors.red
                          : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '落ちてくる: ${_fallingWords.length}個',
                    style: const TextStyle(fontSize: 14),
                  ),
                  // ✅ 음성 인식 준비 상태 표시
                  if (!_isSpeechReady) ...[
                    const SizedBox(height: 5),
                    const Row(
                      children: [
                        Icon(Icons.mic_off, size: 14, color: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          'マイク準備中...',
                          style: TextStyle(fontSize: 12, color: Colors.red),
                        ),
                      ],
                    ),
                  ],
                  if (_combo >= 3) ...[
                    const SizedBox(height: 5),
                    Text(
                      '🔥 $_comboコンボ！',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 하단 음성 입력
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SpeechInputWidget(
              onTextChanged: _onTextChanged,
              onSubmit: _onSubmit,
              lastResult: _lastResult,
              currentInput: _currentInput,
              isDisabled: !_isSpeechReady || _isProcessing, // ✅ 음성 인식 준비 안되거나 처리 중이면 비활성화
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(KoreanWord word) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 이모지
          Text(
            word.emoji,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 4),
          // 한글 단어
          Text(
            word.word,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          // 일본어 의미
          if (word.meaning.containsKey('ja'))
            Text(
              word.meaning['ja']!,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

// 떨어지는 단어 클래스
class FallingWord {
  final KoreanWord word;
  double x;
  double y;
  final double speed;

  FallingWord({
    required this.word,
    required this.x,
    required this.y,
    required this.speed,
  });
}

// 단어 리스트 다이얼로그 (카테고리 필터링 기능 포함)
class _WordListDialog extends StatefulWidget {
  final List<KoreanWord> words;

  const _WordListDialog({required this.words});

  @override
  State<_WordListDialog> createState() => _WordListDialogState();
}

class _WordListDialogState extends State<_WordListDialog> {
  String _selectedCategory = 'all'; // 'all' = 전체
  
  // 카테고리 이름을 일본어로 변환
  final Map<String, String> _categoryNames = {
    'all': '全て',
    'family': '家族',
    'food': '食べ物',
    'numbers': '数字',
    'colors': '色',
    'animals': '動物',
    'objects': '物',
    'people': '人',
    'places': '場所',
    'time': '時間',
    'weather': '天気',
    'seasons': '季節',
    'emotions': '感情',
    'adjectives': '形容詞',
  };

  List<KoreanWord> get _filteredWords {
    if (_selectedCategory == 'all') {
      return widget.words;
    }
    return widget.words.where((word) => word.category == _selectedCategory).toList();
  }

  List<String> get _availableCategories {
    final categories = <String>{'all'};
    for (var word in widget.words) {
      categories.add(word.category);
    }
    return categories.toList()..sort();
  }

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
                  '単語リスト',
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
            
            // 카테고리 드롭다운
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                items: _availableCategories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Row(
                      children: [
                        Icon(
                          category == 'all' ? Icons.apps : Icons.category,
                          size: 20,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _categoryNames[category] ?? category,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  }
                },
              ),
            ),
            
            const SizedBox(height: 10),
            
            // 결과 개수 표시
            Text(
              '${_filteredWords.length}個の単語',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 15),
            
            // 단어 리스트
            Expanded(
              child: _filteredWords.isEmpty
                  ? Center(
                      child: Text(
                        'この単語がありません',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[500],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredWords.length,
                      itemBuilder: (context, index) {
                        final word = _filteredWords[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          elevation: 2,
                          child: ListTile(
                            leading: Text(
                              word.emoji,
                              style: const TextStyle(fontSize: 28),
                            ),
                            title: Text(
                              word.word,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (word.meaning.containsKey('ja'))
                                  Text(
                                    word.meaning['ja']!,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                if (_selectedCategory == 'all')
                                  Text(
                                    _categoryNames[word.category] ?? word.category,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
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
                backgroundColor: Colors.blue,
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

// 게임 결과 다이얼로그 (틀린 단어 표시)
class _GameResultDialog extends StatelessWidget {
  final int score;
  final String timeStr;
  final List<MapEntry<String, String>> mistakes;
  final List<KoreanWord> allWords;
  final VoidCallback onRestart;
  final VoidCallback onBack;

  const _GameResultDialog({
    required this.score,
    required this.timeStr,
    required this.mistakes,
    required this.allWords,
    required this.onRestart,
    required this.onBack,
  });

  KoreanWord? _findWord(String wordText) {
    try {
      return allWords.firstWhere((w) => w.word == wordText);
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
              'ゲームオーバー',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            
            // 점수
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    size: 50,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$score点',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.timer, size: 20, color: Colors.grey),
                          Text(
                            timeStr,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Icon(Icons.check_circle, size: 20, color: Colors.green),
                          Text(
                            '${(score / 100).floor()}個',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 틀린 단어 섹션
            if (mistakes.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '復習が必要な単語',
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
              
              // 틀린 단어 리스트
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
                      final word = _findWord(mistake.key);
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: word != null
                              ? Text(
                                  word.emoji,
                                  style: const TextStyle(fontSize: 24),
                                )
                              : const Icon(Icons.error, color: Colors.red),
                          title: Text(
                            mistake.key,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (word != null && word.meaning.containsKey('ja'))
                                Text(
                                  word.meaning['ja']!,
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
                      '全ての単語を正しく読みました',
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
                      backgroundColor: Colors.blue,
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
