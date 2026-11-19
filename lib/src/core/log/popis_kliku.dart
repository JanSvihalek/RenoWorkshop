import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Kliknutí do logu událostí (událost `klik`, drží se 14 dní).
///
/// [SledovaniKliku] obalí celou aplikaci a u každého klepnutí na ovládací
/// prvek zapíše jen obecně, na co se kliklo - `tlačítko`, `záložka`,
/// `pole`… K tomu log sám doplní obrazovku a číslo zakázky, na které
/// uživatel je. Nápisy prvků ani obsah obrazovky se nezapisují.
///
/// Nic se kvůli tomu nemusí doplňovat do jednotlivých obrazovek. Zátěž
/// je zanedbatelná: jeden průchod cestou klepnutí ve stromu widgetů, jen
/// při klepnutí (ne při posouvání).

/// Obalí aplikaci a klepnutí na ovládací prvky pošle do [onKlik].
class SledovaniKliku extends StatefulWidget {
  const SledovaniKliku({super.key, required this.onKlik, required this.child});

  final void Function(String druh) onKlik;
  final Widget child;

  @override
  State<SledovaniKliku> createState() => _SledovaniKlikuState();
}

class _SledovaniKlikuState extends State<SledovaniKliku> {
  /// Kde a kdy prst dosedl - klepnutí je jen krátké a bez posunu.
  final _dole = <int, (Offset, Duration)>{};

  static const _dlouhyStisk = Duration(milliseconds: 800);

  void _nahoru(PointerUpEvent e) {
    final dole = _dole.remove(e.pointer);
    if (dole == null) return;
    if ((e.position - dole.$1).distance > kTouchSlop) return;
    if (e.timeStamp - dole.$2 > _dlouhyStisk) return;
    try {
      // Strom je ještě před reakcí na klepnutí - onTap běží až po nás.
      final druh = druhKliku(
        context as Element,
        e.position,
        View.of(context).viewId,
      );
      if (druh != null) widget.onKlik(druh);
    } catch (_) {
      // Log nesmí shodit aplikaci.
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (e) => _dole[e.pointer] = (e.position, e.timeStamp),
    onPointerCancel: (e) => _dole.remove(e.pointer),
    onPointerUp: _nahoru,
    child: widget.child,
  );
}

const _tlacitko = 'tlačítko';
const _ikona = 'ikona';
const _polozka = 'položka';
const _prvek = 'prvek';
const _prepinac = 'přepínač';

String? _druhOvladani(Widget w) => switch (w) {
  TextField() => 'pole',
  IconButton() => _ikona,
  FloatingActionButton() || ButtonStyleButton() => _tlacitko,
  RawChip() => 'čip',
  Tab() => 'záložka',
  NavigationDestination() ||
  BottomNavigationBar() ||
  NavigationRail() => 'navigace',
  PopupMenuItem() => 'menu',
  DropdownMenuItem() => 'volba',
  DropdownButton() => 'výběr',
  SwitchListTile() ||
  CheckboxListTile() ||
  RadioListTile() ||
  Switch() ||
  Checkbox() ||
  Radio() => _prepinac,
  ListTile() => _polozka,
  _ => null,
};

bool _jeAktivni(Widget w) => switch (w) {
  InkResponse(:final onTap, :final onLongPress, :final onDoubleTap) =>
    onTap != null || onLongPress != null || onDoubleTap != null,
  GestureDetector(
    :final onTap,
    :final onTapUp,
    :final onTapDown,
    :final onLongPress,
    :final onDoubleTap,
  ) =>
    onTap != null ||
        onTapUp != null ||
        onTapDown != null ||
        onLongPress != null ||
        onDoubleTap != null,
  _ => _druhOvladani(w) != null,
};

/// Na co se v bodě [pozice] (globální souřadnice) kliklo - `tlačítko`,
/// `záložka`, `pole`… - nebo `null`, když to nebyl ovládací prvek
/// (text, prázdné místo). [koren] je obal celé aplikace.
String? druhKliku(Element koren, Offset pozice, int viewId) {
  final vysledek = HitTestResult();
  WidgetsBinding.instance.hitTestInView(vysledek, pozice, viewId);
  // Zasažené kreslení i všichni jeho rodiče - některé obaly (posun
  // přechodu stránky) se do výsledku klepnutí samy nezapisují.
  final zasazene = <Object>{};
  for (final e in vysledek.path) {
    Object? cil = e.target;
    while (cil != null && zasazene.add(cil)) {
      cil = cil is RenderObject ? cil.parent : null;
    }
  }

  // Cesta prvků od kořene k nejhlubšímu zasaženému. Ze sourozenců vede
  // jen ten, jehož kreslení klepnutí zasáhlo (při překryvu ten navrchu).
  final cesta = <Element>[];
  Element? ted = koren;
  while (ted != null) {
    cesta.add(ted);
    Element? dalsi;
    ted.visitChildElements((dite) {
      final ro = dite.renderObject;
      if (ro != null && zasazene.contains(ro)) dalsi = dite;
    });
    ted = dalsi;
  }

  final aktivni = cesta.lastIndexWhere((e) => _jeAktivni(e.widget));
  if (aktivni < 0) return null;

  // InkWell staví vlastní GestureDetector o tucet úrovní níž - hledá se
  // od InkWellu.
  var kotva = aktivni;
  if (cesta[aktivni].widget is GestureDetector) {
    for (var i = aktivni - 1; i >= 0 && i >= aktivni - 15; i--) {
      if (cesta[i].widget is InkResponse) {
        kotva = i;
        break;
      }
    }
  }

  // Nejbližší známý ovládací prvek nad místem klepnutí (tlačítko je kolem
  // svého InkWellu ještě asi 20 úrovní). Položka seznamu může být
  // přepínač (SwitchListTile) a vnitřní tlačítko ikona (IconButton) -
  // ty jsou o kousek výš.
  var druh = _prvek;
  var index = kotva;
  for (var i = cesta.length - 1; i >= 0 && i >= kotva - 30; i--) {
    if (druh == _polozka && i < index - 4) break;
    final d = _druhOvladani(cesta[i].widget);
    if (d == null) continue;
    if (druh == _prvek) {
      druh = d;
      index = i;
      if (d == _polozka) continue;
    } else if (d == _prepinac) {
      druh = d;
    }
    break;
  }
  if (druh == _tlacitko) {
    for (var i = index - 1; i >= 0 && i >= index - 6; i--) {
      if (cesta[i].widget is IconButton) return _ikona;
    }
  }
  return druh;
}
