import 'package:flutter/material.dart';
import '../services/speech_service.dart';
import '../models/korean_data.dart';

class SpeechInputWidget extends StatefulWidget {
  final Function(String) onTextChanged;
  final Function(String) onSubmit;
  final MatchResult? lastResult;
  final String currentInput;
  final bool isDisabled; // ✅ 비활성화 여부

  const SpeechInputWidget({
    super.key,
    required this.onTextChanged,
    required this.onSubmit,
    this.lastResult,
    required this.currentInput,
    this.isDisabled = false, // ✅ 기본값 false
  });

  @override
  State<SpeechInputWidget> createState() => _SpeechInputWidgetState();
}

class _SpeechInputWidgetState extends State<SpeechInputWidget> {
  final SpeechService _speechService = SpeechService();
  final TextEditingController _controller = TextEditingController();
  bool _isListening = false;
  bool _isInitializing = false;
  String _latestText = ''; // stop 이후 최종 결과 캡처용

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      widget.onTextChanged(_controller.text);
    });
    // 앱 시작 시 음성인식 초기화
    _initializeSpeech();
  }
  
  Future<void> _initializeSpeech() async {
    if (!_speechService.isAvailable && !_isInitializing) {
      setState(() {
        _isInitializing = true;
      });
      await _speechService.initialize();
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(SpeechInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (!mounted) return; // ✅ 최상단에서 mounted 체크
    
    // 비활성화되면 음성인식 즉시 중지
    if (!oldWidget.isDisabled && widget.isDisabled) {
      debugPrint('🔴 비활성화됨 - 음성인식 강제 중지');
      if (_isListening) {
        _speechService.stopListening();
        if (mounted) {
          setState(() {
            _isListening = false;
          });
        }
      }
    }

    // 활성화되면 상태 리셋
    if (oldWidget.isDisabled && !widget.isDisabled) {
      debugPrint('🟢 활성화됨 - 상태 리셋');
      if (_isListening) {
        _speechService.stopListening();
        if (mounted) {
          setState(() {
            _isListening = false;
          });
        }
      }
    }
    
    // ✅ 음성인식 중이 아니고, 외부에서 currentInput이 비어있으면 TextField도 초기화
    if (!_isListening && widget.currentInput.isEmpty && _controller.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.clear();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _speechService.cancel();
    super.dispose();
  }

  // 버튼 누르기: 음성인식 시작
  void _startListening() {
    if (!mounted || _isListening || widget.isDisabled) return;

    debugPrint('👆 버튼 누름 - 리스닝 시작');
    _controller.clear();
    _latestText = '';

    setState(() {
      _isListening = true;
    });

    _speechService.startListening(
      onResult: (text) {
        if (!mounted) return;
        debugPrint('🎤 인식 중: "$text"');
        _latestText = text;
        _controller.text = text;
      },
    );
  }

  // 버튼 떼기: 음성인식 중지 & 제출
  Future<void> _stopListening() async {
    if (!mounted || !_isListening) return;

    debugPrint('👆 버튼 뗌 - 중지');

    setState(() {
      _isListening = false;
    });

    // stop 호출 — 최종 결과가 있으면 _latestText 업데이트
    await _speechService.stopListening(
      onFinalResult: (text) {
        if (mounted) {
          _latestText = text;
          _controller.text = text;
        }
      },
    );

    if (!mounted) return;

    final text = _latestText.trim();
    if (text.isNotEmpty) {
      debugPrint('📤 제출: "$text"');
      widget.onSubmit(text);
    } else {
      debugPrint('⚠️ 빈 텍스트, 제출하지 않음');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 결과 피드백
          if (widget.lastResult != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _getResultColor(widget.lastResult!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getResultIcon(widget.lastResult!),
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _getResultText(widget.lastResult!),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

          // 입력란
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: '음성 또는 키보드로 입력',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                  ),
                  onSubmitted: widget.onSubmit,
                ),
              ),
              const SizedBox(width: 10),
              
              // 키보드 전송 버튼
              InkWell(
                onTap: () {
                  if (_controller.text.isNotEmpty) {
                    widget.onSubmit(_controller.text);
                  }
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade600],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              
              // 마이크 버튼 (크게!) - 누르고 있으면 녹음, 떼면 입력
              GestureDetector(
                onTapDown: widget.isDisabled ? null : (_) { // ✅ 비활성화 시 null
                  debugPrint('👆 마이크 버튼 누름');
                  _startListening();
                },
                onTapUp: widget.isDisabled ? null : (_) { // ✅ 비활성화 시 null
                  debugPrint('👆 마이크 버튼 뗌');
                  _stopListening();
                },
                onTapCancel: widget.isDisabled ? null : () { // ✅ 비활성화 시 null
                  debugPrint('👆 마이크 버튼 취소');
                  _stopListening();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: widget.isDisabled // ✅ 비활성화 시 회색
                          ? [Colors.grey.shade300, Colors.grey.shade400]
                          : _isInitializing
                              ? [Colors.grey.shade400, Colors.grey.shade600]
                              : _isListening
                                  ? [Colors.red.shade400, Colors.red.shade600]
                                  : [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.isDisabled // ✅ 비활성화 시 약한 그림자
                            ? Colors.grey.withValues(alpha: 0.2)
                            : _isInitializing
                                ? Colors.grey.withValues(alpha: 0.4)
                                : _isListening
                                    ? Colors.red.withValues(alpha: 0.4)
                                    : Colors.blue.withValues(alpha: 0.4),
                        blurRadius: _isListening ? 15 : 10,
                        spreadRadius: _isListening ? 3 : 2,
                      ),
                    ],
                  ),
                  child: widget.isDisabled // ✅ 비활성화 시 아이콘 변경
                      ? Icon(
                          Icons.mic_off,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 32,
                        )
                      : _isInitializing
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: Colors.white,
                              size: 32,
                            ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          Text(
            widget.isDisabled // ✅ 비활성화 시 메시지
                ? '⏳ 処理中... / 처리 중...'
                : _isInitializing
                    ? '⏳ 音声認識を初期化中... / 음성인식 초기화 중...'
                    : _isListening
                        ? '🎤 話してください！離すと入力 / 말씀하세요! 떼면 입력'
                    : '長押しして話す。離すと送信 / 길게 눌러 말하고 떼면 전송',
            style: TextStyle(
              fontSize: 12,
              color: _isListening ? Colors.red.shade600 : Colors.grey.shade600,
              fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Color _getResultColor(MatchResult result) {
    switch (result) {
      case MatchResult.perfect:
        return Colors.green;
      case MatchResult.close:
        return Colors.orange;
      case MatchResult.wrong:
        return Colors.red;
    }
  }

  String _getResultIcon(MatchResult result) {
    switch (result) {
      case MatchResult.perfect:
        return '⭕';
      case MatchResult.close:
        return '🔺';
      case MatchResult.wrong:
        return '❌';
    }
  }

  String _getResultText(MatchResult result) {
    switch (result) {
      case MatchResult.perfect:
        return '完璧! / 완벽!';
      case MatchResult.close:
        return '惜しい! / 아까워!';
      case MatchResult.wrong:
        return 'もう一度 / 다시 시도';
    }
  }
}
