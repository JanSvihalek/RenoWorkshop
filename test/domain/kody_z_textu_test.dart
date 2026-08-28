import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/kod_vozidla.dart';

void main() {
  group('VIN', () {
    test('najde se ve výpisu ze štítku', () {
      // Přesně takhle vypadá text ze štítku pod kapotou.
      const text = '''
BMW AG
TYP: 7K51
FIN WBAJN51070G980042
ZUL. GES. GEW. 2100 KG
''';

      final kody = KodyZTextu.najdi(text);

      expect(
        kody.first,
        const KodVozidla(druh: DruhKodu.vin, hodnota: 'WBAJN51070G980042'),
      );
    });

    test('poskládá se i když ho rozpoznávání rozdělí mezerami', () {
      final kody = KodyZTextu.najdi('WBAJN510 70G98 0042');

      expect(
        kody.any(
          (k) => k.druh == DruhKodu.vin && k.hodnota == 'WBAJN51070G980042',
        ),
        isTrue,
      );
    });

    test('záměna O za nulu se opraví, VIN písmeno O neobsahuje', () {
      // Rozpoznávání ze špinavého štítku vrací O místo 0.
      final kody = KodyZTextu.najdi('WBAJN51O7OG98OO42');

      expect(
        kody.first,
        const KodVozidla(druh: DruhKodu.vin, hodnota: 'WBAJN51070G980042'),
      );
    });

    test('kratší ani delší řetězec se za VIN nepovažuje', () {
      expect(
        KodyZTextu.najdi('WBAJN51070G98004').any((k) => k.druh == DruhKodu.vin),
        isFalse,
      );
    });
  });

  group('SPZ', () {
    test('najde běžné i starší tvary', () {
      for (final spz in ['1BN320', '8AE3055', 'AA155HR', '2BK9485']) {
        final kody = KodyZTextu.najdi('registrační značka $spz');
        expect(
          kody.any((k) => k.druh == DruhKodu.spz && k.hodnota == spz),
          isTrue,
          reason: 'nenašlo $spz',
        );
      }
    });

    test('samotné číslo ani slovo se za SPZ nepovažuje', () {
      final kody = KodyZTextu.najdi('12345 SERVIS 2026');

      expect(kody.where((k) => k.druh == DruhKodu.spz), isEmpty);
    });

    test('část VINu se jako SPZ nenabídne', () {
      final kody = KodyZTextu.najdi('WBAJN51070G980042');

      expect(kody, hasLength(1));
      expect(kody.single.druh, DruhKodu.vin);
    });
  });

  test('VIN je v nabídce první, je u něj největší jistota', () {
    final kody = KodyZTextu.najdi('1BN320 WBAJN51070G980042');

    expect(kody.first.druh, DruhKodu.vin);
    expect(kody.map((k) => k.druh), contains(DruhKodu.spz));
  });
}
