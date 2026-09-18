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

  void zmenVychoziUtvar(String? kodUtvaru) => _uloz(
    kodUtvaru == null
        ? state.copyWith(zrusUtvar: true)
        : state.copyWith(vychoziUtvar: kodUtvaru),
  );

  void zmenVychoziPoradac(String? kod) => _uloz(
    kod == null
        ? state.copyWith(zrusPoradac: true)
        : state.copyWith(vychoziPoradac: kod),
  );

  void zmenVychoziZodpovida(String? jmeno) => _uloz(
    jmeno == null
        ? state.copyWith(zrusZodpovida: true)
        : state.copyWith(vychoziZodpovida: jmeno),
  );

  void zmenSlozkuFotek(String? slozka) => _uloz(
    slozka == null
        ? state.copyWith(zrusSlozkuFotek: true)
        : state.copyWith(slozkaFotek: slozka),
  );

  void zmenZobrazeniZakazek(ZobrazeniZakazek zobrazeni) =>
      _uloz(state.copyWith(zobrazeniZakazek: zobrazeni));

  void zmenUkladaniFotekDoZarizeni(bool ukladat) =>
      _uloz(state.copyWith(ukladatFotkyDoZarizeni: ukladat));

  void zrusVychoziFiltr() => _uloz(
    state.copyWith(zrusUtvar: true, zrusPoradac: true, zrusZodpovida: true),
  );

  /// Zápis do úložiště se nečeká: nastavení je drobnost a čekání na disk
  /// by se projevilo jako zpoždění přepínače pod prstem.
  void _uloz(Nastaveni nove) {
    state = nove;
    ref.read(nastaveniUlozisteProvider).uloz(nove);
  }
}
