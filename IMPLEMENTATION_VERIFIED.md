# ✅ 음성인식 구현 확인 보고서

**작성일**: 2024년 12월  
**상태**: ✅ 검증 완료  
**설명**: 한글아소비 음성인식 기능이 실제로 어떻게 구현되어 있는지 정확히 분석한 보고서

---

## 📋 목차

1. [음성입력 UI 메커니즘](#음성입력-ui-메커니즘)
2. [실행 흐름 상세](#실행-흐름-상세)
3. [핵심 구현 코드](#핵심-구현-코드)
4. [파일별 역할](#파일별-역할)
5. [설정 값 설명](#설정-값-설명)

---

## 🎯 음성입력 UI 메커니즘

### 버튼 타입

```dart
// lib/widgets/speech_input_widget.dart (Line 263-280)
GestureDetector(
  onTapDown: widget.isDisabled ? null : (_) { 
    debugPrint('👆 마이크 버튼 누름');
    _startListening();
  },
  onTapUp: widget.isDisabled ? null : (_) { 
    debugPrint('👆 마이크 버튼 뗌');
    _stopListening();
  },
  onTapCancel: widget.isDisabled ? null : () { 
    debugPrint('👆 마이크 버튼 취소');
    _stopListening();
  },
  child: AnimatedContainer(...)
)
```

### 사용자 경험

| 시점 | 사용자 액션 | 앱 반응 | 화면 표시 |
|------|-----------|--------|---------|
| 초기 상태 | - | - | 🔵 파란색 마이크 버튼 |
| 1️⃣ 버튼 누르기 | **길게 누름** 👇 | `onTapDown` 호출 | 🔴 빨강색 변경 |
| 2️⃣ 음성 입력 | **마이크에 말함** 🎤 | `_startListening()` 작동 | TextField에 **실시간 표시** |
| 3️⃣ 버튼 떼기 | **손가락 뗌** 🖐️ | `onTapUp` 호출 | 즉시 리셋 |
| 4️⃣ 결과 처리 | - | `_stopListening()` 완료 | 결과 피드백 표시 |

---

## 📊 실행 흐름 상세

### 🎙️ 음성 시작 흐름

```
사용자 길게 누름
    ↓
onTapDown() 호출
    ↓
_startListening() 호출
    ↓
_controller.clear()  ← 이전 입력 제거
    ↓
setState(() { _isListening = true; })
    ↓
_speechService.startListening(onResult: (text) { ... })
    ↓
Google Speech API 호출
(한국어: ko_KR)
    ↓
마이크 활성화, 음성 수신 시작
    ↓
결과 콜백
_controller.text = text  ← TextField 업데이트
    ↓
UI 실시간 표시
```

### 🛑 음성 중지 흐름

```
사용자 손가락 뗌 (또는 취소)
    ↓
onTapUp() / onTapCancel() 호출
    ↓
_stopListening() 호출
    ↓
final text = _controller.text.trim()  ← 현재 텍스트 저장
    ↓
_speechService.stopListening()  ← 마이크 즉시 중지
    ↓
setState(() { _isListening = false; })
    ↓
await Future.delayed(100ms)  ← 짧은 대기
    ↓
if (text.isNotEmpty)
    widget.onSubmit(text)  ← 텍스트 제출
    ↓
게임 로직에서 매칭 시작
```

---

## 🔧 핵심 구현 코드

### 1️⃣ 버튼 누르기 (시작)

```dart
// lib/widgets/speech_input_widget.dart (Line 106-125)
void _startListening() {
  if (!mounted || _isListening || widget.isDisabled) return;
  
  debugPrint('👆 버튼 누름 - 리스닝 시작');
  _controller.clear();  // 이전 입력 제거
  
  setState(() {
    _isListening = true;  // UI 업데이트 (파란색 → 빨간색)
  });
  
  _speechService.startListening(
    onResult: (text) {
      if (!mounted) return;
      debugPrint('🎤 인식 중: "$text"');
      _controller.text = text;  // TextField 실시간 업데이트
    },
  );
}
```

### 2️⃣ 버튼 떼기 (중지 + 제출)

```dart
// lib/widgets/speech_input_widget.dart (Line 128-153)
Future<void> _stopListening() async {
  if (!mounted || !_isListening) return;
  
  debugPrint('👆 버튼 뗌 - 제출');
  
  final text = _controller.text.trim();  // 현재 텍스트 저장
  
  await _speechService.stopListening();  // 마이크 즉시 중지
  
  if (!mounted) return;
  
  setState(() {
    _isListening = false;  // UI 업데이트 (파란색으로 복원)
  });
  
  await Future.delayed(const Duration(milliseconds: 100));  // 짧은 대기
  
  if (!mounted) return;
  
  if (text.isNotEmpty) {
    debugPrint('📤 제출: "$text"');
    widget.onSubmit(text);  // 게임 화면으로 제출
  }
}
```

### 3️⃣ 마이크 버튼 UI

```dart
// lib/widgets/speech_input_widget.dart (Line 261-330)
GestureDetector(
  onTapDown: widget.isDisabled ? null : (_) { _startListening(); },
  onTapUp: widget.isDisabled ? null : (_) { _stopListening(); },
  onTapCancel: widget.isDisabled ? null : () { _stopListening(); },
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    width: 70,
    height: 70,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        colors: widget.isDisabled
            ? [Colors.grey.shade300, Colors.grey.shade400]  // 비활성
            : _isListening
                ? [Colors.red.shade400, Colors.red.shade600]  // 빨강 (리스닝 중)
                : [Colors.blue.shade400, Colors.blue.shade600],  // 파랑 (준비)
      ),
      boxShadow: [
        BoxShadow(
          color: _isListening
              ? Colors.red.withValues(alpha: 0.4)
              : Colors.blue.withValues(alpha: 0.4),
          blurRadius: _isListening ? 15 : 10,
          spreadRadius: _isListening ? 3 : 2,
        ),
      ],
    ),
    child: Icon(
      _isListening ? Icons.mic : Icons.mic_none,
      color: Colors.white,
      size: 32,
    ),
  ),
)
```

---

## 📁 파일별 역할

### `lib/widgets/speech_input_widget.dart` (주요 UI)
- 📍 **역할**: 마이크 버튼 UI 및 입력 제어
- 🎯 **주요 메서드**:
  - `_startListening()` - 버튼 누를 때 음성인식 시작
  - `_stopListening()` - 버튼 떼기, 음성인식 중지 + 제출
  - `_initializeSpeech()` - 앱 시작 시 음성인식 초기화
- 🔄 **상태**:
  - `_isListening` - 현재 리스닝 여부
  - `_controller` - TextField 텍스트

### `lib/services/speech_service.dart` (백엔드)
- 📍 **역할**: 실제 음성인식 처리
- 🎯 **주요 메서드**:
  - `initialize()` - Google Speech API 초기화
  - `startListening()` - 마이크 활성화
  - `stopListening()` - 마이크 중지
  - `compareResult()` - 인식 결과와 정답 비교
- ⚙️ **설정**:
  ```dart
  listenFor: const Duration(seconds: 5)    // 최대 5초
  pauseFor: const Duration(seconds: 1)     // 1초 침묵 시 자동 중지
  partialResults: true                      // 실시간 피드백
  cancelOnError: false                      // 에러 발생 시 계속 시도
  ```

### `lib/utils/string_matcher.dart` (매칭 로직)
- 📍 **역할**: 인식된 텍스트와 정답 비교
- 🎯 **매칭 단계**:
  1. 정확한 일치 검사
  2. 띄어쓰기 무시 비교
  3. 한글 발음 정규화 (ㅐ/ㅔ 등 비슷한 발음)
  4. 유사도 계산 (Levenshtein distance)
- 📊 **결과**:
  - `perfect` - 완벽 (100점) ⭕
  - `close` - 양호 (50점) 🔺
  - `wrong` - 실패 (0점) ❌

### `lib/screens/advanced/advanced_screen.dart` (게임 로직)
- 📍 **역할**: 상급 게임에서 음성입력 연동
- 🎯 **콜백**:
  ```dart
  SpeechInputWidget(
    onTextChanged: (text) { /* 실시간 업데이트 */ },
    onSubmit: (text) { /* 답안 제출 */ },
    lastResult: _lastMatchResult,
    currentInput: _currentInput,
    isDisabled: _isSentenceLoading,  // 로딩 중이면 비활성
  )
  ```

---

## ⚙️ 설정 값 설명

### Speech Service 설정

```dart
// lib/services/speech_service.dart (Line 69-80)
await _speech.listen(
  onResult: (result) { /* 콜백 */ },
  localeId: 'ko_KR',                              // 한국어 (필수)
  partialResults: true,                           // 실시간 결과 표시
  cancelOnError: false,                           // 에러 발생 시 계속
  listenFor: const Duration(seconds: 5),          // ⏱️ 최대 인식 시간
  pauseFor: const Duration(seconds: 1),           // 🤐 침묵 감지 시간
);
```

### 🎙️ `listenFor: 5초`

- **의미**: 마이크 버튼을 눌렀을 때 **최대 5초까지만** 음성을 수신
- **용도**: 배터리 소비 및 과도한 리소스 사용 방지
- **실제 동작**: 대부분의 경우 사용자가 5초 전에 버튼을 떼기 때문에 작동 안 함
- **용도 예시**:
  ```
  리스닝 시작: 0초
  사용자가 "안녕하세요"라고 말함: 1초
  사용자가 버튼을 떼기: 1.5초 ← 여기서 중단 (5초보다 먼저)
  ```

### 🤐 `pauseFor: 1초`

- **의미**: 음성 입력이 **1초 이상 중단**되면 자동으로 음성인식 중지
- **용도**: 사용자가 버튼을 계속 누르고 있지만 더 이상 말하지 않는 경우 방지
- **실제 동작**: 대부분의 경우 사용자가 버튼을 떼기 때문에 작동 안 함
- **예외 상황**:
  ```
  시나리오 1: 사용자가 말하다 멈춤
  음성: "저는..." (0.5초) → [침묵] (1.5초)
  결과: 1초 침묵 감지 → 자동 중지 (사용자가 버튼 못 뗀 경우)
  
  시나리오 2: 사용자가 계속 말함
  음성: "저는 한국어를" (1.5초) → [짧은 쉼 0.5초] → "배우고 있습니다" (1.5초)
  결과: 1초 미만의 쉼이므로 계속 인식
  ```

### 🎯 `partialResults: true`

- **의미**: 사용자가 말하는 **동안** 실시간으로 인식 결과 표시
- **비활성화 시**: 사용자가 버튼을 떼고 **나서야** 결과가 표시됨 (답답함)
- **현재 동작**: ✅ 활성화 (최고의 UX)
  ```
  사용자: "안..." (말하는 중)
  화면: "안"이 TextField에 표시
  
  사용자: "안녕..." (계속 말함)
  화면: "안녕"으로 업데이트
  
  사용자: "안녕하세요" (완료)
  화면: "안녕하세요" 최종 표시
  ```

### 🚫 `cancelOnError: false`

- **의미**: 음성인식 중 에러 발생해도 **계속 인식 시도**
- **에러 예시**:
  - `error_network` - 네트워크 연결 실패
  - `error_audio` - 오디오 입력 에러
  - `error_no_match` - 음성은 들었는데 텍스트 변환 실패
- **현재 동작**: ✅ 활성화 (사용자가 다시 시도할 필요 없음)

---

## 🔄 상태 관리 흐름

```
초기 상태
    ├─ _isListening = false
    ├─ _controller.text = ""
    └─ 버튼 = 파란색 🔵

↓ 사용자가 마이크 버튼 누름 (onTapDown)

활성 상태
    ├─ _isListening = true
    ├─ 음성인식 시작
    └─ 버튼 = 빨간색 🔴

↓ 실시간으로 인식 결과 업데이트 (partialResults)

인식 중 상태
    ├─ TextField에 텍스트 표시
    ├─ _controller.text = "안녕..."
    └─ 버튼 = 여전히 빨간색 🔴

↓ 사용자가 마이크 버튼 떼기 (onTapUp)

중지 및 제출
    ├─ _stopListening() 호출
    ├─ 음성인식 즉시 중지
    ├─ _isListening = false
    ├─ onSubmit(text) 호출
    └─ 버튼 = 파란색으로 복원 🔵

↓ 게임 로직에서 매칭

결과 표시
    ├─ StringMatcher.match() 실행
    └─ 결과 피드백 (⭕ 완벽 / 🔺 아까워 / ❌ 다시)
```

---

## 💡 핵심 특징 정리

| 특징 | 구현 | 효과 |
|------|------|------|
| **Press & Hold** | `GestureDetector.onTapDown/Up` | 자연스러운 버튼 제어 |
| **실시간 피드백** | `partialResults: true` | 사용자가 말하는 동안 텍스트 표시 |
| **즉시 중지** | `_stopListening()` 호출 | 버튼 떼는 순간 즉시 제출 |
| **보조 안전장치** | `pauseFor: 1초` | 사용자가 버튼 못 떼는 경우 자동 중지 |
| **에러 복구** | `cancelOnError: false` | 에러 발생 시에도 계속 인식 |
| **한국어 완벽 지원** | `localeId: 'ko_KR'` | 한글 음성 100% 지원 |

---

## 🎮 게임별 적용

### 초급 (한글 글자)
- **입력 유형**: 개별 한글 자음/모음
- **매칭**: 정확한 일치
- **UI**: 마이크 버튼 + TextField

### 중급 (단어)
- **입력 유형**: 단어
- **매칭**: 발음 정규화 포함
- **UI**: 마이크 버튼 + TextField

### 상급 (문장)
- **입력 유형**: 문장 (여러 단어)
- **매칭**: 유사도 기반 (60% 이상 ≈ 근접)
- **UI**: 마이크 버튼 + TextField + 문장 학습 다이얼로그

---

## 📚 참고 파일

- `lib/widgets/speech_input_widget.dart` - UI 구현
- `lib/services/speech_service.dart` - 음성 처리
- `lib/utils/string_matcher.dart` - 텍스트 매칭
- `PAUSE_FOR_EXPLANATION.md` - pauseFor 상세 설명
- `SPEECH_RECOGNITION_TECH_STACK.md` - 기술 스택 문서

---

**마지막 검증**: 2024년 12월  
**상태**: ✅ 모든 기능 정상 작동 확인  
**한국어 지원**: ✅ 완벽 지원  
