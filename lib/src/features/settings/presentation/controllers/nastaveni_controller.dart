import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/nastaveni_uloziste.dart';
import '../../domain/entities/nastaveni.dart';

/// Úložiště nastavení. V `main()` se přepíše tím, které sáhne do telefonu;
/// výchozí paměťové drží testy i případ, kdy se úložiště nepodaří otevřít.
final nastaveniUlozisteProvider = Provider<NastaveniUloziste>(
  (ref) => PametoveNastaveni(),
);

/// Nastavení aplikace. Čte se synchronně, takže první vykreslení už zná
/// zvolené téma a nic neblikne.
final nastaveniProvider = NotifierProvider<NastaveniController, Nastaveni>(
  NastaveniController.new,
);

class NastaveniController extends Notifier<Nastaveni> {
  @override
  Nastaveni build() => ref.watch(nastaveniUlozisteProvider).nacti();

  void zmenVzhled(RezimVzhledu vzhled) => _uloz(state.copyWith(vzhled: vzhled));

  void zmenSpoust(UmisteniSpouste spoust) =>
      _uloz(state.copyWith(spoust: spoust));

  void zmenVychoziUtvary(List<String> kody) =>
      _uloz(state.copyWith(vychoziUtvary: kody));

  void zmenVychoziPoradace(List<String> kody) =>
      _uloz(state.copyWith(vychoziPoradace: kody));

  void zmenVychoziZodpovedne(List<String> jmena) =>
      _uloz(state.copyWith(vychoziZodpovedni: jmena));

  /// [ids] `0` = zakázky bez zpracovatele, `-1` = já. Jména se drží jen
  /// k vybraným lidem.
  void zmenVychoziZpracovatele(List<int> ids, Map<int, String> jmena) => _uloz(
    state.copyWith(
      vychoziZpracovatele: ids,
      jmenaZpracovatelu: {
        for (final id in ids) id: ?(jmena[id] ?? state.jmenaZpracovatelu[id]),
      },
    ),
  );

  void zmenSloupce(NastaveniSloupcu sloupce) =>
      _uloz(state.copyWith(sloupce: sloupce));

  void zmenSlozkuFotek(String? slozka) => _uloz(
    slozka == null
        ? state.copyWith(zrusSlozkuFotek: true)
        : state.copyWith(slozkaFotek: slozka),
  );

  void zmenZobrazeniZakazek(ZobrazeniZakazek zobrazeni) =>
      _uloz(state.copyWith(zobrazeniZakazek: zobrazeni));

  void zmenUkladaniFotekDoZarizeni(bool ukladat) =>
      _uloz(state.copyWith(ukladatFotkyDoZarizeni: ukladat));

  void zmenSamoRozpoznaniSpz(bool zapnout) =>
      _uloz(state.copyWith(samoRozpoznatSpz: zapnout));

  void zmenSkrytUdaje(bool skryt) => _uloz(state.copyWith(skrytUdaje: skryt));

  void zmenUkazkovaData(bool zapnout) =>
      _uloz(state.copyWith(ukazkovaData: zapnout));

  /// Nastavení z účtu (po přihlášení) - uloží se i do telefonu.
  void prevezmiZUctu(Nastaveni nastaveni) => _uloz(nastaveni);

  void zrusVychoziFiltr() => _uloz(
    state.copyWith(
      vychoziPobocky: const [],
      vychoziStavyHelios: const [],
      vychoziUtvary: const [],
      vychoziPoradace: const [],
      vychoziZodpovedni: const [],
      vychoziZpracovatele: const [],
      jmenaZpracovatelu: const {},
    ),
  );

  /// Zápis do úložiště se nečeká: nastavení je drobnost a čekání na disk
  /// by se projevilo jako zpoždění přepínače pod prstem.
  void _uloz(Nastaveni nove) {
    state = nove;
    ref.read(nastaveniUlozisteProvider).uloz(nove);
  }
}
