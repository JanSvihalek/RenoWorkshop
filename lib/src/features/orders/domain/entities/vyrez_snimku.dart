import 'dart:math' as math;
import 'dart:ui';

/// Přepočet rámečku z obrazovky na výřez z pořízeného snímku.
///
/// Náhled kamery je na obrazovce zvětšený tak, aby ji vyplnil (`BoxFit.cover`),
/// takže se část obrazu ořízne a měřítko neodpovídá jedna ku jedné. Bez
/// přepočtu by se sejmula úplně jiná část fotky, než jakou má člověk
/// v rámečku.
abstract final class VyrezSnimku {
  /// Rozměr, do kterého se vloží náhled kamery, než ho `BoxFit.cover`
  /// roztáhne přes obrazovku.
  ///
  /// Kamera hlásí rozměr náhledu podle snímače, tedy na šířku. Na výšku
  /// se proto strany prohodí, na šířku ne - `CameraPreview` si obraz
  /// otáčí podle zařízení sám a do rámečku obráceného tvaru by se obraz
  /// vmáčkl, roztáhl a pak zvětšil. Tak vznikal přehnaný zoom na tabletu.
  ///
  /// Řídí se tvarem [plocha], ne tím, co hlásí kamera: na některých
  /// zařízeních hlásí rozměr už otočený.
  static Size velikostNahledu({
    required Size nahledKamery,
    required Size plocha,
  }) {
    final dlouha = math.max(nahledKamery.width, nahledKamery.height);
    final kratka = math.min(nahledKamery.width, nahledKamery.height);
    final naVysku = plocha.height >= plocha.width;
    return naVysku ? Size(kratka, dlouha) : Size(dlouha, kratka);
  }

  /// Vrátí obdélník ve **pixelech snímku**, který odpovídá [ramecek]
  /// nakreslenému přes náhled o velikosti [plocha].
  ///
  /// [snimek] je rozměr pořízené fotky. Výsledek je vždy uvnitř snímku;
  /// když by rámeček přesahoval, ořízne se.
  static Rect prepocti({
    required Size snimek,
    required Size plocha,
    required Rect ramecek,
  }) {
    if (snimek.isEmpty || plocha.isEmpty) return Offset.zero & snimek;

    // BoxFit.cover: použije se větší z měřítek, přebytek přeteče mimo obraz.
    final meritko = math.max(
      plocha.width / snimek.width,
      plocha.height / snimek.height,
    );
    final zobrazenaSirka = snimek.width * meritko;
    final zobrazenaVyska = snimek.height * meritko;

    // O kolik obraz přetéká na každé straně.
    final posunX = (zobrazenaSirka - plocha.width) / 2;
    final posunY = (zobrazenaVyska - plocha.height) / 2;

    final vyrez = Rect.fromLTRB(
      (ramecek.left + posunX) / meritko,
      (ramecek.top + posunY) / meritko,
      (ramecek.right + posunX) / meritko,
      (ramecek.bottom + posunY) / meritko,
    );

    return _oriznDoSnimku(vyrez, snimek);
  }

  static Rect _oriznDoSnimku(Rect vyrez, Size snimek) {
    final left = vyrez.left.clamp(0.0, snimek.width);
    final top = vyrez.top.clamp(0.0, snimek.height);
    final right = vyrez.right.clamp(left, snimek.width);
    final bottom = vyrez.bottom.clamp(top, snimek.height);
    return Rect.fromLTRB(left, top, right, bottom);
  }
}
