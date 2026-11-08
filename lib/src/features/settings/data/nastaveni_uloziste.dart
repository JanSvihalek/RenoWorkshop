import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/nastaveni.dart';

/// Kam se ukládá nastavení aplikace.
///
/// Rozhraní zvlášť od implementace proto, aby šlo v testech použít paměť
/// místo úložiště telefonu.
abstract interface class NastaveniUloziste {
  Nastaveni nacti();

  Future<void> uloz(Nastaveni nastaveni);
}

/// Nastavení v úložišti telefonu.
///
/// Čte se **synchronně** z už načtené instance: téma musí být známé dřív,
/// než se vykreslí první obrazovka, jinak by appka blikla ze světlé do
/// tmavé. Načtení proto proběhne při startu v `main()`.
class SharedPreferencesNastaveni implements NastaveniUloziste {
  const SharedPreferencesNastaveni(this._prefs);

  final SharedPreferences _prefs;

  static const _klicVzhled = 'nastaveni.vzhled';
  static const _klicSpoust = 'nastaveni.spoust';
  // Starší verze měly ve výběru jednu hodnotu pod těmito klíči. Čtou se,
  // dokud nejsou uložené nové seznamy, a při uložení se smažou.
  static const _klicPobocka = 'nastaveni.vychoziPobocka';
  static const _klicStavHelios = 'nastaveni.vychoziStavHelios';
  static const _klicUtvar = 'nastaveni.vychoziUtvar';
  static const _klicPoradac = 'nastaveni.vychoziPoradac';
  static const _klicZodpovida = 'nastaveni.vychoziZodpovida';
  static const _klicZpracovatel = 'nastaveni.vychoziZpracovatel';
  static const _klicZpracovatelJmeno = 'nastaveni.vychoziZpracovatelJmeno';

  static const _klicPobocky = 'nastaveni.vychoziPobocky';
  static const _klicStavyHelios = 'nastaveni.vychoziStavyHelios';
  static const _klicUtvary = 'nastaveni.vychoziUtvary';
  static const _klicPoradace = 'nastaveni.vychoziPoradace';
  static const _klicZodpovedni = 'nastaveni.vychoziZodpovedni';
  static const _klicZpracovatele = 'nastaveni.vychoziZpracovatele';
  static const _klicJmenaZpracovatelu = 'nastaveni.jmenaZpracovatelu';
  static const _klicPoradiSloupcu = 'nastaveni.poradiSloupcu';
  static const _klicSkryteSloupce = 'nastaveni.skryteSloupce';
  static const _klicSlozkaFotek = 'nastaveni.slozkaFotek';
  static const _klicUkladatDoZarizeni = 'nastaveni.ukladatFotkyDoZarizeni';
  static const _klicZobrazeni = 'nastaveni.zobrazeniZakazek';
  static const _klicSamoRozpoznatSpz = 'nastaveni.samoRozpoznatSpz';
  static const _klicUkazkovaData = 'nastaveni.ukazkovaData';
  static const _klicSkrytUdaje = 'nastaveni.skrytUdaje';

  @override
  Nastaveni nacti() {
    return Nastaveni(
      vzhled: RezimVzhledu.zNazvu(_prefs.getString(_klicVzhled)),
      spoust: UmisteniSpouste.zNazvu(_prefs.getString(_klicSpoust)),
      vychoziPobocky: _seznam(_klicPobocky, _klicPobocka),
      vychoziStavyHelios: _seznam(_klicStavyHelios, _klicStavHelios),
      vychoziUtvary: _seznam(_klicUtvary, _klicUtvar),
      vychoziPoradace: _seznam(_klicPoradace, _klicPoradac),
      vychoziZodpovedni: _seznam(_klicZodpovedni, _klicZodpovida),
      vychoziZpracovatele: _zpracovatele(),
      jmenaZpracovatelu: _jmenaZpracovatelu(),
      sloupce: NastaveniSloupcu(
        poradi: _prefs.getStringList(_klicPoradiSloupcu) ?? const [],
        skryte: _prefs.getStringList(_klicSkryteSloupce) ?? const [],
      ),
      slozkaFotek: _prazdneJakoNull(_prefs.getString(_klicSlozkaFotek)),
      ukladatFotkyDoZarizeni: _prefs.getBool(_klicUkladatDoZarizeni) ?? false,
      samoRozpoznatSpz: _prefs.getBool(_klicSamoRozpoznatSpz) ?? false,
      zobrazeniZakazek: ZobrazeniZakazek.zNazvu(
        _prefs.getString(_klicZobrazeni),
      ),
      skrytUdaje: _prefs.getBool(_klicSkrytUdaje) ?? false,
      ukazkovaData: _prefs.getBool(_klicUkazkovaData) ?? false,
    );
  }

  @override
  Future<void> uloz(Nastaveni nastaveni) async {
    await _prefs.setString(_klicVzhled, nastaveni.vzhled.name);
    await _prefs.setString(_klicSpoust, nastaveni.spoust.name);
    for (final stary in [
      _klicPobocka,
      _klicStavHelios,
      _klicUtvar,
      _klicPoradac,
      _klicZodpovida,
      _klicZpracovatel,
      _klicZpracovatelJmeno,
    ]) {
      await _prefs.remove(stary);
    }
    await _prefs.setStringList(_klicPobocky, nastaveni.vychoziPobocky);
    await _prefs.setStringList(_klicStavyHelios, nastaveni.vychoziStavyHelios);
    await _prefs.setStringList(_klicUtvary, nastaveni.vychoziUtvary);
    await _prefs.setStringList(_klicPoradace, nastaveni.vychoziPoradace);
    await _prefs.setStringList(_klicZodpovedni, nastaveni.vychoziZodpovedni);
    await _prefs.setStringList(_klicZpracovatele, [
      for (final id in nastaveni.vychoziZpracovatele) '$id',
    ]);
    await _prefs.setStringList(_klicJmenaZpracovatelu, [
      for (final MapEntry(:key, :value) in nastaveni.jmenaZpracovatelu.entries)
        '$key|$value',
    ]);
    await _prefs.setStringList(_klicPoradiSloupcu, nastaveni.sloupce.poradi);
    await _prefs.setStringList(_klicSkryteSloupce, nastaveni.sloupce.skryte);
    await _ulozNeboSmaz(_klicSlozkaFotek, nastaveni.slozkaFotek);
    await _prefs.setBool(
      _klicUkladatDoZarizeni,
      nastaveni.ukladatFotkyDoZarizeni,
    );
    await _prefs.setString(_klicZobrazeni, nastaveni.zobrazeniZakazek.name);
    await _prefs.setBool(_klicSamoRozpoznatSpz, nastaveni.samoRozpoznatSpz);
    await _prefs.setBool(_klicSkrytUdaje, nastaveni.skrytUdaje);
    await _prefs.setBool(_klicUkazkovaData, nastaveni.ukazkovaData);
  }

  Future<void> _ulozNeboSmaz(String klic, String? hodnota) {
    // Prázdný řetězec by se při čtení tvářil jako vybraná pobočka.
    return hodnota == null || hodnota.isEmpty
        ? _prefs.remove(klic)
        : _prefs.setString(klic, hodnota);
  }

  /// Seznam z nového klíče, jinak jedna hodnota ze staré verze.
  List<String> _seznam(String klic, String staryKlic) {
    final seznam = _prefs.getStringList(klic);
    if (seznam != null) return seznam;
    final stara = _prazdneJakoNull(_prefs.getString(staryKlic));
    return stara == null ? const [] : [stara];
  }

  List<int> _zpracovatele() {
    final seznam = _prefs.getStringList(_klicZpracovatele);
    if (seznam != null) return [...seznam.map(int.tryParse).nonNulls];
    final stary = _prefs.getInt(_klicZpracovatel);
    return stary == null ? const [] : [stary];
  }

  Map<int, String> _jmenaZpracovatelu() {
    final seznam = _prefs.getStringList(_klicJmenaZpracovatelu);
    if (seznam == null) {
      final id = _prefs.getInt(_klicZpracovatel);
      final jmeno = _prazdneJakoNull(_prefs.getString(_klicZpracovatelJmeno));
      return id == null || jmeno == null ? const {} : {id: jmeno};
    }
    return {
      for (final radek in seznam)
        if (radek.indexOf('|') case final i when i > 0)
          ?int.tryParse(radek.substring(0, i)): radek.substring(i + 1),
    };
  }

  static String? _prazdneJakoNull(String? hodnota) =>
      hodnota == null || hodnota.isEmpty ? null : hodnota;
}

/// Nastavení jen v paměti - pro testy a pro případ, že by úložiště
/// telefonu nešlo otevřít. Appka pak funguje, jen si nic nezapamatuje.
class PametoveNastaveni implements NastaveniUloziste {
  PametoveNastaveni([this._nastaveni = const Nastaveni()]);

  Nastaveni _nastaveni;

  @override
  Nastaveni nacti() => _nastaveni;

  @override
  Future<void> uloz(Nastaveni nastaveni) async => _nastaveni = nastaveni;
}
