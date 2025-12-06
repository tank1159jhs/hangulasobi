import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {
  static final ProgressService _instance = ProgressService._internal();
  factory ProgressService() => _instance;
  ProgressService._internal();

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // 틀린 단어 저장
  Future<void> addMissedWord(String word) async {
    await initialize();
    final missed = getMissedWords();
    if (!missed.contains(word)) {
      missed.add(word);
      await _prefs!.setStringList('missed_words', missed);
    }
  }

  // 틀린 단어 목록 가져오기
  List<String> getMissedWords() {
    return _prefs?.getStringList('missed_words') ?? [];
  }

  // 틀린 단어 제거 (성공했을 때)
  Future<void> removeMissedWord(String word) async {
    await initialize();
    final missed = getMissedWords();
    missed.remove(word);
    await _prefs!.setStringList('missed_words', missed);
  }

  // 틀린 단어 초기화
  Future<void> clearMissedWords() async {
    await initialize();
    await _prefs!.remove('missed_words');
  }

  // 레벨별 진행도 저장
  Future<void> setLevelProgress(String level, int progress) async {
    await initialize();
    await _prefs!.setInt('progress_$level', progress);
  }

  // 레벨별 진행도 가져오기
  int getLevelProgress(String level) {
    return _prefs?.getInt('progress_$level') ?? 0;
  }

  // 최고 점수 저장
  Future<void> setHighScore(String gameType, int score) async {
    await initialize();
    final currentHigh = getHighScore(gameType);
    if (score > currentHigh) {
      await _prefs!.setInt('high_score_$gameType', score);
    }
  }

  // 최고 점수 가져오기
  int getHighScore(String gameType) {
    return _prefs?.getInt('high_score_$gameType') ?? 0;
  }

  // 언어 설정 저장
  Future<void> setLanguage(String languageCode) async {
    await initialize();
    await _prefs!.setString('language', languageCode);
  }

  // 언어 설정 가져오기
  String getLanguage() {
    return _prefs?.getString('language') ?? 'ja'; // 기본값: 일본어
  }

  // 사운드 설정
  Future<void> setSoundEnabled(bool enabled) async {
    await initialize();
    await _prefs!.setBool('sound_enabled', enabled);
  }

  bool isSoundEnabled() {
    return _prefs?.getBool('sound_enabled') ?? true;
  }
}
