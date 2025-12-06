import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/korean_data.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  List<HangulCharacter>? _consonants;
  List<HangulCharacter>? _vowels;
  List<HangulCharacter>? _singleCharacters;
  List<KoreanWord>? _words;
  List<KoreanSentence>? _sentences;

  // 자음 불러오기
  Future<List<HangulCharacter>> loadConsonants() async {
    if (_consonants != null) return _consonants!;

    final String data = await rootBundle.loadString('assets/data/consonants.json');
    final List<dynamic> jsonList = json.decode(data);
    _consonants = jsonList.map((json) => HangulCharacter.fromJson(json)).toList();
    return _consonants!;
  }

  // 모음 불러오기
  Future<List<HangulCharacter>> loadVowels() async {
    if (_vowels != null) return _vowels!;

    final String data = await rootBundle.loadString('assets/data/vowels.json');
    final List<dynamic> jsonList = json.decode(data);
    _vowels = jsonList.map((json) => HangulCharacter.fromJson(json)).toList();
    return _vowels!;
  }

  // 한 글자 문자 불러오기 (초급용)
  Future<List<HangulCharacter>> loadSingleCharacters() async {
    if (_singleCharacters != null) return _singleCharacters!;

    final String data = await rootBundle.loadString('assets/data/single_characters.json');
    final List<dynamic> jsonList = json.decode(data);
    _singleCharacters = jsonList.map((json) => HangulCharacter.fromJson(json)).toList();
    return _singleCharacters!;
  }

  // 단어 불러오기
  Future<List<KoreanWord>> loadWords() async {
    if (_words != null) return _words!;

    final String data = await rootBundle.loadString('assets/data/words.json');
    final List<dynamic> jsonList = json.decode(data);
    _words = jsonList.map((json) => KoreanWord.fromJson(json)).toList();
    return _words!;
  }

  // 문장 불러오기
  Future<List<KoreanSentence>> loadSentences() async {
    if (_sentences != null) return _sentences!;

    final String data = await rootBundle.loadString('assets/data/sentences.json');
    final List<dynamic> jsonList = json.decode(data);
    _sentences = jsonList.map((json) => KoreanSentence.fromJson(json)).toList();
    return _sentences!;
  }

  // 카테고리별 단어 필터링
  List<KoreanWord> getWordsByCategory(List<KoreanWord> words, String category) {
    return words.where((word) => word.category == category).toList();
  }

  // 카테고리별 문장 필터링
  List<KoreanSentence> getSentencesByCategory(List<KoreanSentence> sentences, String category) {
    return sentences.where((sentence) => sentence.category == category).toList();
  }
}
