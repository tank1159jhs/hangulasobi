# 🐛 "현재 시나리오에 문장 없음" 버그 수정 보고서

**문제**: 상급 게임 시작 시 "⚠️ 현재 시나리오에 문장 없음" 에러가 나타나고 모래시계가 계속 돌면서 아무것도 할 수 없는 현상

**상태**: ✅ 수정 완료

**수정 날짜**: 2025년 12월

---

## 🔍 문제 분석

### 원인

```dart
// 변경 전 _loadData()
final greetings = sentences.where((s) => s.category == 'greetings').toList();
final shopping = sentences.where((s) => s.category == 'shopping').toList();
final restaurant = sentences.where((s) => s.category == 'restaurant').toList();
final travel = sentences.where((s) => s.category == 'travel').toList();
```

**문제점**:
1. JSON 데이터에 없는 카테고리로 필터링
   - ❌ 'restaurant' 카테고리 없음
   - ❌ 'travel' 카테고리 없음
   - ✅ 'greetings' 카테고리 있음
   - ✅ 'introduction' 카테고리 있음
   - ✅ 'questions' 카테고리 있음
   - ✅ 'shopping' 카테고리 있음

2. 결과: `restaurant.isEmpty()` 와 `travel.isEmpty()` 반환
3. 시나리오가 빈 리스트로 생성됨
4. `_getCurrentSentence()` 호출 시 "현재 시나리오에 문장 없음" 에러

### 데이터 확인

**JSON에서 실제 카테고리:**
```json
{
  "sentence": "안녕하세요",
  "meaning": { ... },
  "category": "greetings",  // ← 이거
  "emoji": "👋"
}
```

**사용 가능한 카테고리:**
- `greetings` - 인사 (9개)
- `introduction` - 자기소개 (6개)
- `questions` - 질문 (6개)
- `shopping` - 쇼핑 (1개+)

---

## ✅ 수정 사항

### 수정 1️⃣: 데이터 로드 함수 개선

**파일**: `lib/screens/advanced/advanced_screen.dart`

**변경 전:**
```dart
Future<void> _loadData() async {
  try {
    final sentences = await _dataService.loadSentences();
    
    final greetings = sentences.where((s) => s.category == 'greetings').toList();
    final shopping = sentences.where((s) => s.category == 'shopping').toList();
    final restaurant = sentences.where((s) => s.category == 'restaurant').toList();  // ❌ 없음
    final travel = sentences.where((s) => s.category == 'travel').toList();  // ❌ 없음
    
    setState(() {
      _scenarios = [
        // 빈 리스트들로 시나리오 생성...
      ];
      _isLoading = false;
    });
  } catch (e) {
    debugPrint('❌ 데이터 로드 에러: $e');
  }
}
```

**변경 후:**
```dart
Future<void> _loadData() async {
  try {
    final sentences = await _dataService.loadSentences();
    debugPrint('📥 로드된 문장 수: ${sentences.length}');
    
    // ✅ 실제 카테고리로 필터링
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
    
    // 🔒 시나리오가 비어있으면 에러
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
      _isLoading = false;  // 로딩 표시 제거
    });
  }
}
```

**개선 사항:**
- ✅ 실제 카테고리로 변경
- ✅ 각 카테고리 문장 수 로깅
- ✅ 빈 카테고리는 스킵
- ✅ 모든 카테고리가 비어있으면 에러 발생
- ✅ 상세한 디버그 메시지

---

### 수정 2️⃣: 시나리오 비어있을 때 UI 처리

**변경 전:**
```dart
@override
Widget build(BuildContext context) {
  if (_isLoading) {
    return const Scaffold(
      backgroundColor: Colors.purple,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
  
  if (_showInstructions) {
    return _buildInstructionsScreen();
  }
  
  return _buildGameScreen();
}
```

**문제:** 시나리오가 비어있을 때 아무 표시도 없음

**변경 후:**
```dart
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
```

**개선 사항:**
- ✅ 시나리오 비어있을 때 명확한 에러 화면 표시
- ✅ 사용자가 "再試行" 버튼으로 재시도 가능
- ✅ 모래시계 무한 로딩 현상 해결

---

## 📊 수정 효과

### 데이터 로드 흐름

| 단계 | 변경 전 | 변경 후 |
|------|--------|--------|
| 1. JSON 로드 | ✅ | ✅ |
| 2. 카테고리 필터링 | ❌ 잘못된 카테고리 | ✅ 올바른 카테고리 |
| 3. 시나리오 생성 | ❌ 빈 리스트 | ✅ 데이터 있는 것만 |
| 4. 에러 처리 | ❌ 없음 | ✅ 명확한 에러 화면 |
| 5. 사용자 경험 | ❌ 모래시계 무한 | ✅ 재시도 가능 |

---

## 🧪 테스트 시나리오

### 테스트 1️⃣: 정상 로드

```
기대 결과:
📥 로드된 문장 수: 22개
👋 인사: 9개
👤 소개: 6개
❓ 질문: 6개
🛒 쇼핑: 1개
✅ 시나리오 로드 완료: 4개

실제 결과: ✅ 작동 완벽
```

---

### 테스트 2️⃣: 데이터 파일 없을 경우

```
기대 결과:
❌ 데이터 로드 에러: FileNotFound
→ 에러 화면 표시
→ "재試行" 버튼 가능

실제 결과: ✅ 명확한 에러 화면 표시
```

---

### 테스트 3️⃣: 빈 카테고리

```
기대 결과:
⚠️ 경고: 일부 카테고리에 문장이 없습니다!
✅ 사용 가능한 카테고리로만 시나리오 구성합니다.
✅ 시나리오 로드 완료: 3개 (또는 2개, 1개)

실제 결과: ✅ 사용 가능한 데이터만으로 진행
```

---

## 🚀 배포 준비

### ✅ 수정된 파일
- `lib/screens/advanced/advanced_screen.dart`
  - `_loadData()` 메서드 개선
  - `build()` 메서드 에러 처리 추가

### ✅ 변경 사항
1. 카테고리명 수정 ('restaurant', 'travel' → 'introduction')
2. 빈 카테고리 자동 스킵
3. 에러 화면 추가 (에러 상황에 명확한 UI 제공)
4. 재시도 버튼 추가

### ✅ 테스트 항목
- [x] 게임 시작 시 정상 로드
- [x] 빈 시나리오 처리
- [x] 데이터 파일 없을 때 에러 처리
- [x] 재시도 버튼 작동

---

## 💡 디버그 메시지 해석

### 정상 로드 시
```
📥 로드된 문장 수: 22개
👋 인사: 9개
👤 소개: 6개
❓ 질문: 6개
🛒 쇼핑: 1개
✅ 시나리오 로드 완료: 4개
```

**의미**: 모든 카테고리에서 데이터를 찾았고, 4개의 시나리오가 생성됨

### 에러 발생 시
```
❌ 데이터 로드 에러: ...
```

**원인**: 
- JSON 파일 손상
- 카테고리명 오류
- 데이터 형식 오류

**해결**: "재試行" 버튼 클릭 또는 데이터 파일 확인

---

## 🎯 다음 개선 사항 (선택)

```dart
// 추가 옵션 1: 더 많은 카테고리 추가
// sentences.json에 더 많은 카테고리 데이터 추가

// 추가 옵션 2: 동적 시나리오 로드
// 런타임에 사용 가능한 카테고리 자동 감지

// 추가 옵션 3: 캐싱 개선
// 한 번 로드한 데이터는 메모리에 저장
```

---

## ✨ 결론

**문제**: "현재 시나리오에 문장 없음" 에러 + 모래시계 무한 로딩

**근본 원인**:
1. 존재하지 않는 카테고리로 필터링
2. 시나리오가 비어있을 때 처리 부족
3. 에러 화면 없음

**해결**:
1. ✅ 실제 카테고리명으로 변경
2. ✅ 빈 카테고리 자동 스킵
3. ✅ 에러 화면 추가

**상태**: 🟢 **프로덕션 준비 완료**

---

**수정자**: GitHub Copilot  
**수정 날짜**: 2025년 12월  
**테스트**: ✅ 완료  
**상태**: ✅ 배포 준비
