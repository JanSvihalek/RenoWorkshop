import '../domain/entities/prijem.dart';

/// Zdroj příjmu vozidla. Plní ho tentýž zdroj jako zakázky.
abstract interface class PrijemDataSource {
  /// `GET /orders/{id}/intake`.
  Future<Prijem> prijemZakazky(String orderId);

  /// `PUT /orders/{id}/intake/items/{kod}` - vrací celý příjem.
  Future<Prijem> zmenPolozku(String orderId, String kod, ZmenaPolozky zmena);

  /// `POST /orders/{id}/intake/complete`.
  Future<Prijem> dokonciPrijem(String orderId);

  /// `DELETE /orders/{id}/intake/complete`.
  Future<Prijem> znovuOtevriPrijem(String orderId);
}

/// Checklist z papírového formuláře příjmu - pro ukázková data a testy.
/// V provozu je v databázi.
const vychoziChecklist = [
  PolozkaPrijmu(
    kod: 'sklo_sterace',
    nazev: 'FCE/poškození: stěrače, ostřikovače, čelní sklo',
  ),
  PolozkaPrijmu(
    kod: 'stk',
    nazev: 'Datum platnosti STK',
    typ: TypKontroly.datum,
  ),
  PolozkaPrijmu(kod: 'adblue', nazev: 'Množství AdBlue, ostřikovače'),
  PolozkaPrijmu(
    kod: 'cbs',
    nazev: 'CBS data (kontrola nadcházejícího) + přítomnost TA',
  ),
  PolozkaPrijmu(
    kod: 'osvetleni',
    nazev: 'Kontrola osvětlení: přední, zadní, SPZ',
  ),
  PolozkaPrijmu(kod: 'brzdy', nazev: 'Brzdy: destičky, kotouče, hadičky'),
  PolozkaPrijmu(
    kod: 'motor',
    nazev: 'Motor + převodovka: úniky kapalin, řemeny',
  ),
  PolozkaPrijmu(
    kod: 'napravy',
    nazev: 'Kontrola náprav + stav pneu + spodní kryty vozidla',
  ),
  PolozkaPrijmu(kod: 'kapaliny', nazev: 'Kapaliny: olej, chladicí kapalina'),
];

/// Příjem v paměti se stejnými pravidly jako server - pro ukázková data
/// a testy.
class PametovyPrijem {
  final Map<String, Prijem> _prijmy = {};

  Prijem nacti(String orderId) =>
      _prijmy[orderId] ?? const Prijem(polozky: vychoziChecklist);

  Prijem zmen(
    String orderId,
    String kod,
    ZmenaPolozky zmena, {
    String kdo = 'Jan Dvořák',
  }) {
    final prijem = nacti(orderId);
    if (prijem.jeDokoncen) {
      throw StateError('Příjem je dokončený. Pro úpravu ho znovu otevřete.');
    }
    final polozka = prijem.polozky.firstWhere((p) => p.kod == kod);
    final nova = prijem.sPolozkou(zmena.pouzij(polozka));
    return _prijmy[orderId] = Prijem(
      stav: StavPrijmu.rozpracovany,
      polozky: nova.polozky,
      zahajilKdo: prijem.zahajilKdo ?? kdo,
      zahajenoAt: prijem.zahajenoAt ?? DateTime.now(),
    );
  }

  Prijem dokonci(String orderId, {String kdo = 'Jan Dvořák'}) {
    final prijem = nacti(orderId);
    if (prijem.jeDokoncen) return prijem;
    if (prijem.chybi > 0) {
      throw StateError('Příjem nejde dokončit, chybí ${prijem.chybi} bodů.');
    }
    return _prijmy[orderId] = Prijem(
      stav: StavPrijmu.dokoncen,
      polozky: prijem.polozky,
      zahajilKdo: prijem.zahajilKdo,
      zahajenoAt: prijem.zahajenoAt,
      dokoncilKdo: kdo,
      dokoncenoAt: DateTime.now(),
    );
  }

  Prijem znovuOtevri(String orderId) {
    final prijem = nacti(orderId);
    if (!prijem.jeDokoncen) return prijem;
    return _prijmy[orderId] = Prijem(
      stav: StavPrijmu.rozpracovany,
      polozky: prijem.polozky,
      zahajilKdo: prijem.zahajilKdo,
      zahajenoAt: prijem.zahajenoAt,
    );
  }
}
