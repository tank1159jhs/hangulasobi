import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/korean_data.dart';
import '../utils/string_matcher.dart';

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  int _consecutiveErrors = 0;
  String? _lastRecognizedText;
  
  // 🔒 음성인식 작업 직렬화를 위한 뮤텍스
  bool _isOperationInProgress = false;

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;

  // 음성인식 초기화
  Future<bool> initialize() async {
    try {
      _isAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          _isListening = status == 'listening';
          
          // 음성인식이 완료되면 연속 에러 카운트 리셋
          if (status == 'done' || status == 'notListening') {
            if (_lastRecognizedText != null && _lastRecognizedText!.isNotEmpty) {
              _consecutiveErrors = 0;
            }
          }
        },
        onError: (error) {
          debugPrint('Speech recognition error: ${error.errorMsg}, permanent: ${error.permanent}');
          _isListening = false;
          
          // error_no_match는 단순히 인식 못한 것이므로 에러로 카운트하지 않음
          if (error.errorMsg != 'error_no_match') {
            _consecutiveErrors++;
            
            // 3번 연속 에러 발생 시 재초기화
            if (_consecutiveErrors >= 3) {
              debugPrint('Too many errors, reinitializing...');
              _isAvailable = false;
              _consecutiveErrors = 0;
            }
          }
        },
      );
      
      if (_isAvailable) {
        _consecutiveErrors = 0;
      }
      
      return _isAvailable;
    } catch (e) {
      debugPrint('Failed to initialize speech recognition: $e');
      _isAvailable = false;
      return false;
    }
  }

  // 음성인식 시작 (한국어로 설정)
  Future<void> startListening({
    required Function(String) onResult,
    String localeId = 'ko_KR',
  }) async {
    debugPrint('🎙️ startListening 호출');
    
    // 🔒 다른 작업이 진행 중이면 대기
    while (_isOperationInProgress) {
      debugPrint('⏳ 다른 작업 진행 중 - 대기');
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    _isOperationInProgress = true;
    
    try {
      // ✅ 즉시 중지 (대기 시간 최소화)
      if (_isListening || _speech.isListening) {
        debugPrint('⚠️ 이미 리스닝 중 - 즉시 중지');
        await _speech.stop();
        _isListening = false;
        
        // 🔥 중요: 오디오 엔진이 완전히 정지할 때까지 대기
        await Future.delayed(const Duration(milliseconds: 300));
      }

      _isListening = true;
      _lastRecognizedText = null;
      debugPrint('▶️ 음성인식 시작');
      
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords;
          debugPrint('🎤 인식: "$words"');
          
          if (words.isNotEmpty) {
            _lastRecognizedText = words;
            onResult(words);
          }
        },
        localeId: localeId,
        // ignore: deprecated_member_use
        partialResults: true, // 실시간 표시
        // ignore: deprecated_member_use
        cancelOnError: false,
        listenFor: const Duration(seconds: 5), // ✅ 10초 → 5초로 단축
        pauseFor: const Duration(seconds: 1), // ✅ 10초 → 1초로 단축 (말 멈추면 1초 후 자동 중지)
      );
      
      // 🔥 중요: 리스닝 시작 후 오디오 엔진이 안정화될 때까지 대기
      await Future.delayed(const Duration(milliseconds: 200));
      
    } catch (e) {
      debugPrint('❌ 에러: $e');
      _isListening = false;
      rethrow;
    } finally {
      _isOperationInProgress = false;
    }
  }

  // 음성인식 중지
  Future<void> stopListening() async {
    debugPrint('🛑 stopListening 호출');
    
    // 🔒 다른 작업이 진행 중이면 대기
    while (_isOperationInProgress) {
      debugPrint('⏳ 다른 작업 진행 중 - 대기');
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    _isOperationInProgress = true;
    
    try {
      if (_isListening || _speech.isListening) {
        await _speech.stop();
        _isListening = false;
        debugPrint('✅ 중지 완료');
        
        // 🔥 중요: 오디오 엔진이 완전히 정지할 때까지 대기
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } finally {
      _isOperationInProgress = false;
    }
  }
  
  // 음성인식 취소
  Future<void> cancel() async {
    if (_isListening) {
      try {
        await _speech.cancel();
      } catch (e) {
        debugPrint('Error canceling speech: $e');
      } finally {
        _isListening = false;
      }
    }
  }

  // 사용 가능한 언어 목록 가져오기
  Future<List<stt.LocaleName>> getLocales() async {
    if (!_isAvailable) {
      await initialize();
    }
    return await _speech.locales();
  }

  // 음성인식 결과와 정답 비교
  MatchResult compareResult(String recognized, String correct) {
    return StringMatcher.match(recognized, correct);
  }

  // 여러 타겟 중에서 매칭되는 것 찾기 (중요!)
  Map<String, MatchResult>? findBestMatch(
    String recognized,
    List<String> targets,
  ) {
    return StringMatcher.findBestMatch(recognized, targets);
  }

  void dispose() {
    _speech.stop();
  }
}
