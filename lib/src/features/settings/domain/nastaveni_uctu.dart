/// Nastavení na účtu (`/me/settings`) - co si člověk nese mezi webem
/// a telefony: výchozí filtr zakázek, pohled plánovače, složku fotek
/// a úvodní záložku. Stejný tvar jako na webu (web/src/nastaveni/ucet.ts).
///
/// Klíče, kterým appka nerozumí (dílenský stav z webu je podle názvu, appka
/// filtruje podle kódu), se drží ze základu - appka je nepřepíše.
library;

import 'dart:convert';

import '../../orders/domain/entities/order_filter.dart';
import '../../plan/domain/prehled_planu.dart';
import 'entities/nastaveni.dart';

/// Pohled plánovače - pobočka, týden / 14 dní a filtr (bez hledání).
class PohledPlanu {
  const PohledPlanu({
    this.pobocka,
    this.tydnu = 1,
    this.filtr = const OrderFilter(),
    this.kodLaku,
    this.stavPlanu,
  });

  final String? pobocka;
  final int tydnu;
  final OrderFilter filtr;
  final String? kodLaku;
  final StavPlanuFiltr? stavPlanu;
}

/// Zpracovatel na účtu: `me`, `none`, nebo id.
String? zpracovatelDoUctu(int? id) => switch (id) {
  null => null,
  OrderFilter.ja => 'me',
  OrderFilter.nikdo => 'none',
  _ => '$id',
};

int? zpracovatelZUctu(Object? hodnota) => switch (hodnota) {
  'me' => OrderFilter.ja,
  'none' => OrderFilter.nikdo,
  final String id => int.tryParse(id),
  _ => null,
};

/// Do [zakladu] přepíše klíče, které appka zná ([znam]) - nastavené
/// hodnotou, nenastavené smaže. Ostatní klíče zůstanou.
Map<String, Object?> _prekryj(
  Map<String, Object?>? zaklad,
  Map<String, String?> znam,
) {
  final vysledek = {...?zaklad};
  for (final MapEntry(:key, :value) in znam.entries) {
    if (value == null || value.isEmpty) {
      vysledek.remove(key);
    } else {
      vysledek[key] = value;
    }
  }
  return vysledek;
}

String? _text(Map<String, Object?>? mapa, String klic) => switch (mapa?[klic]) {
  final String s when s.isNotEmpty => s,
  _ => null,
};

Map<String, Object?>? _mapa(Object? hodnota) =>
    hodnota is Map<String, Object?> ? hodnota : null;

/// Výchozí filtr zakázek na účet.
Map<String, Object?> filtrZakazekDoUctu(
  Nastaveni n,
  Map<String, Object?>? zaklad,
) {
  final assignee = zpracovatelDoUctu(n.vychoziZpracovatelId);
  return _prekryj(zaklad, {
    'branch': n.vychoziPobocka,
    'department': n.vychoziUtvar,
    'folder': n.vychoziPoradac,
    'heliosStatus': n.vychoziStavHelios,
    'responsible': n.vychoziZodpovida,
    'assignee': assignee,
    // Jméno jen u konkrétního člověka - aby šel ukázat, i když nemá zakázku.
    'assigneeName': assignee == null || assignee == 'me' || assignee == 'none'
        ? null
        : n.vychoziZpracovatelJmeno,
  });
}

/// Výchozí filtr zakázek z účtu do nastavení.
Nastaveni filtrZakazekZUctu(Nastaveni n, Map<String, Object?>? filtr) {
  final pobocka = _text(filtr, 'branch');
  final utvar = _text(filtr, 'department');
  final poradac = _text(filtr, 'folder');
  final stavHelios = _text(filtr, 'heliosStatus');
  final zodpovida = _text(filtr, 'responsible');
  final zpracovatel = zpracovatelZUctu(filtr?['assignee']);
  return n.copyWith(
    vychoziPobocka: pobocka,
    zrusPobocku: pobocka == null,
    vychoziUtvar: utvar,
    zrusUtvar: utvar == null,
    vychoziPoradac: poradac,
    zrusPoradac: poradac == null,
    vychoziStavHelios: stavHelios,
    zrusStavHelios: stavHelios == null,
    vychoziZodpovida: zodpovida,
    zrusZodpovida: zodpovida == null,
    vychoziZpracovatelId: zpracovatel,
    vychoziZpracovatelJmeno: switch (zpracovatel) {
      null => null,
      OrderFilter.ja => 'Já',
      OrderFilter.nikdo => 'Nikdo',
      // Bez jména (nastavil ho web) - jméno z telefonu, jen když jde
      // o téhož člověka.
      _ =>
        _text(filtr, 'assigneeName') ??
            (zpracovatel == n.vychoziZpracovatelId
                ? n.vychoziZpracovatelJmeno
                : null) ??
            'č. $zpracovatel',
    },
    zrusZpracovatele: zpracovatel == null,
  );
}

/// Pohled plánovače na účet.
Map<String, Object?> pohledDoUctu(PohledPlanu p, Map<String, Object?>? zaklad) {
  final f = p.filtr;
  return {
    'branch': p.pobocka,
    'weeks': p.tydnu == 2 ? 2 : 1,
    'filter': _prekryj(_mapa(zaklad?['filter']), {
      'department': f.departmentCode,
      'folder': f.poradacKod,
      'heliosStatus': f.heliosStav,
      'responsible': f.mechanicName,
      'assignee': zpracovatelDoUctu(f.zpracovatelId),
      'paintCode': p.kodLaku,
      'planStatus': p.stavPlanu?.name,
    }),
  };
}

/// Pohled plánovače z účtu. Hledaný text a e-mail pro „Já" zůstanou
/// z [filtru].
PohledPlanu pohledZUctu(Map<String, Object?>? ucet, OrderFilter filtr) {
  final f = _mapa(ucet?['filter']);
  final stav = _text(f, 'planStatus');
  return PohledPlanu(
    pobocka: _text(ucet, 'branch'),
    tydnu: ucet?['weeks'] == 2 ? 2 : 1,
    filtr: OrderFilter(
      departmentCode: _text(f, 'department'),
      poradacKod: _text(f, 'folder'),
      heliosStav: _text(f, 'heliosStatus'),
      mechanicName: _text(f, 'responsible'),
      zpracovatelId: zpracovatelZUctu(f?['assignee']),
      query: filtr.query,
      sort: filtr.sort,
      mujEmail: filtr.mujEmail,
    ),
    kodLaku: _text(f, 'paintCode'),
    stavPlanu: StavPlanuFiltr.values.where((s) => s.name == stav).firstOrNull,
  );
}

/// Co appka na účtu drží - klíče, kterým nerozumí, bere ze [zakladu].
Map<String, Object?> castiAplikace(
  Nastaveni n,
  PohledPlanu pohled,
  Map<String, Object?> zaklad,
) => {
  'ordersFilter': filtrZakazekDoUctu(n, _mapa(zaklad['ordersFilter'])),
  'planner': pohledDoUctu(pohled, _mapa(zaklad['planner'])),
  'photoFolder': n.slozkaFotek,
  'startTab': n.uvodniZalozka.name,
};

/// Nastavení z účtu do nastavení telefonu.
Nastaveni nastaveniZUctu(Nastaveni n, Map<String, Object?> ucet) {
  final s = filtrZakazekZUctu(n, _mapa(ucet['ordersFilter']));
  return s.copyWith(
    slozkaFotek: _text(ucet, 'photoFolder'),
    zrusSlozkuFotek: _text(ucet, 'photoFolder') == null,
    uvodniZalozka: switch (_text(ucet, 'startTab')) {
      final nazev? => UvodniZalozka.zNazvu(nazev),
      null => n.uvodniZalozka,
    },
  );
}

/// Klíče, které se oproti [puvodni] změnily.
Map<String, Object?> zmenyNastaveni(
  Map<String, Object?> puvodni,
  Map<String, Object?> nove,
) => {
  for (final MapEntry(:key, :value) in nove.entries)
    if (jsonEncode(value) != jsonEncode(puvodni[key])) key: value,
};
