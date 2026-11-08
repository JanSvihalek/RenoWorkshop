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
    this.kodLaku = const {},
    this.stavPlanu = const {},
  });

  final String? pobocka;
  final int tydnu;
  final OrderFilter filtr;
  final Set<String> kodLaku;
  final Set<StavPlanuFiltr> stavPlanu;
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

/// Do [zakladu] přepíše klíče, které appka zná ([znam]) - jedna hodnota
/// jako text (rozumí jí i starší verze), víc jako seznam, žádná klíč smaže.
/// Ostatní klíče zůstanou.
Map<String, Object?> _prekryj(
  Map<String, Object?>? zaklad,
  Map<String, Iterable<String>> znam,
) {
  final vysledek = {...?zaklad};
  for (final MapEntry(:key, :value) in znam.entries) {
    final hodnoty = value.where((h) => h.isNotEmpty).toList();
    if (hodnoty.isEmpty) {
      vysledek.remove(key);
    } else {
      vysledek[key] = hodnoty.length == 1 ? hodnoty.single : hodnoty;
    }
  }
  return vysledek;
}

/// Výběr z účtu: text (jedna hodnota) i seznam.
List<String> _seznam(Map<String, Object?>? mapa, String klic) =>
    switch (mapa?[klic]) {
      final String s when s.isNotEmpty => [s],
      final List<Object?> l => [
        for (final h in l)
          if (h is String && h.isNotEmpty) h,
      ],
      _ => const [],
    };

List<int> _zpracovateleZUctu(Map<String, Object?>? mapa) => [
  ...switch (mapa?['assignee']) {
    final List<Object?> l => l,
    final hodnota => [hodnota],
  }.map(zpracovatelZUctu).nonNulls,
];

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
  final lide = n.vychoziZpracovatele;
  final jediny = lide.length == 1 && lide.single > 0 ? lide.single : null;
  return _prekryj(zaklad, {
    'branch': n.vychoziPobocky,
    'department': n.vychoziUtvary,
    'folder': n.vychoziPoradace,
    'heliosStatus': n.vychoziStavyHelios,
    'responsible': n.vychoziZodpovedni,
    'assignee': lide.map(zpracovatelDoUctu).nonNulls,
    // Jméno jen u jednoho konkrétního člověka - aby šel ukázat, i když nemá
    // zakázku. U víc lidí se jména drží jen v telefonu.
    'assigneeName': [?n.jmenaZpracovatelu[jediny]],
  });
}

/// Výchozí filtr zakázek z účtu do nastavení.
Nastaveni filtrZakazekZUctu(Nastaveni n, Map<String, Object?>? filtr) {
  final zpracovatele = _zpracovateleZUctu(filtr);
  final jmenoZWebu = _text(filtr, 'assigneeName');
  return n.copyWith(
    vychoziPobocky: _seznam(filtr, 'branch'),
    vychoziUtvary: _seznam(filtr, 'department'),
    vychoziPoradace: _seznam(filtr, 'folder'),
    vychoziStavyHelios: _seznam(filtr, 'heliosStatus'),
    vychoziZodpovedni: _seznam(filtr, 'responsible'),
    vychoziZpracovatele: zpracovatele,
    jmenaZpracovatelu: {
      for (final id in zpracovatele)
        id: switch (id) {
          OrderFilter.ja => 'Já',
          OrderFilter.nikdo => 'Nikdo',
          // Bez jména (nastavil ho web) - jméno z telefonu, jinak číslo.
          _ =>
            (zpracovatele.length == 1 ? jmenoZWebu : null) ??
                n.jmenaZpracovatelu[id] ??
                'č. $id',
        },
    },
  );
}

/// Sloupce tabulky na účet a zpět.
Map<String, Object?> sloupceDoUctu(NastaveniSloupcu s) => {
  'columns': s.poradi,
  'hidden': s.skryte,
};

NastaveniSloupcu sloupceZUctu(Object? hodnota) {
  final mapa = _mapa(hodnota);
  return NastaveniSloupcu(
    poradi: _seznam(mapa, 'columns'),
    skryte: _seznam(mapa, 'hidden'),
  );
}

/// Pohled plánovače na účet.
Map<String, Object?> pohledDoUctu(PohledPlanu p, Map<String, Object?>? zaklad) {
  final f = p.filtr;
  return {
    'branch': p.pobocka,
    'weeks': p.tydnu == 2 ? 2 : 1,
    'filter': _prekryj(_mapa(zaklad?['filter']), {
      'department': f.departmentCodes,
      'folder': f.poradacKody,
      'heliosStatus': f.heliosStavy,
      'responsible': f.mechanicNames,
      'assignee': f.zpracovatelIds.map(zpracovatelDoUctu).nonNulls,
      'paintCode': p.kodLaku,
      'planStatus': p.stavPlanu.map((s) => s.name),
    }),
  };
}

/// Pohled plánovače z účtu. Hledaný text a e-mail pro „Já" zůstanou
/// z [filtru].
PohledPlanu pohledZUctu(Map<String, Object?>? ucet, OrderFilter filtr) {
  final f = _mapa(ucet?['filter']);
  final stavy = _seznam(f, 'planStatus');
  return PohledPlanu(
    pobocka: _text(ucet, 'branch'),
    tydnu: ucet?['weeks'] == 2 ? 2 : 1,
    filtr: OrderFilter(
      departmentCodes: {..._seznam(f, 'department')},
      poradacKody: {..._seznam(f, 'folder')},
      heliosStavy: {..._seznam(f, 'heliosStatus')},
      mechanicNames: {..._seznam(f, 'responsible')},
      zpracovatelIds: {..._zpracovateleZUctu(f)},
      query: filtr.query,
      sort: filtr.sort,
      mujEmail: filtr.mujEmail,
    ),
    kodLaku: {..._seznam(f, 'paintCode')},
    stavPlanu: {
      for (final s in StavPlanuFiltr.values)
        if (stavy.contains(s.name)) s,
    },
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
  // Výchozí sloupce se na účet neposílají, dokud tam žádné nejsou - jinak
  // by první změna čehokoli poslala i sloupce, které nikdo neměnil.
  if (!n.sloupce.vychozi || zaklad['ordersTable'] != null)
    'ordersTable': sloupceDoUctu(n.sloupce),
};

/// Nastavení z účtu do nastavení telefonu.
Nastaveni nastaveniZUctu(Nastaveni n, Map<String, Object?> ucet) {
  final s = filtrZakazekZUctu(n, _mapa(ucet['ordersFilter']));
  return s.copyWith(
    slozkaFotek: _text(ucet, 'photoFolder'),
    zrusSlozkuFotek: _text(ucet, 'photoFolder') == null,
    sloupce: sloupceZUctu(ucet['ordersTable']),
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
