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

/// „1 rok", „3 roky", „7 let".
String pocetLet(int n) =>
    '$n ${n == 1
        ? 'rok'
        : n >= 2 && n <= 4
        ? 'roky'
        : 'let'}';

/// Stáří v letech a měsících: „8 měsíců", „3 roky", „7 let 5 měsíců".
String rokyAMesice(int mesice) {
  final roky = mesice ~/ 12;
  final zbytek = mesice % 12;
  if (roky == 0) return pocetMesicu(mesice);
  return zbytek == 0
      ? pocetLet(roky)
      : '${pocetLet(roky)} ${pocetMesicu(zbytek)}';
}

/// „3. 5. 2019 · 7 let 5 měsíců" - datum a stáří vedle sebe. Registrace
/// v budoucnu je překlep v Heliosu, stáří se k ní nepíše.
String registraceSeStarim(
  DateTime registrace,
  DateTime dnes,
  String Function(DateTime) datum,
) {
  final stari = stariVMesicich(registrace, dnes);
  return stari < 0
      ? datum(registrace)
      : '${datum(registrace)} · ${rokyAMesice(stari)}';
}

/// „dnes", „včera", „před 3 dny", „před měsícem", „před 2 lety".
String predKolika(DateTime datum, DateTime dnes) {
  final dny = DateTime(
    dnes.year,
    dnes.month,
    dnes.day,
  ).difference(DateTime(datum.year, datum.month, datum.day)).inDays;
  if (dny < 0) return '';
  if (dny == 0) return 'dnes';
  if (dny == 1) return 'včera';
  if (dny < 30) return 'před $dny dny';
  final mesice = stariVMesicich(datum, dnes);
  if (mesice < 12) return mesice <= 1 ? 'před měsícem' : 'před $mesice měsíci';
  final roky = (mesice / 12).round();
  return roky == 1 ? 'před rokem' : 'před $roky lety';
}

/// „dnes", „zítra", „zbývají 3 dny", „zbývá 5 dní"; prošlý den prázdně.
String zbyvaDo(DateTime datum, DateTime dnes) {
  final dny = DateTime(
    datum.year,
    datum.month,
    datum.day,
  ).difference(DateTime(dnes.year, dnes.month, dnes.day)).inDays;
  if (dny < 0) return '';
  if (dny == 0) return 'dnes';
  if (dny == 1) return 'zítra';
  return dny <= 4 ? 'zbývají $dny dny' : 'zbývá $dny dní';
}
