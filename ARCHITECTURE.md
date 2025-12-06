# 한글遊び (Hangul Asobi) - 아키텍처 및 구조 문서

## 📱 앱 개요
일본인을 위한 한글 학습 게임 앱입니다. 음성인식을 통해 한글 발음을 연습할 수 있습니다.

---

## 🗂️ 프로젝트 구조

```
lib/
├── main.dart                          # 앱 진입점
├── models/                            # 데이터 모델
│   └── korean_data.dart              # 한글 데이터 구조 정의
├── services/                          # 비즈니스 로직
│   ├── data_service.dart             # 데이터 로딩 서비스
│   ├── speech_service.dart           # 음성인식 서비스 (싱글톤)
│   └── progress_service.dart         # 진행도 저장 서비스
├── screens/                           # 화면
│   ├── home_screen.dart              # 홈 화면
│   ├── beginner/                     # 초급 게임
│   │   └── beginner_screen.dart
│   ├── intermediate/                 # 중급 게임
│   │   └── intermediate_screen.dart
│   └── advanced/                     # 고급 게임 (예정)
├── widgets/                           # 재사용 가능한 위젯
│   ├── speech_input_widget.dart      # 음성 입력 위젯
│   └── pronunciation_guide_dialog.dart
└── utils/                             # 유틸리티
    └── string_matcher.dart           # 문자열 매칭 로직
```

---

## 🏗️ 핵심 아키텍처

### 1. **싱글톤 패턴 - SpeechService**
```dart
class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
}
```

**중요**: 모든 화면이 **같은 음성인식 인스턴스를 공유**합니다.
- **장점**: 리소스 효율적
- **주의점**: 화면 전환 시 `dispose()`에서 반드시 `stopListening()` 호출 필요

---

## 🎮 게임 모드

### 초급 게임 (Beginner) - 인형뽑기 🎪
**파일**: `lib/screens/beginner/beginner_screen.dart`

#### 게임 로직:
1. **설정 화면**: 시간 선택 (30초~3분, 30초 단위)
2. **게임 시작**: 타이머 시작, 8개 글자 표시
3. **음성 입력**: 마이크 버튼으로 발음
4. **정답 체크**: 
   - ✅ 정답 → 애니메이션 → 다음 문제
   - ❌ 오답 → 1초 피드백 → 다시 시도
5. **결과 화면**: 정확도, 틀린 글자 복습

#### 상태 관리:
```dart
bool _isProcessing = false;  // 정답 체크 중 (마이크 비활성화)
bool _isGameOver = false;    // 게임 종료 여부
int _remainingSeconds;       // 남은 시간
Set<String> _correctCharacters;  // 맞춘 글자
Map<String, int> _wrongAnswers;  // 틀린 글자 추적
```

---

### 중급 게임 (Intermediate) - 떨어지는 단어 🎯
**파일**: `lib/screens/intermediate/intermediate_screen.dart`

#### 게임 로직:
1. **설명 화면** 표시
2. **게임 시작**: 2초마다 단어 생성
3. **떨어지는 애니메이션**: 60fps로 업데이트
4. **음성 입력**: 단어 발음하면 제거 + 점수
5. **10개 놓치면 게임 오버**

#### 상태 관리:
```dart
List<FallingWord> _fallingWords;  // 떨어지는 단어 리스트
int _score;                        // 점수
int _missedCount;                  // 놓친 개수
int _combo;                        // 콤보
Timer? _spawnTimer;                // 단어 생성 타이머
Timer? _updateTimer;               // 화면 업데이트 타이머
```

---

## 🎤 음성인식 처리 흐름

### 1. **초기화** (앱 시작 시)
```dart
// main.dart
void main() async {
  await SpeechService().initialize();  // 싱글톤 초기화
  runApp(const MyApp());
}
```

### 2. **음성인식 시작** (버튼 누름)
```
사용자가 마이크 버튼 누름 (onTapDown)
  ↓
speech_input_widget.dart: _startListening()
  ↓
speech_service.dart: startListening()
  ↓
_speech.listen(
  partialResults: true,        # 실시간 표시
  pauseFor: 10초,              # 자동 중지 안 함 (버튼으로만 제어)
  listenFor: 10초,
  onResult: (result) { ... }   # TextField에 실시간 표시
)
```

### 3. **음성인식 중지** (버튼 뗌)
```
사용자가 마이크 버튼 뗌 (onTapUp)
  ↓
speech_input_widget.dart: _stopListening()
  ↓
speech_service.dart: stopListening()
  ↓
_speech.stop()  # 즉시 중지
  ↓
widget.onSubmit(text)  # 즉시 전송
  ↓
게임 화면: _onInputSubmit(input)
  ↓
정답 체크
```

### 4. **정답 체크 중**
```dart
// beginner_screen.dart
void _onInputSubmit(String input) {
  _speechService.stopListening();  // ✅ 즉시 음성인식 중지
  
  setState(() {
    _isProcessing = true;  // ✅ 마이크 비활성화
  });
  
  // 정답 체크 로직...
  
  // 애니메이션 후
  setState(() {
    _isProcessing = false;  // ✅ 마이크 활성화
  });
}
```

---

## 🔄 화면 전환 시 처리

### 중요: 화면 떠날 때 음성인식 정리

```dart
@override
void dispose() {
  _speechService.stopListening();  // ✅ 반드시 호출
  // 기타 리소스 정리...
  super.dispose();
}
```

**이유**: 싱글톤을 공유하므로, 이전 화면의 음성인식 세션이 남아있으면 충돌 발생

---

## 🎯 문자열 매칭 로직

### 비슷한 발음 정답 인정
**파일**: `lib/utils/string_matcher.dart`

```dart
// ㅐ/ㅔ/ㅒ/ㅖ 계열 → 'ㅔ'로 통일
개/게/걔/계 → 모두 "게"
내/네/냬/녜 → 모두 "네"
왜/웨 → 모두 "왜"
```

### 매칭 등급:
- **Perfect**: 정확히 일치 (정규화 후)
- **Close**: 70% 이상 유사 (Levenshtein distance)
- **Wrong**: 그 외

---

## 📊 데이터 구조

### HangulCharacter (한 글자)
```dart
class HangulCharacter {
  final String character;      // 한글: "가"
  final String pronunciation;  // 발음: "ga"
  final String romanization;   // 로마자: "ga"
  final String? meaning;       // 의미: "~が"
}
```

### KoreanWord (단어)
```dart
class KoreanWord {
  final String korean;         // "안녕"
  final String pronunciation;  // "annyeong"
  final String meaning;        // "こんにちは"
  final String? example;       // 예문
}
```

---

## 🚀 주요 최적화

### 1. **음성인식 지연 최소화**
```dart
// ❌ 기존: 대기 시간 있음
await Future.delayed(Duration(milliseconds: 300));

// ✅ 현재: 즉시 실행
await _speech.stop();
_isListening = false;
```

### 2. **마이크 비활성화로 충돌 방지**
```dart
// 정답 체크 중
_isProcessing = true;  // 마이크 비활성화

// SpeechInputWidget에서
if (widget.isDisabled || _isListening) return;  // 시작 불가
```

### 3. **didUpdateWidget에서 상태 정리**
```dart
@override
void didUpdateWidget(SpeechInputWidget oldWidget) {
  super.didUpdateWidget(oldWidget);
  
  // 비활성화되면 음성인식 즉시 중지
  if (!oldWidget.isDisabled && widget.isDisabled) {
    _speechService.stopListening();
    setState(() { _isListening = false; });
  }
}
```

---

## 🐛 알려진 문제 및 해결책

### 문제 1: 다음 문제로 넘어갈 때 음성인식 안 됨
**원인**: 이전 음성인식 세션이 완전히 종료되지 않음

**해결**:
```dart
void _onInputSubmit(String input) {
  _speechService.stopListening();  // ✅ 제일 먼저 중지
  setState(() { _isProcessing = true; });
  // ...
}
```

### 문제 2: 화면 전환 시 충돌
**원인**: 싱글톤 공유로 인한 충돌

**해결**:
```dart
@override
void dispose() {
  _speechService.stopListening();  // ✅ 반드시 정리
  super.dispose();
}
```

### 문제 3: 계/개/걔 구분 안 됨
**원인**: 한국어 발음 특성

**해결**:
```dart
// string_matcher.dart에서 정규화
.replaceAll('개', '게').replaceAll('걔', '게').replaceAll('계', '게')
```

---

## 📝 코딩 컨벤션

### 1. **상태 변수 명명**
```dart
bool _isProcessing;   // 처리 중
bool _isGameOver;     // 게임 종료
bool _isListening;    // 음성인식 중
int _remainingSeconds; // 남은 시간
```

### 2. **콜백 함수 명명**
```dart
void _onInputSubmit(String input);  // 입력 제출
void _startGame();                   // 게임 시작
void _showGameResultDialog();       // 결과 표시
```

### 3. **주석 스타일**
```dart
// ✅ 중요한 수정 사항
// ❌ 잘못된 방법
// 🎯 핵심 로직
```

---

## 🔮 향후 개발 계획

### 고급 게임 (Advanced)
- **컨베이어 벨트 게임** 예정
- 문장 단위 학습

### 추가 기능
- 학습 진행도 저장 (`progress_service.dart`)
- 발음 가이드 개선
- 일본 앱스토어 출시

---

## 🛠️ 개발 환경

### 필수 패키지
```yaml
dependencies:
  flutter:
    sdk: flutter
  speech_to_text: ^6.6.0    # 음성인식
  shared_preferences: ^2.2.0 # 로컬 저장
```

### 테스트
```bash
flutter run
flutter test
```

---

## 📞 문제 해결 가이드

### 음성인식이 안 될 때
1. `main.dart`에서 초기화 확인
2. iOS: `Info.plist`에 권한 추가 확인
3. 로그 확인: `print()` 문 활용

### 마이크 버튼이 반응 안 할 때
1. `_isProcessing` 상태 확인
2. `isDisabled` prop 확인
3. `dispose()`에서 `stopListening()` 호출 확인

### 정답이 인정 안 될 때
1. `string_matcher.dart`의 정규화 로직 확인
2. 콘솔 로그 확인: `print('🎤 입력: "$input"')`
3. `_normalizeSimilarSounds()` 함수 수정

---

## 📚 참고 자료

- [speech_to_text 패키지](https://pub.dev/packages/speech_to_text)
- [Flutter 상태 관리](https://flutter.dev/docs/development/data-and-backend/state-mgmt)
- [싱글톤 패턴](https://dart.dev/guides/language/language-tour#constructors)

---

**작성일**: 2025년 1월 24일
**버전**: 1.0.0
**작성자**: 개발팀
