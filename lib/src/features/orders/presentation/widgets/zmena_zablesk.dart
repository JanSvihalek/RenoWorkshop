import 'dart:async';

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/barvy_zmen.dart';
import '../../domain/entities/nova_zmena.dart';

/// Krátké rozsvícení změněného prvku v detailu („yellow fade", varianta G).
///
/// Detail si při otevření vezme seznam nových změn ([NovaZmena.polozky])
/// a každý změněný prvek - krok postupu, poznámka, závada, čip „Dílna" -
/// se jednou rozsvítí, třikrát pulzne a do pěti vteřin vybledne. Nic
/// trvalého nezůstane. Spustí se, až je prvek vidět; víc změn postupně.
/// Jako na webu (zakazky/ZablesZmeny.tsx).

/// Časování a vzhled na jednom místě.
abstract final class Zablesk {
  /// Celá doba od rozsvícení po úplné vyblednutí.
  static const delka = Duration(seconds: 5);

  /// Jeden pulz a kolik jich je.
  static const pulz = Duration(milliseconds: 1100);
  static const pulzu = 3;

  /// Rozestup mezi víc změnami naráz (shora dolů).
  static const rozestup = Duration(milliseconds: 300);

  /// Kolik prvku musí být vidět, aby se spustil.
  static const prah = 0.5;

  /// Jak dlouho svítí naplno, než začne blednout (podíl z [delka]).
  static const plnaCast = 0.35;

  /// O kolik překryv přesahuje prvek a jak je sytý.
  static const presah = 3.0;
  static const kryti = 0.22;

  /// Pulz: jak daleko se stín rozepne a jak sytý začíná.
  static const pulzRozpeti = 9.0;
  static const pulzKryti = 0.6;
}

/// Klíč prvku: `status:<id záznamu>`, `note:<id>`, `defect:<id>`, `dilna`.
///
/// Hodnota = čím se prvek změnil (druhy a záznamy) - podle ní se pozná, co
/// se už přehrálo: stejný krok s novou změnou (dokončení) se rozsvítí
/// znovu, totéž podruhé ne.
Map<String, String> kliceZmen(NovaZmena? zmena) {
  final klice = <String, String>{};
  void pridej(String klic, String cim) =>
      klice[klic] = [?klice[klic], cim].join(',');
  for (final p in zmena?.polozky ?? const <PolozkaZmeny>[]) {
    final cim = '${p.druh.klic}:${p.id}';
    pridej('${p.pole}:${p.id}', cim);
    if (p.pole == 'status') pridej('dilna', cim);
    if (p.zavadaId case final zavada?) pridej('defect:$zavada', cim);
  }
  return klice;
}

/// Nové změny detailu pro prvky uvnitř.
class ZmenyDetailu extends InheritedWidget {
  ZmenyDetailu({
    super.key,
    required this.zakazkaId,
    required NovaZmena? zmena,
    required super.child,
  }) : klice = kliceZmen(zmena);

  final String zakazkaId;
  final Map<String, String> klice;

  static ZmenyDetailu? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZmenyDetailu>();

  @override
  bool updateShouldNotify(ZmenyDetailu stary) =>
      stary.zakazkaId != zakazkaId ||
      stary.klice.toString() != klice.toString();
}

/// Obal prvku, který se rozsvítí se změnou [klic]. Překryv přesahuje
/// prvek o 3 px, nepřekáží kliknutí a nic neposune.
class ZmenaZablesk extends StatefulWidget {
  const ZmenaZablesk({
    super.key,
    required this.klic,
    required this.child,
    this.zaobleni = 8,
  });

  final String? klic;
  final Widget child;

  /// Zaoblení prvku - překryv ho kopíruje (+ přesah).
  final double zaobleni;

  /// Co se už přehrálo - po rebuildu ani znovuotevření se nespouští.
  static final Set<String> _prehrane = {};

  /// Kdy může začít další rozsvícení - postupně po [Zablesk.rozestup].
  static DateTime _dalsiStart = DateTime.fromMillisecondsSinceEpoch(0);

  static Duration _naplanuj() {
    final ted = DateTime.now();
    final start = _dalsiStart.isAfter(ted) ? _dalsiStart : ted;
    _dalsiStart = start.add(Zablesk.rozestup);
    return start.difference(ted);
  }

  /// Pro testy - začít s čistým štítem.
  @visibleForTesting
  static void obnov() {
    _prehrane.clear();
    _dalsiStart = DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  State<ZmenaZablesk> createState() => _ZmenaZableskState();
}

class _ZmenaZableskState extends State<ZmenaZablesk>
    with SingleTickerProviderStateMixin {
  AnimationController? _animace;
  Timer? _start;

  void _spust(String id) {
    if (ZmenaZablesk._prehrane.contains(id)) return;
    ZmenaZablesk._prehrane.add(id);
    _start = Timer(ZmenaZablesk._naplanuj(), () {
      if (!mounted) return;
      setState(() {
        _animace = AnimationController(vsync: this, duration: Zablesk.delka)
          ..addStatusListener((stav) {
            if (stav == AnimationStatus.completed && mounted) {
              // Hotovo - prvek vypadá úplně normálně, žádný ticker.
              setState(() {
                _animace?.dispose();
                _animace = null;
              });
            }
          })
          ..forward();
      });
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    _animace?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zmeny = ZmenyDetailu.of(context);
    final klic = widget.klic;
    final cim = klic == null ? null : zmeny?.klice[klic];
    final animace = _animace;
    if (animace != null) return _sPrekryvem(context, animace);
    if (cim == null) return widget.child;
    final id = '${zmeny!.zakazkaId}|$klic|$cim';
    if (ZmenaZablesk._prehrane.contains(id)) return widget.child;
    return VisibilityDetector(
      key: Key('zablesk-$id'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction >= Zablesk.prah && mounted) _spust(id);
      },
      child: widget.child,
    );
  }

  Widget _sPrekryvem(BuildContext context, AnimationController animace) {
    final akcent = context.barvyZmen.akcent;
    final bezAnimaci = MediaQuery.of(context).disableAnimations;
    final tmavy = context.isDarkMode;
    final pulzu = Zablesk.pulz * Zablesk.pulzu;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          left: -Zablesk.presah,
          top: -Zablesk.presah,
          right: -Zablesk.presah,
          bottom: -Zablesk.presah,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: animace,
              builder: (context, _) {
                final v = animace.value;
                // Bez animací jen lineárně vybledne, jinak nejdřív naplno
                // a pak plynule (easeIn) do ztracena.
                final sila = bezAnimaci
                    ? 1 - v
                    : v < Zablesk.plnaCast
                    ? 1.0
                    : 1 -
                          Curves.easeIn.transform(
                            (v - Zablesk.plnaCast) / (1 - Zablesk.plnaCast),
                          );
                final cas = Zablesk.delka * v;
                final faze = !bezAnimaci && cas < pulzu
                    ? (cas.inMicroseconds % Zablesk.pulz.inMicroseconds) /
                          Zablesk.pulz.inMicroseconds
                    : null;
                return DecoratedBox(
                  key: const Key('zablesk-prekryv'),
                  decoration: BoxDecoration(
                    color: akcent.withValues(alpha: Zablesk.kryti * sila),
                    // Multiply nechá text čitelný; na tmavém pozadí by
                    // zmizel, tam normálně.
                    backgroundBlendMode: tmavy ? null : BlendMode.multiply,
                    borderRadius: BorderRadius.circular(
                      widget.zaobleni + Zablesk.presah,
                    ),
                    boxShadow: faze == null
                        ? null
                        : [
                            BoxShadow(
                              color: akcent.withValues(
                                alpha: Zablesk.pulzKryti * (1 - faze) * sila,
                              ),
                              spreadRadius: Zablesk.pulzRozpeti * faze,
                            ),
                          ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
