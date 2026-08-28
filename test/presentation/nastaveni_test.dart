import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/settings/data/nastaveni_uloziste.dart';
import 'package:renoworkshop/src/features/settings/domain/entities/nastaveni.dart';
import 'package:renoworkshop/src/features/settings/presentation/controllers/nastaveni_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('úložiště nastavení', () {
    test('co se uloží, to se po restartu načte', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final uloziste = SharedPreferencesNastaveni(prefs);

      await uloziste.uloz(
        const Nastaveni(
          vzhled: RezimVzhledu.svetly,
          vychoziPobocka: '12',
          vychoziUtvar: '12100',
        ),
      );

      // Nová instance nad týmiž daty = jako po restartu aplikace.
      final poRestartu = SharedPreferencesNastaveni(prefs).nacti();

      expect(poRestartu.vzhled, RezimVzhledu.svetly);
      expect(poRestartu.vychoziPobocka, '12');
      expect(poRestartu.vychoziUtvar, '12100');
    });

    test('prázdné úložiště dá výchozí nastavení', () async {
      SharedPreferences.setMockInitialValues({});
      final uloziste = SharedPreferencesNastaveni(
        await SharedPreferences.getInstance(),
      );

      expect(uloziste.nacti(), const Nastaveni());
    });

    test('neznámý zápis vzhledu spadne zpátky na systémový', () async {
      SharedPreferences.setMockInitialValues({'nastaveni.vzhled': 'duhovy'});
      final uloziste = SharedPreferencesNastaveni(
        await SharedPreferences.getInstance(),
      );

      expect(uloziste.nacti().vzhled, RezimVzhledu.podleSystemu);
    });

    test('zrušená pobočka se z úložiště smaže', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final uloziste = SharedPreferencesNastaveni(prefs);

      await uloziste.uloz(const Nastaveni(vychoziPobocka: '12'));
      await uloziste.uloz(const Nastaveni());

      expect(prefs.getString('nastaveni.vychoziPobocka'), isNull);
      expect(uloziste.nacti().vychoziPobocka, isNull);
    });
  });

  group('controller nastavení', () {
    ProviderContainer kontejner(NastaveniUloziste uloziste) {
      final container = ProviderContainer(
        overrides: [nastaveniUlozisteProvider.overrideWithValue(uloziste)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('změna vzhledu se propíše do úložiště', () async {
      final uloziste = PametoveNastaveni();
      final container = kontejner(uloziste);

      container.read(nastaveniProvider.notifier).zmenVzhled(RezimVzhledu.tmavy);

      expect(container.read(nastaveniProvider).vzhled, RezimVzhledu.tmavy);
      expect(uloziste.nacti().vzhled, RezimVzhledu.tmavy);
    });

    test('uložené nastavení je k dispozici hned při prvním čtení', () {
      final container = kontejner(
        PametoveNastaveni(const Nastaveni(vzhled: RezimVzhledu.svetly)),
      );

      expect(container.read(nastaveniProvider).vzhled, RezimVzhledu.svetly);
    });

    test('změna pobočky zahodí útvar z té předchozí', () {
      final container = kontejner(
        PametoveNastaveni(
          const Nastaveni(vychoziPobocka: '12', vychoziUtvar: '12100'),
        ),
      );

      container.read(nastaveniProvider.notifier).zmenVychoziPobocku('13');

      expect(container.read(nastaveniProvider).vychoziPobocka, '13');
      expect(container.read(nastaveniProvider).vychoziUtvar, isNull);
    });

    test('zrušení výchozího filtru smaže pobočku i útvar', () {
      final container = kontejner(
        PametoveNastaveni(
          const Nastaveni(vychoziPobocka: '12', vychoziUtvar: '12100'),
        ),
      );

      container.read(nastaveniProvider.notifier).zrusVychoziFiltr();

      expect(container.read(nastaveniProvider).maVychoziFiltr, isFalse);
    });
  });
}
