/// České skloňování počtů (1 zakázka / 2-4 zakázky / 5+ zakázek).
String czechPlural(
  int count, {
  required String one,
  required String few,
  required String many,
}) {
  if (count == 1) return one;
  if (count >= 2 && count <= 4) return few;
  return many;
}

/// "0 zakázek", "1 zakázka", "3 zakázky", "12 zakázek".
String orderCountLabel(int count) {
  final word = czechPlural(
    count,
    one: 'zakázka',
    few: 'zakázky',
    many: 'zakázek',
  );
  return '$count $word';
}
