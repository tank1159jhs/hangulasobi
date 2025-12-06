import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import '../../models/korean_data.dart';
import '../../services/data_service.dart';
import '../../services/speech_service.dart';
import '../../widgets/speech_input_widget.dart';
import '../../widgets/sentence_list_dialog.dart';
import '../../widgets/game_complete_dialog.dart';
import '../../utils/string_matcher.dart';

class AdvancedScreen extends StatefulWidget {
  const AdvancedScreen({super.key});

  @override
  State<AdvancedScreen> createState() => _AdvancedScreenState();
}

class _AdvancedScreenState extends State<AdvancedScreen> with SingleTickerProviderStateMixin {
  // ✅ 싱글톤 서비스 사용
  final DataService _dataService = DataService();
  final SpeechService _speechService = SpeechService();
  final FlutterTts _flutterTts = FlutterTts();
  
  List<ScenarioStage> _scenarios = [];
  int _currentScenarioIndex = 0;
  int _currentStageIndex = 0;
  
  bool _isLoading = true;
  bool _showInstructions = true;
  bool _isGameStarted = false;
  bool _isPlaying = false;
  bool _isProcessing = false;
  bool _isSpeechReady = false;
  Timer? _speechCheckTimer;
  
  String _currentInput = '';
  MatchResult? _lastResult;
  
  int _score = 0;
  int _perfectCount = 0;
  int _goodCount = 0;
  int _missCount = 0;
  
  late AnimationController _characterController;
  
  @override
  void initState() {
    super.initState();
    _characterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _loadData();
    _initTts();
    _initSpeech();
  }
  
  Future<void> _initSpeech() async {
    if (!_speechService.isAvailable) {
      await _speechService.initialize();
    }
    
    if (mounted) {
      setState(() {
        _isSpeechReady = _speechService.isAvailable;
      });
    }
    
    // 🔒 타이머는 한 번만 설정하고, 상태 변경이 있을 때만 업데이트
    _speechCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final isAvailable = _speechService.isAvailable;
      // 상태 변경이 있을 때만 setState 호출
      if (_isSpeechReady != isAvailable) {
        setState(() {
          _isSpeechReady = isAvailable;
        });
      }
    });
  }
  
  Future<void> _initTts() async {
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setSpeechRate(0.5); // 천천히
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }
  
  Future<void> _loadData() async {
    try {
      final sentences = await _dataService.loadSentences();
      debugPrint('📥 로드된 문장 수: ${sentences.length}');
      
      // 카테고리별로 문장 필터링
      final greetings = sentences.where((s) => s.category == 'greetings').toList();
      final introduction = sentences.where((s) => s.category == 'introduction').toList();
      final questions = sentences.where((s) => s.category == 'questions').toList();
      final shopping = sentences.where((s) => s.category == 'shopping').toList();
      
      debugPrint('👋 인사: ${greetings.length}개');
      debugPrint('👤 소개: ${introduction.length}개');
      debugPrint('❓ 질문: ${questions.length}개');
      debugPrint('🛒 쇼핑: ${shopping.length}개');
      
      // 🔒 각 카테고리에 최소 1개 이상의 문장이 있는지 확인
      if (greetings.isEmpty || introduction.isEmpty || questions.isEmpty || shopping.isEmpty) {
        debugPrint('⚠️ 경고: 일부 카테고리에 문장이 없습니다!');
        debugPrint('✅ 사용 가능한 카테고리로만 시나리오 구성합니다.');
      }
      
      // 최소 1개 이상의 문장이 있는 카테고리만 사용
      final scenarios = <ScenarioStage>[];
      
      if (greetings.isNotEmpty) {
        scenarios.add(
          ScenarioStage(
            title: '挨拶',
            emoji: '👋',
            character: '友達',
            characterEmoji: '😊',
            sentences: greetings.take(5).toList(),
            backgroundColor: Colors.purple.shade50,
          ),
        );
      }
      
      if (introduction.isNotEmpty) {
        scenarios.add(
          ScenarioStage(
            title: '自己紹介',
            emoji: '👤',
            character: '新しい友達',
            characterEmoji: '🙂',
            sentences: introduction.take(5).toList(),
            backgroundColor: Colors.purple.shade100,
          ),
        );
      }
      
      if (questions.isNotEmpty) {
        scenarios.add(
          ScenarioStage(
            title: '質問',
            emoji: '❓',
            character: 'インタビュアー',
            characterEmoji: '🎤',
            sentences: questions.take(5).toList(),
            backgroundColor: Colors.purple.shade50,
          ),
        );
      }
      
      if (shopping.isNotEmpty) {
        scenarios.add(
          ScenarioStage(
            title: '買い物',
            emoji: '🛒',
            character: '店員',
            characterEmoji: '🧑‍💼',
            sentences: shopping.take(5).toList(),
            backgroundColor: Colors.purple.shade100,
          ),
        );
      }
      
      if (scenarios.isEmpty) {
        throw Exception('❌ 사용 가능한 시나리오가 없습니다!');
      }
      
      setState(() {
        _scenarios = scenarios;
        _isLoading = false;
      });
      
      debugPrint('✅ 시나리오 로드 완료: ${scenarios.length}개');
    } catch (e) {
      debugPrint('❌ 데이터 로드 에러: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  void dispose() {
    _characterController.dispose();
    _speechCheckTimer?.cancel();
    _speechService.stopListening();
    _flutterTts.stop();
    super.dispose();
  }
  
  void _startGame() {
    setState(() {
      _showInstructions = false;
      _isGameStarted = true;
      _currentScenarioIndex = 0;
      _currentStageIndex = 0;
      _score = 0;
      _perfectCount = 0;
      _goodCount = 0;
      _missCount = 0;
    });
  }
  
  Future<void> _playCurrentSentence() async {
    if (_isPlaying) return;
    
    final currentSentence = _getCurrentSentence();
    if (currentSentence == null) return;
    
    setState(() {
      _isPlaying = true;
    });
    
    await _flutterTts.speak(currentSentence.sentence);
  }
  
  KoreanSentence? _getCurrentSentence() {
    // 🔒 인덱스 범위 체크 강화
    if (_scenarios.isEmpty) {
      debugPrint('⚠️ 시나리오 비어있음');
      return null;
    }
    
    if (_currentScenarioIndex >= _scenarios.length) {
      debugPrint('⚠️ 시나리오 인덱스 범위 초과: $_currentScenarioIndex >= ${_scenarios.length}');
      return null;
    }
    
    final scenario = _scenarios[_currentScenarioIndex];
    
    if (scenario.sentences.isEmpty) {
      debugPrint('⚠️ 현재 시나리오에 문장 없음');
      return null;
    }
    
    if (_currentStageIndex >= scenario.sentences.length) {
      debugPrint('⚠️ 문장 인덱스 범위 초과: $_currentStageIndex >= ${scenario.sentences.length}');
      return null;
    }
    
    return scenario.sentences[_currentStageIndex];
  }
  
  void _onInputSubmit(String input) {
    if (_isProcessing || input.trim().isEmpty) return;
    
    _speechService.stopListening();
    
    setState(() {
      _isProcessing = true;
    });
    
    final currentSentence = _getCurrentSentence();
    if (currentSentence == null) return;
    
    final result = StringMatcher.match(input, currentSentence.sentence);
    
    setState(() {
      _lastResult = result;
      _currentInput = '';
    });
    
    if (result == MatchResult.perfect || result == MatchResult.close) {
      final points = result == MatchResult.perfect ? 100 : 50;
      setState(() {
        _score += points;
        if (result == MatchResult.perfect) {
          _perfectCount++;
        } else {
          _goodCount++;
        }
      });
      
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _nextStage();
        }
      });
    } else {
      setState(() {
        _missCount++;
      });
      
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _lastResult = null;
            _isProcessing = false;
          });
        }
      });
    }
  }
  
  void _nextStage() {
    setState(() {
      _currentStageIndex++;
      _lastResult = null;
      _isProcessing = false;
    });
    
    if (_currentStageIndex >= _scenarios[_currentScenarioIndex].sentences.length) {
      _nextScenario();
    }
  }
  
  void _nextScenario() {
    setState(() {
      _currentScenarioIndex++;
      _currentStageIndex = 0;
    });
    
    if (_currentScenarioIndex >= _scenarios.length) {
      _showGameCompleteDialog();
    }
  }
  
  void _showGameCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GameCompleteDialog(
        score: _score,
        perfectCount: _perfectCount,
        goodCount: _goodCount,
        missCount: _missCount,
        onBack: () {
          Navigator.of(context).pop();
          setState(() {
            _isGameStarted = false;
            _showInstructions = true;
          });
        },
        onRetry: () {
          Navigator.of(context).pop();
          _startGame();
        },
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.purple,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    
    // 🔒 시나리오가 비어있는 경우 에러 표시
    if (_scenarios.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.purple.shade50,
        appBar: AppBar(
          backgroundColor: Colors.purple.shade200,
          title: const Text('上級: 会話ゲーム 🎭'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'データ読込エラー',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'シナリオが見つかりません。\nデータファイルを確認してください。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                    });
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  child: const Text('再試行', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    if (_showInstructions) {
      return _buildInstructionsScreen();
    }
    
    if (!_isGameStarted || _currentScenarioIndex >= _scenarios.length) {
      return _buildInstructionsScreen();
    }
    
    return _buildGameScreen();
  }
  
  Widget _buildInstructionsScreen() {
    return Scaffold(
      backgroundColor: Colors.purple.shade50,
      appBar: AppBar(
        backgroundColor: Colors.purple.shade200,
        title: const Text(
          '上級: 会話ゲーム 🎭',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat, size: 80, color: Colors.purple),
              const SizedBox(height: 30),
              const Text(
                '遊び方',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🎧 1. 音声を聞く', style: TextStyle(fontSize: 18)),
                    SizedBox(height: 8),
                    Text('🎤 2. 真似して発音する', style: TextStyle(fontSize: 18)),
                    SizedBox(height: 8),
                    Text('✨ 3. 様々な状況で練習', style: TextStyle(fontSize: 18)),
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
                    onPressed: _showSentenceListDialog,
                    icon: const Icon(Icons.menu_book),
                    label: const Text('文章学習'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: const BorderSide(color: Colors.purple, width: 2),
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
                      backgroundColor: Colors.purple.shade300,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
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
  
  Widget _buildGameScreen() {
    final scenario = _scenarios[_currentScenarioIndex];
    final currentSentence = _getCurrentSentence();
    
    if (currentSentence == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      backgroundColor: scenario.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.purple.shade200,
        title: Text('${scenario.emoji} ${scenario.title}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: '文章学習',
            onPressed: _showSentenceListDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 정보
            _buildTopBar(scenario),
            
            // 캐릭터와 대화 (스크롤 가능)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 캐릭터
                    _buildCharacter(scenario),
                    
                    const SizedBox(height: 20),
                    
                    // 문장 카드
                    _buildSentenceCard(currentSentence),
                    
                    const SizedBox(height: 20),
                    
                    // 재생 버튼
                    _buildPlayButton(),
                    
                    const SizedBox(height: 15),
                    
                    // 피드백
                    if (_lastResult != null) _buildFeedback(),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            
            // 음성 입력
            SpeechInputWidget(
              onTextChanged: (text) {
                setState(() {
                  _currentInput = text;
                });
              },
              onSubmit: _onInputSubmit,
              lastResult: _lastResult,
              currentInput: _currentInput,
              isDisabled: !_isSpeechReady || _isProcessing || _isPlaying,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTopBar(ScenarioStage scenario) {
    final progress = (_currentStageIndex + 1) / scenario.sentences.length;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_scoreポイント',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700,
                ),
              ),
              Text(
                '${_currentStageIndex + 1} / ${scenario.sentences.length}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade300),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  void _showSentenceListDialog() {
    if (_scenarios.isEmpty) return;

    final Map<String, List<KoreanSentence>> byCategory = {};
    for (final scenario in _scenarios) {
      for (final s in scenario.sentences) {
        byCategory.putIfAbsent(s.category, () => []).add(s);
      }
    }

    showDialog(
      context: context,
      builder: (context) => SentenceListDialog(byCategory: byCategory),
    );
  }

  Widget _buildCharacter(ScenarioStage scenario) {
    return AnimatedBuilder(
      animation: _characterController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _characterController.value * 8),
          child: Column(
            children: [
              Text(
                scenario.characterEmoji,
                style: const TextStyle(fontSize: 60),
              ),
              const SizedBox(height: 6),
              Text(
                scenario.character,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildSentenceCard(KoreanSentence sentence) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            sentence.sentence,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              sentence.meaning['ja'] ?? sentence.meaning['en'] ?? '',
              style: TextStyle(
                fontSize: 15,
                color: Colors.purple.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPlayButton() {
    final isFirstSentence = _currentScenarioIndex == 0 && _currentStageIndex == 0;
    final isLastSentence = _currentScenarioIndex == _scenarios.length - 1 &&
        _currentStageIndex == _scenarios[_currentScenarioIndex].sentences.length - 1;
    
    // 🔒 마지막 문장인지 다시 확인하여 UI 상태 동기화
    final canGoNext = !isLastSentence;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 前へ (Previous) button
        _buildNavigationButton(
          icon: Icons.skip_previous,
          label: '前へ',
          onTap: isFirstSentence ? null : _goToPreviousSentence,
          isDisabled: isFirstSentence || _isProcessing,
        ),
        
        const SizedBox(width: 20),
        
        // Play button
        GestureDetector(
          onTap: _isPlaying ? null : _playCurrentSentence,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _isPlaying
                    ? [Colors.grey.shade300, Colors.grey.shade400]
                    : [Colors.purple.shade300, Colors.purple.shade500],
              ),
              boxShadow: [
                BoxShadow(
                  color: _isPlaying
                      ? Colors.grey.withOpacity(0.3)
                      : Colors.purple.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _isPlaying ? Icons.volume_up : Icons.play_arrow,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        
        const SizedBox(width: 20),
        
        // 次へ (Next) button - 마지막 문장이면 비활성화
        _buildNavigationButton(
          icon: Icons.skip_next,
          label: '次へ',
          onTap: canGoNext && !_isProcessing ? _goToNextSentence : null,
          isDisabled: !canGoNext || _isProcessing,
        ),
      ],
    );
  }
  
  Widget _buildNavigationButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool isDisabled,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDisabled ? Colors.grey.shade300 : Colors.purple.shade200,
          boxShadow: [
            BoxShadow(
              color: isDisabled
                  ? Colors.grey.withOpacity(0.2)
                  : Colors.purple.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isDisabled ? Colors.grey.shade500 : Colors.white,
              size: 24,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDisabled ? Colors.grey.shade500 : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _goToPreviousSentence() {
    if (_scenarios.isEmpty || _isProcessing) return;

    // 🔒 게임 완료 상태 확인
    if (_currentScenarioIndex >= _scenarios.length) {
      debugPrint('⚠️ 게임이 이미 완료됨');
      return;
    }

    if (_currentStageIndex > 0) {
      setState(() {
        _currentStageIndex--;
        _lastResult = null;
        _isProcessing = false;
      });
    } else if (_currentScenarioIndex > 0) {
      setState(() {
        _currentScenarioIndex--;
        // 前のシナリオに文がない場合を防御
        final prevScenario = _scenarios[_currentScenarioIndex];
        if (prevScenario.sentences.isNotEmpty) {
          _currentStageIndex = prevScenario.sentences.length - 1;
        } else {
          _currentStageIndex = 0;
        }
        _lastResult = null;
        _isProcessing = false;
      });
    }
  }
  
  void _goToNextSentence() {
    if (_scenarios.isEmpty || _isProcessing) return;

    // 🔒 게임 완료 상태 확인
    if (_currentScenarioIndex >= _scenarios.length) {
      debugPrint('⚠️ 게임이 이미 완료됨');
      return;
    }

    final scenario = _scenarios[_currentScenarioIndex];
    
    if (scenario.sentences.isEmpty) {
      // 文が無いシナリオなら次のシナリオへ
      if (_currentScenarioIndex < _scenarios.length - 1) {
        setState(() {
          _currentScenarioIndex++;
          _currentStageIndex = 0;
          _lastResult = null;
          _isProcessing = false;
        });
      }
      return;
    }

    // 현재 시나리오의 마지막 문장이 아니면 스테이지만 증가
    if (_currentStageIndex < scenario.sentences.length - 1) {
      setState(() {
        _currentStageIndex++;
        _lastResult = null;
        _isProcessing = false;
      });
    }
    // 현재 시나리오의 마지막 문장이고, 다음 시나리오가 있으면 이동
    else if (_currentScenarioIndex < _scenarios.length - 1) {
      setState(() {
        _currentScenarioIndex++;
        _currentStageIndex = 0;
        _lastResult = null;
        _isProcessing = false;
      });
    }
    // 마지막 시나리오의 마지막 문장이면 더 이상 이동하지 않음
    else {
      debugPrint('✅ 마지막 문장에 도달함 - 더 이상 이동 불가');
    }
  }

  Widget _buildFeedback() {
    String emoji;
    String text;
    Color color;
    
    switch (_lastResult) {
      case MatchResult.perfect:
        emoji = '🎯';
        text = '完璧！';
        color = Colors.green;
        break;
      case MatchResult.close:
        emoji = '👍';
        text = '良い！';
        color = Colors.orange;
        break;
      default:
        emoji = '❌';
        text = 'もう一度';
        color = Colors.red;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        '$emoji $text',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class ScenarioStage {
  final String title;
  final String emoji;
  final String character;
  final String characterEmoji;
  final List<KoreanSentence> sentences;
  final Color backgroundColor;
  
  ScenarioStage({
    required this.title,
    required this.emoji,
    required this.character,
    required this.characterEmoji,
    required this.sentences,
    required this.backgroundColor,
  });
}
