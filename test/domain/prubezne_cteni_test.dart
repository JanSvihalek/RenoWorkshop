import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/orders/data/prubezne_cteni.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/kod_vozidla.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/vyrez_snimku.dart';

/// Průběžné čtení SPZ bez spouště - části, které jdou ověřit bez kamery.
void main() {
  const spz = KodVozidla(druh: DruhKodu.spz, hodnota: '4Z49636');
  const jinaSpz = KodVozidla(druh: DruhKodu.spz, hodnota: '4Z49686');
  const vin = KodVozidla(druh: DruhKodu.vin, hodnota: 'WBAJN51070G980042');

  group('potvrzení SPZ', () {
    test('hledá se až po druhém stejném přečtení', () {
      final potvrzeni = PotvrzeniSpz();

      expect(potvrzeni.pridej([spz]), isNull);
      expect(potvrzeni.pridej([spz]), spz);
    });

    test('jiné přečtení počítání začne znovu', () {
      final potvrzeni = PotvrzeniSpz();

      expect(potvrzeni.pridej([spz]), isNull);
      // Rozmazaný snímek: 3 přečtená jako 8.
      expect(potvrzeni.pridej([jinaSpz]), isNull);
      expect(potvrzeni.pridej([spz]), isNull);
      expect(potvrzeni.pridej([spz]), spz);
    });

    test('snímek bez SPZ počítání nepřeruší', () {
      final potvrzeni = PotvrzeniSpz();

      expect(potvrzeni.pridej([spz]), isNull);
      expect(potvrzeni.pridej([]), isNull);
      expect(potvrzeni.pridej([spz]), spz);
    });

    test('VIN se sám nehledá - ten se fotí spouští', () {
      final potvrzeni = PotvrzeniSpz();

      expect(potvrzeni.pridej([vin]), isNull);
      expect(potvrzeni.pridej([vin]), isNull);
    });

    test('bere první SPZ - spojená slova mají přednost', () {
      final potvrzeni = PotvrzeniSpz();

      expect(potvrzeni.pridej([vin, spz, jinaSpz]), isNull);
      expect(potvrzeni.pridej([spz, jinaSpz]), spz);
    });

    test('po vynulování se počítá od začátku', () {
      final potvrzeni = PotvrzeniSpz()..pridej([spz]);
      potvrzeni.vynuluj();

      expect(potvrzeni.pridej([spz]), isNull);
    });
  });

  group('otočení snímku', () {
    const naSirku = Size(2000, 1390);
    const naVysku = Size(1390, 2000);

    test('iOS: snímek stejného tvaru jako obrazovka už je otočený', () {
      int? ios(Size snimek, Size plocha) => otoceniSnimku(
        ios: true,
        snimac: 90,
        zarizeni: DeviceOrientation.landscapeLeft,
        snimek: snimek,
        plocha: plocha,
      );

      // iPad na šířku - takhle to 6. 10. 2026 přišlo z iPadu.
      expect(ios(const Size(1280, 720), naSirku), 0);
      expect(ios(const Size(720, 1280), naVysku), 0);
      // Neotočený snímek ze snímače na výšku - otočení snímače.
      expect(ios(const Size(1280, 720), naVysku), 90);
    });

    test('Android odečte otočení zařízení', () {
      int? android(DeviceOrientation zarizeni, {bool predni = false}) =>
          otoceniSnimku(
            ios: false,
            snimac: 90,
            zarizeni: zarizeni,
            snimek: const Size(1280, 720),
            plocha: naVysku,
            predni: predni,
          );

      expect(android(DeviceOrientation.portraitUp), 90);
      expect(android(DeviceOrientation.landscapeLeft), 0);
      expect(android(DeviceOrientation.landscapeRight), 180);
      expect(android(DeviceOrientation.portraitDown), 270);
      // Přední kamera je zrcadlená - přičítá se.
      expect(android(DeviceOrientation.landscapeLeft, predni: true), 180);
    });

    test('na výšku se strany snímku prohodí', () {
      const snimek = Size(1280, 720);
      expect(vzprimenaVelikost(snimek, 90), const Size(720, 1280));
      expect(vzprimenaVelikost(snimek, 270), const Size(720, 1280));
      expect(vzprimenaVelikost(snimek, 0), snimek);
      expect(vzprimenaVelikost(snimek, 180), snimek);
    });
  });

  test('čte se jen text, jehož střed je v rámečku', () {
    const ramecek = Rect.fromLTWH(100, 300, 500, 150);
    final radky = [
      // SPZ v rámečku, rozdělená na dvě části.
      (const Rect.fromLTWH(150, 340, 180, 60), '4Z4'),
      (const Rect.fromLTWH(350, 340, 200, 60), '9636'),
      // Sousední vůz a nápis na stěně mimo rámeček.
      (const Rect.fromLTWH(700, 320, 200, 60), '1AB 2345'),
      (const Rect.fromLTWH(100, 50, 400, 40), 'SERVIS'),
      // Jen okrajem v rámečku - střed je venku.
      (const Rect.fromLTWH(560, 420, 300, 80), '5C6 7890'),
    ];

    expect(textVOblasti(radky, ramecek), '4Z4\n9636');
    expect(
      KodyZTextu.najdi(textVOblasti(radky, ramecek)).first,
      const KodVozidla(druh: DruhKodu.spz, hodnota: '4Z49636'),
    );
  });

  test('iPad na šířku: SPZ ze snímku padne do rámečku', () {
    // Situace z iPadu 6. 10. 2026: obrazovka na šířku, snímek 1280×720,
    // ML Kit přečetl SPZ i rámeček značky, rámeček zůstal prázdný.
    const plocha = Size(1180, 820);
    const ramecek = Rect.fromLTRB(39, 268, 1050, 550);
    const snimek = Size(1280, 720);

    final otoceni = otoceniSnimku(
      ios: true,
      snimac: 90,
      zarizeni: DeviceOrientation.landscapeLeft,
      snimek: snimek,
      plocha: plocha,
    )!;
    final oblast = sRezervou(
      VyrezSnimku.prepocti(
        snimek: vzprimenaVelikost(snimek, otoceni),
        plocha: plocha,
        ramecek: ramecek,
      ),
    );
    final radky = [
      // Kde je SPZ ve snímku, když je na obrazovce v rámečku.
      (const Rect.fromLTRB(386, 332, 858, 414), 'EL4 92AS'),
      // Nápis dealera na rámečku značky, taky v rámečku.
      (const Rect.fromLTRB(500, 425, 800, 450), 'BMW Renocar Brno - Slatina'),
    ];

    expect(
      KodyZTextu.najdi(textVOblasti(radky, oblast)).first,
      const KodVozidla(druh: DruhKodu.spz, hodnota: 'EL492AS'),
    );
  });
}
