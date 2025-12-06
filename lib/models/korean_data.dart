class HangulCharacter {
  final String character;
  final String pronunciation;
  final String romanization;
  final String sound;
  final String? meaning; // 선택적 필드

  HangulCharacter({
    required this.character,
    required this.pronunciation,
    required this.romanization,
    required this.sound,
    this.meaning,
  });

  factory HangulCharacter.fromJson(Map<String, dynamic> json) {
    return HangulCharacter(
      character: json['character'] as String,
      pronunciation: json['pronunciation'] as String,
      romanization: json['romanization'] as String,
      sound: json['sound'] as String? ?? json['meaning'] as String? ?? '',
      meaning: json['meaning'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'character': character,
      'pronunciation': pronunciation,
      'romanization': romanization,
      'sound': sound,
      if (meaning != null) 'meaning': meaning,
    };
  }
}

class KoreanWord {
  final String word;
  final Map<String, String> meaning;
  final String category;
  final String emoji;

  KoreanWord({
    required this.word,
    required this.meaning,
    required this.category,
    required this.emoji,
  });

  factory KoreanWord.fromJson(Map<String, dynamic> json) {
    return KoreanWord(
      word: json['word'] as String,
      meaning: Map<String, String>.from(json['meaning'] as Map),
      category: json['category'] as String,
      emoji: json['emoji'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'meaning': meaning,
      'category': category,
      'emoji': emoji,
    };
  }
}

class KoreanSentence {
  final String sentence;
  final Map<String, String> meaning;
  final String category;
  final String emoji;

  KoreanSentence({
    required this.sentence,
    required this.meaning,
    required this.category,
    required this.emoji,
  });

  factory KoreanSentence.fromJson(Map<String, dynamic> json) {
    return KoreanSentence(
      sentence: json['sentence'] as String,
      meaning: Map<String, String>.from(json['meaning'] as Map),
      category: json['category'] as String,
      emoji: json['emoji'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sentence': sentence,
      'meaning': meaning,
      'category': category,
      'emoji': emoji,
    };
  }
}

enum MatchResult {
  perfect,  // ⭕ 정확 일치
  close,    // 🔺 약간의 오차 허용
  wrong,    // ❌ 완전히 다름
}
