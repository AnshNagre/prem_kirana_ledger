import 'package:intl/intl.dart';

/// `₹` formatted using Indian digit grouping (e.g. ₹1,20,500), matching the
/// `toLocaleString('en-IN')` calls used throughout the original HTML file.
String formatRupees(num amount, {bool withSign = false}) {
  final formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  final formatted = formatter.format(amount.abs());
  if (!withSign) return formatted;
  if (amount > 0) return '+$formatted';
  if (amount < 0) return '-$formatted';
  return formatted;
}

/// Levenshtein edit distance between two strings.
int levenshteinDistance(String s1, String s2) {
  final len1 = s1.length;
  final len2 = s2.length;
  final dp = List.generate(len1 + 1, (_) => List<int>.filled(len2 + 1, 0));

  for (var i = 0; i <= len1; i++) dp[i][0] = i;
  for (var j = 0; j <= len2; j++) dp[0][j] = j;

  for (var i = 1; i <= len1; i++) {
    for (var j = 1; j <= len2; j++) {
      final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
      dp[i][j] = [
        dp[i - 1][j] + 1, // deletion
        dp[i][j - 1] + 1, // insertion
        dp[i - 1][j - 1] + cost, // substitution
      ].reduce((a, b) => a < b ? a : b);
    }
  }
  return dp[len1][len2];
}

/// Fuzzy name/phone matcher — direct substring first, then per-word
/// Levenshtein similarity fallback (mirrors `isFuzzyMatch` in the HTML app).
bool isFuzzyMatch(String name, String queryStr) {
  final normalizedName = name.toLowerCase().trim();
  final normalizedQuery = queryStr.toLowerCase().trim();

  if (normalizedQuery.isEmpty) return true;
  if (normalizedName.contains(normalizedQuery)) return true;
  if (normalizedQuery.length < 3) return false;

  final nameWords = normalizedName.split(RegExp(r'\s+'));
  final queryWords = normalizedQuery.split(RegExp(r'\s+'));

  return queryWords.every((qWord) {
    return nameWords.any((tWord) {
      if (tWord.contains(qWord)) return true;
      final distance = levenshteinDistance(qWord, tWord);
      final maxLength = [qWord.length, tWord.length].reduce((a, b) => a > b ? a : b);
      if (maxLength == 0) return false;
      final similarity = 1 - distance / maxLength;
      return similarity >= 0.6;
    });
  });
}
