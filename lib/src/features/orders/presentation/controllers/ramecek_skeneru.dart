import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Strana rámečku, za kterou se táhne.
enum StranaRamecku { vlevo, vpravo, nahore, dole }

/// Rámeček skeneru a pravidla, jak se dá měnit.
///
/// Samostatně od obrazovky proto, že jde o počítání, ne o kreslení: meze
/// se dají ověřit testy, aniž by bylo potřeba zařízení s fotoaparátem.
///
/// Rozměry jsou v bodech obrazovky vztažené k [plocha]. Rámeček se z ní
/// nikdy nedostane a nikdy se nesmrskne pod čitelnou velikost — jinak by
/// mechanikovi zmizel pod prstem a nešel vrátit.
@immutable
class RamecekSkeneru {
  const RamecekSkeneru({required this.plocha, required this.obdelnik});

  /// Výchozí tvar: široký a nízký, protože VIN i SPZ jsou na jednom řádku.
  factory RamecekSkeneru.vychozi(Size plocha) {
    final sirka = plocha.width * 0.86;
    final vyska = math.min(plocha.width * 0.24, plocha.height * 0.6);

    return RamecekSkeneru(
      plocha: plocha,
      obdelnik: Rect.fromCenter(
        center: plocha.center(Offset.zero),
        width: sirka,
        height: vyska,
      ),
    );
  }

  final Size plocha;
  final Rect obdelnik;

  /// Aby rámeček zůstal chytitelný i po zmenšení na minimum.
  static const double minSirka = 120;
  static const double minVyska = 56;

  /// Kousek od kraje obrazovky - u samého okraje se za rámeček nedá vzít.
  static const double okraj = 16;

  /// Přepočet po otočení telefonu. Rámeček si zachová poměrnou velikost
  /// i polohu, místo aby skočil zpátky na výchozí.
  RamecekSkeneru sPlochou(Size nova) {
    if (nova == plocha) return this;
    if (plocha.isEmpty || nova.isEmpty) return RamecekSkeneru.vychozi(nova);

    final x = nova.width / plocha.width;
    final y = nova.height / plocha.height;

    return RamecekSkeneru(
      plocha: nova,
      obdelnik: Rect.fromLTRB(
        obdelnik.left * x,
        obdelnik.top * y,
        obdelnik.right * x,
        obdelnik.bottom * y,
      ),
    )._srovnany();
  }

  /// Posun jedné strany. Ostatní tři zůstávají, kde byly — tím se dá
  /// rámeček přizpůsobit štítku, který není uprostřed obrazovky.
  RamecekSkeneru tahni(StranaRamecku strana, Offset posun) {
    final r = obdelnik;

    final novy = switch (strana) {
      StranaRamecku.vlevo => Rect.fromLTRB(
        _mezi(r.left + posun.dx, okraj, r.right - minSirka),
        r.top,
        r.right,
        r.bottom,
      ),
      StranaRamecku.vpravo => Rect.fromLTRB(
        r.left,
        r.top,
        _mezi(r.right + posun.dx, r.left + minSirka, plocha.width - okraj),
        r.bottom,
      ),
      StranaRamecku.nahore => Rect.fromLTRB(
        r.left,
        _mezi(r.top + posun.dy, okraj, r.bottom - minVyska),
        r.right,
        r.bottom,
      ),
      StranaRamecku.dole => Rect.fromLTRB(
        r.left,
        r.top,
        r.right,
        _mezi(r.bottom + posun.dy, r.top + minVyska, plocha.height - okraj),
      ),
    };

    return RamecekSkeneru(plocha: plocha, obdelnik: novy);
  }

  /// Posun celého rámečku beze změny velikosti.
  RamecekSkeneru posunuty(Offset posun) {
    return RamecekSkeneru(
      plocha: plocha,
      obdelnik: obdelnik.shift(posun),
    )._srovnany();
  }

  /// Roztažení dvěma prsty kolem středu. Šířka a výška zvlášť, takže jde
  /// ze širokého proužku na VIN udělat vyšší rámeček na SPZ.
  RamecekSkeneru zvetseny({required double vodorovne, required double svisle}) {
    final sirka = _mezi(
      obdelnik.width * vodorovne,
      minSirka,
      plocha.width - 2 * okraj,
    );
    final vyska = _mezi(
      obdelnik.height * svisle,
      minVyska,
      plocha.height - 2 * okraj,
    );

    return RamecekSkeneru(
      plocha: plocha,
      obdelnik: Rect.fromCenter(
        center: obdelnik.center,
        width: sirka,
        height: vyska,
      ),
    )._srovnany();
  }

  /// Vrátí rámeček zpátky na obrazovku, když ho posun nebo otočení
  /// vystrčilo ven. Velikost zůstává, jen se přisune.
  RamecekSkeneru _srovnany() {
    var r = obdelnik;

    // Nejdřív velikost, pak poloha - u příliš velkého rámečku by se
    // jinak nedalo rozhodnout, kterou stranu přisunout.
    final sirka = math.min(
      r.width,
      math.max(minSirka, plocha.width - 2 * okraj),
    );
    final vyska = math.min(
      r.height,
      math.max(minVyska, plocha.height - 2 * okraj),
    );
    r = Rect.fromCenter(center: r.center, width: sirka, height: vyska);

    final dx = r.left < okraj
        ? okraj - r.left
        : math.min(0.0, plocha.width - okraj - r.right);
    final dy = r.top < okraj
        ? okraj - r.top
        : math.min(0.0, plocha.height - okraj - r.bottom);

    return RamecekSkeneru(plocha: plocha, obdelnik: r.shift(Offset(dx, dy)));
  }

  /// Omezení, které nespadne, když je horní mez pod dolní — na malé
  /// obrazovce se meze můžou překřížit a `clamp` by vyhodil chybu.
  static double _mezi(double hodnota, double dolni, double horni) =>
      horni <= dolni ? dolni : hodnota.clamp(dolni, horni);
}
