/// Stáří vozu od první registrace v celých měsících - stejně, jak ho
/// počítá server pro FitServis+: měsíc se dovrší ve stejný den
/// (15. 10. 2022 -> 15. 10. 2026 je 48).
int stariVMesicich(DateTime registrace, DateTime dnes) {
  final mesice =
      (dnes.year - registrace.year) * 12 + (dnes.month - registrace.month);
  return dnes.day < registrace.day ? mesice - 1 : mesice;
}

/// „1 měsíc", „3 měsíce", „48 měsíců".
String pocetMesicu(int n) =>
    '$n ${n == 1
        ? 'měsíc'
        : n >= 2 && n <= 4
        ? 'měsíce'
        : 'měsíců'}';

/// „3. 5. 2019 · 89 měsíců" - datum a stáří vedle sebe. Registrace
/// v budoucnu je překlep v Heliosu, stáří se k ní nepíše.
String registraceSeStarim(
  DateTime registrace,
  DateTime dnes,
  String Function(DateTime) datum,
) {
  final stari = stariVMesicich(registrace, dnes);
  return stari < 0
      ? datum(registrace)
      : '${datum(registrace)} · ${pocetMesicu(stari)}';
}
