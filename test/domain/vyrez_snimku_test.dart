import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/orders/domain/entities/vyrez_snimku.dart';

void main() {
  group('přepočet rámečku na výřez', () {
    test('stejný poměr stran: výřez odpovídá poměrné části snímku', () {
      // Náhled 400x800, snímek 800x1600 - dvojnásobek, nic se neořezává.
      final vyrez = VyrezSnimku.prepocti(
        snimek: const Size(800, 1600),
        plocha: const Size(400, 800),
        ramecek: const Rect.fromLTWH(100, 300, 200, 100),
      );

      expect(vyrez, const Rect.fromLTWH(200, 600, 400, 200));
    });

    test('širší snímek než plocha: počítá se s ořezem po stranách', () {
      // Snímek 2000x1000 na ploše 400x400. Měřítko podle výšky (0,4),
      // takže zobrazená šířka je 800 a po každé straně přetéká 200.
      final vyrez = VyrezSnimku.prepocti(
        snimek: const Size(2000, 1000),
        plocha: const Size(400, 400),
        ramecek: const Rect.fromLTWH(0, 0, 400, 400),
      );

      expect(vyrez.left, closeTo(500, 0.01));
      expect(vyrez.width, closeTo(1000, 0.01));
      expect(vyrez.top, closeTo(0, 0.01));
      expect(vyrez.height, closeTo(1000, 0.01));
    });

    test('rámeček přes celou plochu nevrátí nic mimo snímek', () {
      final vyrez = VyrezSnimku.prepocti(
        snimek: const Size(1000, 2000),
        plocha: const Size(300, 600),
        ramecek: const Rect.fromLTWH(-50, -50, 400, 700),
      );

      expect(vyrez.left, greaterThanOrEqualTo(0));
      expect(vyrez.top, greaterThanOrEqualTo(0));
      expect(vyrez.right, lessThanOrEqualTo(1000));
      expect(vyrez.bottom, lessThanOrEqualTo(2000));
    });

    test('nulové rozměry vrátí celý snímek, ne prázdný výřez', () {
      final vyrez = VyrezSnimku.prepocti(
        snimek: const Size(1000, 500),
        plocha: Size.zero,
        ramecek: const Rect.fromLTWH(0, 0, 10, 10),
      );

      expect(vyrez, const Rect.fromLTWH(0, 0, 1000, 500));
    });
  });
}
