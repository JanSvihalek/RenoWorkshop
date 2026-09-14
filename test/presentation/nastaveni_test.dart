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
        const Nastaveni(vzhled: RezimVzhledu.svetly, vychoziUtvar: '12100'),
      );

      // Nová instance nad týmiž daty = jako po restartu aplikace.
      final poRestartu = SharedPreferencesNastaveni(prefs).nacti();

      expect(poRestartu.vzhled, RezimVzhledu.svetly);
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

    test(
      'výchozí zodpovědná osoba přežije restart a po zrušení zmizí',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final uloziste = SharedPreferencesNastaveni(prefs);

        await uloziste.uloz(const Nastaveni(vychoziZodpovida: 'Eva Malá'));
        expect(
          SharedPreferencesNastaveni(prefs).nacti().vychoziZodpovida,
          'Eva Malá',
        );

        await uloziste.uloz(const Nastaveni());
        expect(prefs.getString('nastaveni.vychoziZodpovida'), isNull);
      },
    );

    test('zrušený útvar se z úložiště smaže', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final uloziste = SharedPreferencesNastaveni(prefs);

      await uloziste.uloz(const Nastaveni(vychoziUtvar: '12100'));
      await uloziste.uloz(const Nastaveni());

      expect(prefs.getString('nastaveni.vychoziUtvar'), isNull);
      expect(uloziste.nacti().vychoziUtvar, isNull);
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

    test('změna útvaru přepíše ten předchozí', () {
      final container = kontejner(
        PametoveNastaveni(const Nastaveni(vychoziUtvar: '12100')),
      );

      container.read(nastaveniProvider.notifier).zmenVychoziUtvar('11211');

      expect(container.read(nastaveniProvider).vychoziUtvar, '11211');
    });

    test('zrušení výchozího filtru smaže útvar', () {
      final container = kontejner(
        PametoveNastaveni(const Nastaveni(vychoziUtvar: '12100')),
      );

      container.read(nastaveniProvider.notifier).zrusVychoziFiltr();

      expect(container.read(nastaveniProvider).maVychoziFiltr, isFalse);
    });
  });
}
