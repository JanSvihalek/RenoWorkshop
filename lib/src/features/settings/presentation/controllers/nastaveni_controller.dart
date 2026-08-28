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

  /// Změna pobočky ruší útvar - útvary jsou pod pobočkou a ten starý by
  /// na nové pobočce neexistoval.
  void zmenVychoziPobocku(String? kodPobocky) => _uloz(
    kodPobocky == null
        ? state.copyWith(zrusPobocku: true)
        : state.copyWith(vychoziPobocka: kodPobocky, zrusUtvar: true),
  );

  void zmenVychoziUtvar(String? kodUtvaru) => _uloz(
    kodUtvaru == null
        ? state.copyWith(zrusUtvar: true)
        : state.copyWith(vychoziUtvar: kodUtvaru),
  );

  void zrusVychoziFiltr() => _uloz(state.copyWith(zrusPobocku: true));

  /// Zápis do úložiště se nečeká: nastavení je drobnost a čekání na disk
  /// by se projevilo jako zpoždění přepínače pod prstem.
  void _uloz(Nastaveni nove) {
    state = nove;
    ref.read(nastaveniUlozisteProvider).uloz(nove);
  }
}
