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
  static const _klicPobocka = 'nastaveni.vychoziPobocka';
  static const _klicUtvar = 'nastaveni.vychoziUtvar';

  @override
  Nastaveni nacti() {
    return Nastaveni(
      vzhled: RezimVzhledu.zNazvu(_prefs.getString(_klicVzhled)),
      vychoziPobocka: _prazdneJakoNull(_prefs.getString(_klicPobocka)),
      vychoziUtvar: _prazdneJakoNull(_prefs.getString(_klicUtvar)),
    );
  }

  @override
  Future<void> uloz(Nastaveni nastaveni) async {
    await _prefs.setString(_klicVzhled, nastaveni.vzhled.name);
    await _ulozNeboSmaz(_klicPobocka, nastaveni.vychoziPobocka);
    await _ulozNeboSmaz(_klicUtvar, nastaveni.vychoziUtvar);
  }

  Future<void> _ulozNeboSmaz(String klic, String? hodnota) {
    // Prázdný řetězec by se při čtení tvářil jako vybraná pobočka.
    return hodnota == null || hodnota.isEmpty
        ? _prefs.remove(klic)
        : _prefs.setString(klic, hodnota);
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
