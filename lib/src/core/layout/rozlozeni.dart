import 'package:flutter/widgets.dart';

/// Kdy se aplikace chová jako tablet.
///
/// Na dílně jsou dvě různá zařízení: telefon v ruce u auta a tablet
/// u stání. Tablet má místo na to, aby ukázal seznam i detail zároveň,
/// takže mechanik nemusí mezi nimi přepínat.
///
/// Hranice je na šířce, ne na typu zařízení: rozhoduje, kolik místa
/// aplikace dostane. Telefon na šířku zůstává telefonem — 840 bodů
/// nepřekročí ani ten největší.
abstract final class Rozlozeni {
  /// Od téhle šířky se vedle sebe vejde seznam i detail.
  static const double tabletOd = 840;

  /// Šířka seznamu zakázek v rozděleném zobrazení.
  ///
  /// Pevná, ne poměrová: seznam drží pořád stejné údaje, kdežto detail
  /// unese tím víc, čím je širší.
  static const double sirkaSeznamu = 380;

  /// Šířka svislého navigačního pruhu.
  static const double sirkaNavigace = 80;
}

extension RozlozeniContext on BuildContext {
  /// Vejde se vedle sebe seznam i detail?
  bool get jeTablet => MediaQuery.sizeOf(this).width >= Rozlozeni.tabletOd;
}
