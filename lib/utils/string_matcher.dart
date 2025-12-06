import '../models/korean_data.dart';

class StringMatcher {
  // 두 문자열을 비교하여 일치도 판정
  static MatchResult match(String recognized, String correct) {
    // 공백 제거 및 소문자 변환
    final cleanRecognized = recognized.trim().toLowerCase();
    final cleanCorrect = correct.trim().toLowerCase();

    // 정확히 일치
    if (cleanRecognized == cleanCorrect) {
      return MatchResult.perfect;
    }

    // ✅ 띄어쓰기 무시 비교 (음성인식은 띄어쓰기를 다르게 인식할 수 있음)
    final noSpaceRecognized = cleanRecognized.replaceAll(' ', '');
    final noSpaceCorrect = cleanCorrect.replaceAll(' ', '');
    
    if (noSpaceRecognized == noSpaceCorrect) {
      return MatchResult.perfect;
    }

    // 한글 ㅐ/ㅔ 정규화 비교 (발음이 같음)
    final normalizedRecognized = _normalizeSimilarSounds(noSpaceRecognized);
    final normalizedCorrect = _normalizeSimilarSounds(noSpaceCorrect);
    
    if (normalizedRecognized == normalizedCorrect) {
      return MatchResult.perfect;
    }

    // 유사도 계산 (Levenshtein distance)
    final similarity = _calculateSimilarity(normalizedRecognized, normalizedCorrect);

    // ✅ 60% 이상 유사하면 close (문장은 더 관대하게)
    if (similarity >= 0.6) {
      return MatchResult.close;
    }

    return MatchResult.wrong;
  }
  
  // 발음이 유사한 한글 정규화 (ㅐ/ㅔ/ㅒ/ㅖ/ㅙ/ㅞ 등 모두 통일)
  static String _normalizeSimilarSounds(String text) {
    return text
        // ✅ 한글 ㅐ/ㅔ/ㅒ/ㅖ 계열 → 'ㅔ'로 통일
        .replaceAll('개', '게').replaceAll('걔', '게').replaceAll('계', '게')
        .replaceAll('내', '네').replaceAll('냬', '네').replaceAll('녜', '네')
        .replaceAll('대', '데').replaceAll('댸', '데').replaceAll('뎨', '데')
        .replaceAll('래', '레').replaceAll('럐', '레').replaceAll('례', '레')
        .replaceAll('매', '메').replaceAll('먜', '메').replaceAll('몌', '메')
        .replaceAll('배', '베').replaceAll('뱨', '베').replaceAll('볘', '베')
        .replaceAll('새', '세').replaceAll('섀', '세').replaceAll('셰', '세')
        .replaceAll('애', '에').replaceAll('얘', '에').replaceAll('예', '에')
        .replaceAll('재', '제').replaceAll('쟤', '제').replaceAll('졔', '제')
        .replaceAll('채', '체').replaceAll('챼', '체').replaceAll('쳬', '체')
        .replaceAll('캐', '케').replaceAll('컈', '케').replaceAll('켸', '케')
        .replaceAll('태', '테').replaceAll('턔', '테').replaceAll('톄', '테')
        .replaceAll('패', '페').replaceAll('퍠', '페').replaceAll('폐', '페')
        .replaceAll('해', '헤').replaceAll('햬', '헤').replaceAll('혜', '헤')
        
        // ✅ 한글 ㅙ/ㅞ → 'ㅙ'로 통일
        .replaceAll('왜', '왜').replaceAll('웨', '왜')
        .replaceAll('괘', '과').replaceAll('궤', '과')
        .replaceAll('꽈', '과').replaceAll('꿰', '과')
        
        // ✅ 로마자 ae/e/yae/ye → e 통일
        .replaceAll('gae', 'ge').replaceAll('gyae', 'ge').replaceAll('gye', 'ge')
        .replaceAll('nae', 'ne').replaceAll('nyae', 'ne').replaceAll('nye', 'ne')
        .replaceAll('dae', 'de').replaceAll('dyae', 'de').replaceAll('dye', 'de')
        .replaceAll('rae', 're').replaceAll('ryae', 're').replaceAll('rye', 're')
        .replaceAll('lae', 'le').replaceAll('lyae', 'le').replaceAll('lye', 'le')
        .replaceAll('mae', 'me').replaceAll('myae', 'me').replaceAll('mye', 'me')
        .replaceAll('bae', 'be').replaceAll('byae', 'be').replaceAll('bye', 'be')
        .replaceAll('sae', 'se').replaceAll('syae', 'se').replaceAll('sye', 'se')
        .replaceAll('ae', 'e').replaceAll('yae', 'e').replaceAll('ye', 'e')
        .replaceAll('jae', 'je').replaceAll('jyae', 'je').replaceAll('jye', 'je')
        .replaceAll('chae', 'che').replaceAll('chyae', 'che').replaceAll('chye', 'che')
        .replaceAll('kae', 'ke').replaceAll('kyae', 'ke').replaceAll('kye', 'ke')
        .replaceAll('tae', 'te').replaceAll('tyae', 'te').replaceAll('tye', 'te')
        .replaceAll('pae', 'pe').replaceAll('pyae', 'pe').replaceAll('pye', 'pe')
        .replaceAll('hae', 'he').replaceAll('hyae', 'he').replaceAll('hye', 'he')
        
        // ✅ 로마자 wae/we → wae 통일
        .replaceAll('we', 'wae')
        .replaceAll('gwae', 'gwa').replaceAll('gwe', 'gwa')
        .replaceAll('kwae', 'kwa').replaceAll('kwe', 'kwa');
  }

  // 여러 타겟 중에서 가장 매칭되는 것 찾기
  static Map<String, MatchResult>? findBestMatch(
    String recognized,
    List<String> targets,
  ) {
    if (targets.isEmpty) return null;

    String? bestMatch;
    MatchResult? bestResult;
    double bestScore = 0.0;

    for (final target in targets) {
      final result = match(recognized, target);
      final score = _calculateSimilarity(
        recognized.trim().toLowerCase(),
        target.trim().toLowerCase(),
      );

      // Perfect match를 찾으면 즉시 반환
      if (result == MatchResult.perfect) {
        return {target: result};
      }

      // Close match 중 가장 높은 점수
      if (result == MatchResult.close && score > bestScore) {
        bestMatch = target;
        bestResult = result;
        bestScore = score;
      }

      // Wrong이지만 가장 유사한 것 기록 (혹시 모를 경우를 위해)
      if (bestMatch == null && score > bestScore) {
        bestMatch = target;
        bestResult = result;
        bestScore = score;
      }
    }

    if (bestMatch != null && bestResult != null) {
      return {bestMatch: bestResult};
    }

    return null;
  }

  // Levenshtein distance 기반 유사도 계산 (0.0 ~ 1.0)
  static double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final distance = _levenshteinDistance(s1, s2);
    final maxLength = s1.length > s2.length ? s1.length : s2.length;

    return 1.0 - (distance / maxLength);
  }

  // Levenshtein distance 계산
  static int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;

    // 2D 배열 생성
    final matrix = List.generate(
      len1 + 1,
      (i) => List.filled(len2 + 1, 0),
    );

    // 초기화
    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    // 거리 계산
    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;

        matrix[i][j] = _min3(
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        );
      }
    }

    return matrix[len1][len2];
  }

  static int _min3(int a, int b, int c) {
    return a < b ? (a < c ? a : c) : (b < c ? b : c);
  }

  // 한글 자음/모음 분리 (선택적 기능)
  static bool containsKorean(String text) {
    final koreanRegex = RegExp(r'[ㄱ-ㅎㅏ-ㅣ가-힣]');
    return koreanRegex.hasMatch(text);
  }
}
