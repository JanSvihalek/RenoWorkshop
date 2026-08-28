import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:renoworkshop/src/features/orders/presentation/controllers/ramecek_skeneru.dart';

void main() {
  const plocha = Size(400, 800);

  RamecekSkeneru vychozi() => RamecekSkeneru.vychozi(plocha);

  group('výchozí rámeček', () {
    test('je uprostřed, široký a nízký', () {
      final r = vychozi().obdelnik;

      expect(r.center, const Offset(200, 400));
      expect(r.width, closeTo(344, 0.01));
      expect(r.height, lessThan(r.width / 2));
    });

    test('se vejde na obrazovku', () {
      final r = vychozi().obdelnik;

      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(plocha.width));
    });
  });

  group('tažení za stranu', () {
    test('posune jen tu stranu, za kterou se táhne', () {
      final puvodni = vychozi().obdelnik;
      // Výchozí rámeček je od kraje jen kousek, takže krátké tažení.
      final r = vychozi().tahni(StranaRamecku.vlevo, const Offset(-10, 0));

      expect(r.obdelnik.left, closeTo(puvodni.left - 10, 0.01));
      expect(r.obdelnik.right, puvodni.right);
      expect(r.obdelnik.top, puvodni.top);
      expect(r.obdelnik.bottom, puvodni.bottom);
    });

    test('svislý posun levou stranou nehýbe', () {
      final puvodni = vychozi().obdelnik;
      final r = vychozi().tahni(StranaRamecku.vlevo, const Offset(0, 50));

      expect(r.obdelnik, puvodni);
    });

    test('nepustí stranu za okraj obrazovky', () {
      final r = vychozi().tahni(StranaRamecku.vlevo, const Offset(-500, 0));

      expect(r.obdelnik.left, RamecekSkeneru.okraj);
    });

    test('nedovolí rámeček užší než minimum', () {
      final r = vychozi().tahni(StranaRamecku.vpravo, const Offset(-1000, 0));

      expect(r.obdelnik.width, closeTo(RamecekSkeneru.minSirka, 0.01));
    });

    test('nedovolí rámeček nižší než minimum', () {
      final r = vychozi().tahni(StranaRamecku.dole, const Offset(0, -1000));

      expect(r.obdelnik.height, closeTo(RamecekSkeneru.minVyska, 0.01));
    });

    test('spodní strana se dá roztáhnout skoro přes celou výšku', () {
      final r = vychozi().tahni(StranaRamecku.dole, const Offset(0, 2000));

      expect(r.obdelnik.bottom, plocha.height - RamecekSkeneru.okraj);
    });

    test('tažení jde vrstvit - dvě strany po sobě', () {
      final r = vychozi()
          .tahni(StranaRamecku.nahore, const Offset(0, -40))
          .tahni(StranaRamecku.dole, const Offset(0, 40));

      expect(r.obdelnik.height, closeTo(vychozi().obdelnik.height + 80, 0.01));
    });
  });

  group('posun celého rámečku', () {
    test('zachová velikost', () {
      // Zúžený rámeček, aby bylo kam do stran uhnout - výchozí je skoro
      // přes celou šířku a ten se zboku posunout nedá.
      final zuzeny = vychozi().tahni(
        StranaRamecku.vpravo,
        const Offset(-150, 0),
      );
      final r = zuzeny.posunuty(const Offset(30, -60));

      expect(r.obdelnik.size, zuzeny.obdelnik.size);
      expect(r.obdelnik.center, zuzeny.obdelnik.center + const Offset(30, -60));
    });

    test('široký rámeček se do stran nemá kam hnout', () {
      final r = vychozi().posunuty(const Offset(200, 0));

      expect(r.obdelnik.size, vychozi().obdelnik.size);
      expect(
        r.obdelnik.right,
        closeTo(plocha.width - RamecekSkeneru.okraj, 0.01),
      );
    });

    test('nevystrčí rámeček z obrazovky', () {
      final r = vychozi().posunuty(const Offset(0, -5000));

      expect(r.obdelnik.top, closeTo(RamecekSkeneru.okraj, 0.01));
      expect(r.obdelnik.size, vychozi().obdelnik.size);
    });
  });

  group('roztažení dvěma prsty', () {
    test('mění šířku a výšku nezávisle', () {
      final puvodni = vychozi().obdelnik;
      final r = vychozi().zvetseny(vodorovne: 0.5, svisle: 2);

      expect(r.obdelnik.width, closeTo(puvodni.width * 0.5, 0.01));
      expect(r.obdelnik.height, closeTo(puvodni.height * 2, 0.01));
    });

    test('drží se v mezích obrazovky', () {
      final r = vychozi().zvetseny(vodorovne: 10, svisle: 10);

      expect(
        r.obdelnik.left,
        greaterThanOrEqualTo(RamecekSkeneru.okraj - 0.01),
      );
      expect(
        r.obdelnik.right,
        lessThanOrEqualTo(plocha.width - RamecekSkeneru.okraj + 0.01),
      );
      expect(
        r.obdelnik.bottom,
        lessThanOrEqualTo(plocha.height - RamecekSkeneru.okraj + 0.01),
      );
    });
  });

  group('otočení telefonu', () {
    test('zachová poměrnou velikost i polohu', () {
      final r = vychozi().sPlochou(const Size(800, 400));

      expect(r.plocha, const Size(800, 400));
      expect(r.obdelnik.center.dx, closeTo(400, 0.01));
      expect(r.obdelnik.center.dy, closeTo(200, 0.01));
      expect(r.obdelnik.width, closeTo(688, 0.01));
    });

    test('po zmenšení plochy zůstane rámeček uvnitř', () {
      final r = vychozi().sPlochou(const Size(200, 400));

      expect(
        r.obdelnik.left,
        greaterThanOrEqualTo(RamecekSkeneru.okraj - 0.01),
      );
      expect(
        r.obdelnik.right,
        lessThanOrEqualTo(200 - RamecekSkeneru.okraj + 0.01),
      );
    });
  });

  test('malá plocha nezpůsobí pád ani obrácené meze', () {
    final r = RamecekSkeneru.vychozi(
      const Size(60, 60),
    ).tahni(StranaRamecku.vlevo, const Offset(-100, 0));

    expect(r.obdelnik.width, greaterThan(0));
    expect(r.obdelnik.height, greaterThan(0));
  });
}
