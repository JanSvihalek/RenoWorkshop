/// Kód vozidla vytažený z textu — VIN nebo SPZ.
enum DruhKodu {
  vin('VIN'),
  spz('SPZ');

  const DruhKodu(this.label);

  final String label;
}

class KodVozidla {
  const KodVozidla({required this.druh, required this.hodnota});

  final DruhKodu druh;
  final String hodnota;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KodVozidla && other.druh == druh && other.hodnota == hodnota);

  @override
  int get hashCode => Object.hash(druh, hodnota);

  @override
  String toString() => '${druh.label} $hodnota';
}

/// Vytažení VINu a SPZ z textu, který přečetl fotoaparát.
///
/// Rozpoznávání textu vrátí všechno, co na štítku je — nadpisy, čísla dílů,
/// typové označení. Užitečné z toho udělá až tvar: VIN i SPZ mají pravidla,
/// podle kterých se dají z toho balastu vybrat.
///
/// Vrací návrhy, ne jistotu. Poslední slovo má člověk, který si z nabídky
/// vybere — proto se raději nabídne víc možností než žádná.
abstract final class KodyZTextu {
  /// VIN má 17 znaků a **nikdy neobsahuje I, O ani Q** — právě proto, aby
  /// se nepletly s jedničkou a nulou. Toho se dá využít i obráceně: když
  /// rozpoznávání přečte O, je to skoro jistě nula.
  static const String _vinZnaky = 'A-HJ-NPR-Z0-9';

  static final RegExp _vin = RegExp('[$_vinZnaky]{17}');

  /// Najde v textu kódy vozidla. VIN je vždy první, protože u něj je
  /// jistota největší.
  static List<KodVozidla> najdi(String text) {
    final slova = text
        .toUpperCase()
        .split(RegExp(r'\s+'))
        .map((slovo) => slovo.replaceAll(RegExp('[^A-Z0-9]'), ''))
        .where((slovo) => slovo.isNotEmpty)
        .toList();

    final viny = _najdiViny(slova);
    final spz = _najdiSpz(slova, viny);

    return [
      for (final vin in viny) KodVozidla(druh: DruhKodu.vin, hodnota: vin),
      for (final znacka in spz) KodVozidla(druh: DruhKodu.spz, hodnota: znacka),
    ];
  }

  /// VIN se hledá po slovech, ne v celém slepeném textu — jinak by se
  /// „našel" přes hranici dvou nesouvisejících údajů, třeba na konci
  /// typového označení a začátku toho pravého.
  ///
  /// Rozpoznávání ale VIN často rozdělí, protože je na štítku vysázený
  /// s odstupy, takže se zkouší i spojení dvou a tří sousedních slov.
  static Set<String> _najdiViny(List<String> slova) {
    final nalezene = <String>{};

    for (var i = 0; i < slova.length; i++) {
      var spojene = '';
      for (var delka = 0; delka < 3 && i + delka < slova.length; delka++) {
        spojene += slova[i + delka];
        if (spojene.length < 17) continue;

        final opravene = _opravZamenu(spojene);
        if (spojene.length == 17) {
          if (_vin.stringMatch(opravene) == opravene) nalezene.add(opravene);
          break;
        }
        // Delší slovo může VIN obsahovat - třeba když se slepil s popiskem.
        final uvnitr = _vin.firstMatch(opravene);
        if (delka == 0 && uvnitr != null) nalezene.add(uvnitr.group(0)!);
        break;
      }
    }

    return nalezene;
  }

  static Set<String> _najdiSpz(List<String> slova, Set<String> viny) {
    final nalezene = <String>{};

    for (final slovo in slova) {
      if (!_vypadaJakoSpz(slovo)) continue;
      if (viny.any((vin) => vin.contains(slovo))) continue;
      nalezene.add(slovo);
    }

    return nalezene;
  }

  /// Uvnitř VINu nemůže být I, O ani Q, takže jde o záměnu za 1 a 0.
  /// Bez téhle opravy by špinavý štítek často nedal použitelný výsledek.
  static String _opravZamenu(String vin) =>
      vin.replaceAll('O', '0').replaceAll('Q', '0').replaceAll('I', '1');

  /// SPZ nemá jeden pevný tvar - v datech jsou `1BN320`, `8AE3055`
  /// i starší `AA155HR`. Pravidlem je proto jen délka a to, že se míchají
  /// písmena s číslicemi. Zbytek posoudí člověk, který si z nabídky vybere.
  static bool _vypadaJakoSpz(String slovo) {
    if (slovo.length < 5 || slovo.length > 8) return false;
    final maCislici = slovo.contains(RegExp(r'[0-9]'));
    final maPismeno = slovo.contains(RegExp(r'[A-Z]'));
    return maCislici && maPismeno;
  }
}
