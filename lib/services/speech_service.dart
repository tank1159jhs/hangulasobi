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
    Function(String)? onFinalResult,
    String localeId = 'ko_KR',
    Duration listenFor = const Duration(seconds: 5),
    Duration pauseFor = const Duration(seconds: 1),
  }) async {
    debugPrint('🎙️ startListening 호출');

    // 이미 리스닝 중이면 먼저 중지
    if (_isListening || _speech.isListening) {
      debugPrint('⚠️ 이미 리스닝 중 - 중지 후 재시작');
      await _speech.stop();
      _isListening = false;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      _isListening = true;
      _lastRecognizedText = null;
      debugPrint('▶️ 음성인식 시작');

      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords;
          debugPrint('🎤 인식: "$words" (final: ${result.finalResult})');

          if (words.isNotEmpty) {
            _lastRecognizedText = words;
            onResult(words);
            if (result.finalResult && onFinalResult != null) {
              onFinalResult(words);
            }
          }
        },
        localeId: localeId,
        // ignore: deprecated_member_use
        partialResults: true,
        // ignore: deprecated_member_use
        cancelOnError: false,
        listenFor: listenFor,
        pauseFor: pauseFor,
      );
    } catch (e) {
      debugPrint('❌ 에러: $e');
      _isListening = false;
      rethrow;
    }
  }

  // 음성인식 중지 — 최종 결과를 기다리는 콜백 지원
  Future<void> stopListening({Function(String)? onFinalResult}) async {
    debugPrint('🛑 stopListening 호출');

    if (!_isListening && !_speech.isListening) {
      debugPrint('이미 중지됨');
      return;
    }

    await _speech.stop();
    _isListening = false;
    debugPrint('✅ 중지 완료');

    // 최종 결과 콜백이 있으면 엔진이 마지막 결과를 보낼 시간을 줌 (최소 지연)
    if (onFinalResult != null && _lastRecognizedText != null) {
      await Future.delayed(const Duration(milliseconds: 80));
      onFinalResult(_lastRecognizedText!);
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
