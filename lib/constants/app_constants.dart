import 'package:flutter/material.dart';

// 앱 전역 상수

// 색상
class AppColors {
  static const Color beginnerPrimary = Colors.pink;
  static const Color intermediatePrimary = Colors.blue;
  static const Color advancedPrimary = Colors.purple;

  static Color beginnerShade(int shade) => Colors.pink.withValues(alpha: shade / 1000);
  static Color intermediateShade(int shade) => Colors.blue.withValues(alpha: shade / 1000);
  static Color advancedShade(int shade) => Colors.purple.withValues(alpha: shade / 1000);
}

// 게임 설정
class GameConfig {
  // 게임별 문장 개수 (시나리오당)
  static const int scenarioSentenceCount = 5;
  
  // 채점
  static const int perfectPoints = 100;
  static const int goodPoints = 50;
  static const double similarityThreshold = 0.6;
  
  // 타이밍 (milliseconds)
  static const Duration feedbackDuration = Duration(milliseconds: 1500);
  static const Duration navigationDuration = Duration(milliseconds: 300);
  static const Duration animationDuration = Duration(milliseconds: 500);
}

// 발음 가이드 카테고리
class HangulCategories {
  static const String consonants = 'consonants';
  static const String vowels = 'vowels';
}

// 카테고리별 일본어 이름 (문장 학습용)
class SentenceCategoryNames {
  static const Map<String, String> names = {
    'all': '全て',
    'greetings': '挨拶',
    'shopping': '買い物',
    'restaurant': 'レストラン',
    'directions': '道案内',
    'feelings': '気持ち',
    'communication': 'コミュニケーション',
    'learning': '学習',
    'entertainment': 'エンターテイメント',
    'activities': 'アクティビティ',
    'daily_life': '日常生活',
    'family': '家族',
  };

  static String get(String key) => names[key] ?? key;
}

// 폰트 크기
class FontSizes {
  static const double gameTitleLarge = 28;
  static const double dialogTitle = 22;
  static const double buttonText = 20;
  static const double instructionText = 18;
  static const double itemTitle = 18;
  static const double itemSubtitle = 14;
  static const double smallLabel = 10;
}

// 여백
class Spacing {
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 15);
  static const EdgeInsets largePadding = EdgeInsets.all(24);
  static const EdgeInsets mediumPadding = EdgeInsets.all(20);
  static const EdgeInsets smallPadding = EdgeInsets.all(16);
}

// 보더 반경
class AppBorderRadius {
  static const double button = 30;
  static const double card = 20;
  static const double dialog = 20;
}
