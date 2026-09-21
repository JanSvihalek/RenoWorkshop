import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

/// Jedna událost v logu: obrazovka, důležitý krok, nebo chyba.
@immutable
class Udalost {
  const Udalost({
    required this.cas,
    required this.nazev,
    this.jeChyba = false,
    this.obrazovka,
    this.zakazka,
    this.detail,
    this.text,
  });

  final DateTime cas;
  final String nazev;
  final bool jeChyba;
  final String? obrazovka;
  final String? zakazka;
  final String? detail;

  /// Text chyby a začátek výpisu zásobníku.
  final String? text;

  /// Tvar pro `POST /api/events`. Čas místní bez zóny, jako všude v API.
  Map<String, Object?> toJson() => {
    'at': cas.toIso8601String().substring(0, 19),
    'type': jeChyba ? 'error' : 'event',
    'name': nazev,
    'screen': ?obrazovka,
    'order': ?zakazka,
    'detail': ?detail,
    'error': ?text,
  };

  static Udalost? fromJson(Object? json) {
    if (json is! Map) return null;
    final cas = DateTime.tryParse(json['at'] as String? ?? '');
    final nazev = json['name'];
    if (cas == null || nazev is! String) return null;
    return Udalost(
      cas: cas,
      nazev: nazev,
      jeChyba: json['type'] == 'error',
      obrazovka: json['screen'] as String?,
      zakazka: json['order'] as String?,
      detail: json['detail'] as String?,
      text: json['error'] as String?,
    );
  }
}

/// Kam se dávka posílá - služba RenoWorkshop (`POST /api/events`).
abstract interface class OdesilaniUdalosti {
  Future<void> odesliUdalosti(
    List<Map<String, Object?>> udalosti, {
    required String zarizeni,
    String? verze,
  });
}

/// Kam se fronta uloží, aby přežila pád aplikace.
abstract interface class UlozisteLogu {
  String? nacti();
  Future<void> uloz(String? json);
}

class PametoveUlozisteLogu implements UlozisteLogu {
  String? _json;

  @override
  String? nacti() => _json;

  @override
  Future<void> uloz(String? json) async => _json = json;
}

/// „android 14 …", „ios 18.1 …" - kvůli chybám, které dělá jen jedno
/// zařízení.
String popisZarizeni() {
  final popis =
      '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  return popis.length > 200 ? popis.substring(0, 200) : popis;
}

/// Číslo zakázky z cesty obrazovky (`/orders/ZK-26-0418/fotky`,
/// `/prijem/ZK-26-0418`), jinak `null`.
String? zakazkaZCesty(String cesta) {
  final shoda = RegExp(r'^/(?:orders|prijem)/([^/?#]+)').firstMatch(cesta);
  if (shoda == null) return null;
  try {
    return Uri.decodeComponent(shoda.group(1)!);
  } on ArgumentError {
    return shoda.group(1);
  }
}

/// Log událostí aplikace - co se v telefonu dělo a kde spadlo.
///
/// Doplňuje log přístupů ve službě: ten vidí jen požadavky na server,
/// tenhle i obrazovky, focení, přihlášení, výpadky sítě a chyby aplikace.
/// Když technik nahlásí chybu, je z něj vidět, jak se k ní dostal.
///
/// Záznamy se sbírají do fronty a posílají po dávkách - jednou za minutu,
/// při odchodu z aplikace a po přihlášení. Bez přihlášení se neposílá nic
/// (služba by dávku odmítla); fronta počká. Chyba se hned ukládá i do
/// telefonu, ať přežije pád aplikace.
///
/// Hledaný text, obsah poznámek ani fotky se nezapisují - stejně jako
/// v logu přístupů.
class LogUdalosti {
  LogUdalosti({
    required OdesilaniUdalosti? Function() odesilani,
    required bool Function() prihlasen,
    required UlozisteLogu uloziste,
    String? Function()? verze,
    String? zarizeni,
    DateTime Function()? ted,
  }) : _odesilani = odesilani,
       _prihlasen = prihlasen,
       _uloziste = uloziste,
       _verze = verze ?? (() => null),
       _zarizeni = zarizeni ?? popisZarizeni(),
       _ted = ted ?? DateTime.now;

  /// Víc se v telefonu nedrží - při dlouhém výpadku sítě se zahazují
  /// nejstarší události, chyby až nakonec.
  static const maxFronta = 500;
  static const velikostDavky = 200;
  static const interval = Duration(minutes: 1);

  /// Od kolika čekajících se posílá hned, bez čekání na minutu.
  static const odeslatOd = 50;

  final OdesilaniUdalosti? Function() _odesilani;
  final bool Function() _prihlasen;
  final UlozisteLogu _uloziste;
  final String? Function() _verze;
  final String _zarizeni;
  final DateTime Function() _ted;

  final List<Udalost> _fronta = [];
  String? _obrazovka;
  String? _zakazka;
  bool _odesila = false;
  Timer? _casovac;
  AppLifecycleListener? _zivot;

  /// Co čeká na odeslání - pro testy a diagnostiku.
  List<Udalost> get fronta => List.unmodifiable(_fronta);

  /// Načte frontu uloženou při minulém běhu a spustí pravidelné odesílání.
  /// Volá se jednou v `main` - testy ho nevolají, ať nenechávají běžet
  /// časovače.
  void spust() {
    obnovZUloziste();
    _casovac ??= Timer.periodic(interval, (_) => odesli());
    _zivot ??= AppLifecycleListener(
      // Odchod z aplikace: uložit a poslat, dokud to jde - systém ji
      // pak může kdykoli ukončit.
      onHide: () {
        unawaited(_ulozit());
        unawaited(odesli());
      },
    );
  }

  void zastav() {
    _casovac?.cancel();
    _casovac = null;
    _zivot?.dispose();
    _zivot = null;
  }

  /// Přechod na jinou obrazovku (cesta routeru, bez query).
  void obrazovka(String cesta) {
    if (cesta == _obrazovka) return;
    _obrazovka = cesta;
    _zakazka = zakazkaZCesty(cesta);
    _pridej(
      Udalost(
        cas: _ted(),
        nazev: 'obrazovka',
        obrazovka: cesta,
        zakazka: _zakazka,
      ),
    );
  }

  /// Důležitý krok - přihlášení, focení, hledání v archivu…
  void udalost(String nazev, {String? detail, String? zakazka}) {
    _pridej(
      Udalost(
        cas: _ted(),
        nazev: nazev,
        obrazovka: _obrazovka,
        zakazka: zakazka ?? _zakazka,
        detail: detail,
      ),
    );
  }

  /// Chyba. Hned se uloží i do telefonu - aplikace po ní může spadnout.
  void chyba(
    String nazev,
    Object chyba, {
    StackTrace? zasobnik,
    String? detail,
    String? zakazka,
  }) {
    final radky = zasobnik?.toString().split('\n').take(15).join('\n');
    _pridej(
      Udalost(
        cas: _ted(),
        nazev: nazev,
        jeChyba: true,
        obrazovka: _obrazovka,
        zakazka: zakazka ?? _zakazka,
        detail: detail,
        text: [chyba.toString(), ?radky].join('\n'),
      ),
    );
    unawaited(_ulozit());
  }

  void _pridej(Udalost udalost) {
    _fronta.add(udalost);
    if (_fronta.length > maxFronta) {
      // Radši přijít o obrazovku než o chybu.
      final i = _fronta.indexWhere((u) => !u.jeChyba);
      _fronta.removeAt(i >= 0 ? i : 0);
    }
    if (_fronta.length >= odeslatOd) unawaited(odesli());
  }

  /// Pošle čekající záznamy. Nepovedené odeslání nevadí - fronta zůstane
  /// a zkusí se příště.
  Future<void> odesli() async {
    if (_odesila || _fronta.isEmpty || !_prihlasen()) return;
    final cil = _odesilani();
    if (cil == null) return;

    _odesila = true;
    final davka = _fronta.take(velikostDavky).toList();
    try {
      await cil.odesliUdalosti(
        [for (final u in davka) u.toJson()],
        zarizeni: _zarizeni,
        verze: _verze(),
      );
      final odeslane = Set<Udalost>.identity()..addAll(davka);
      _fronta.removeWhere(odeslane.contains);
      await _ulozit();
    } catch (_) {
      // Bez sítě nebo služba neběží - dávka počká ve frontě.
    } finally {
      _odesila = false;
    }
    // Zbylo víc než jedna dávka (dlouho bez sítě) - poslat i zbytek.
    if (_fronta.length >= velikostDavky) unawaited(odesli());
  }

  Future<void> _ulozit() async {
    try {
      await _uloziste.uloz(
        _fronta.isEmpty
            ? null
            : jsonEncode([for (final u in _fronta) u.toJson()]),
      );
    } catch (_) {
      // Úložiště telefonu selhalo - log kvůli tomu nesmí shodit aplikaci.
    }
  }

  /// Vrátí do fronty, co zůstalo neodeslané z minulého běhu (třeba
  /// chyba, po které aplikace spadla).
  void obnovZUloziste() {
    try {
      final json = _uloziste.nacti();
      if (json == null) return;
      final ulozene = [
        for (final polozka in jsonDecode(json) as List)
          ?Udalost.fromJson(polozka),
      ];
      _fronta.insertAll(0, ulozene);
      while (_fronta.length > maxFronta) {
        _fronta.removeAt(0);
      }
    } catch (_) {
      // Poškozená fronta z minula - začne se znovu.
    }
  }
}
