/// Monitoring používání (jen admin) - kolik lidí RenoWorkshop používá,
/// kdy a co v něm dělají. Stejná data jako Admin › Monitoring na webu
/// (`GET /admin/monitoring`). Pomůcka k rozvoji a chybám, ne hodnocení
/// práce lidí.
library;

/// Období na výběr. Obrazovky se v logu drží jen 30 dní.
const obdobiMonitoringu = [
  (dni: 1, popisek: 'Dnes'),
  (dni: 7, popisek: '7 dní'),
  (dni: 30, popisek: '30 dní'),
  (dni: 90, popisek: '90 dní'),
];

const dnyTydne = ['Po', 'Út', 'St', 'Čt', 'Pá', 'So', 'Ne'];

/// Odkud člověk pracoval - `null` je starší aplikace (před 2.4.14).
String popisKlienta(String? klient) => switch (klient) {
  null || 'aplikace' => 'Aplikace',
  'web' => 'Web',
  'plan' => 'Plánovač',
  _ => 'Jiné',
};

int _cislo(Object? x) => x is num ? x.toInt() : 0;
String? _text(Object? x) => x is String ? x : null;
List<Map<String, dynamic>> _seznam(Object? x) => [
  for (final p in x is List ? x : const [])
    if (p is Map<String, dynamic>) p,
];

/// Místní čas bez zóny (`2026-11-19T08:12:00`) - jak ho posílá služba.
DateTime? _cas(Object? x) => x is String ? DateTime.tryParse(x) : null;

class DenMonitoringu {
  const DenMonitoringu({
    required this.datum,
    required this.lidi,
    required this.navstevy,
    required this.pozadavky,
    required this.zapisy,
    required this.podleKlienta,
  });

  final DateTime datum;
  final int lidi;
  final int navstevy;
  final int pozadavky;
  final int zapisy;
  final Map<String, int> podleKlienta;

  factory DenMonitoringu.fromJson(Map<String, dynamic> j) {
    final klienti = j['byClient'];
    return DenMonitoringu(
      datum: DateTime.parse(j['date'] as String),
      lidi: _cislo(j['users']),
      navstevy: _cislo(j['visits']),
      pozadavky: _cislo(j['requests']),
      zapisy: _cislo(j['writes']),
      podleKlienta: {
        if (klienti is Map)
          for (final e in klienti.entries) '${e.key}': _cislo(e.value),
      },
    );
  }
}

class UzivatelMonitoringu {
  const UzivatelMonitoringu({
    required this.email,
    this.jmeno,
    this.klienti = const [],
    this.verze,
    this.zarizeni,
    this.dni = 0,
    this.navstevy = 0,
    this.zapisy = 0,
    this.chyby = 0,
    this.naposledy,
  });

  final String email;
  final String? jmeno;
  final List<String> klienti;
  final String? verze;
  final String? zarizeni;
  final int dni;
  final int navstevy;
  final int zapisy;
  final int chyby;
  final DateTime? naposledy;

  String get zobrazeneJmeno => jmeno ?? email;

  factory UzivatelMonitoringu.fromJson(Map<String, dynamic> j) =>
      UzivatelMonitoringu(
        email: j['email'] as String,
        jmeno: _text(j['name']),
        klienti: [
          for (final k in j['clients'] is List ? j['clients'] as List : [])
            '$k',
        ],
        verze: _text(j['appVersion']),
        zarizeni: _text(j['device']),
        dni: _cislo(j['activeDays']),
        navstevy: _cislo(j['visits']),
        zapisy: _cislo(j['writes']),
        chyby: _cislo(j['errors']),
        naposledy: _cas(j['lastAt']),
      );
}

/// Řádek s pruhem: akce, obrazovka nebo verze.
class PolozkaPruhu {
  const PolozkaPruhu({
    required this.text,
    required this.pocet,
    this.lidi = 0,
    this.stitek,
    this.zvyraznit = false,
  });

  final String text;
  final int pocet;
  final int lidi;
  final String? stitek;
  final bool zvyraznit;
}

class ChybaMonitoringu {
  const ChybaMonitoringu({
    required this.co,
    this.kdy,
    this.kdo,
    this.odkud = 'Služba',
    this.verze,
    this.zakazka,
    this.zprava,
  });

  final DateTime? kdy;
  final String? kdo;
  final String odkud;
  final String? verze;
  final String co;
  final String? zakazka;
  final String? zprava;

  factory ChybaMonitoringu.fromJson(Map<String, dynamic> j) => ChybaMonitoringu(
    kdy: _cas(j['at']),
    kdo: _text(j['name']) ?? _text(j['email']),
    odkud: j['source'] == 'klient'
        ? popisKlienta(_text(j['client']))
        : 'Služba',
    verze: _text(j['version']),
    co: _text(j['what']) ?? '',
    zakazka: _text(j['order']),
    zprava: _text(j['message']),
  );
}

class PrehledMonitoringu {
  const PrehledMonitoringu({
    required this.dni,
    required this.od,
    required this.do_,
    this.pauzaNavstevy = 30,
    this.lidi = 0,
    this.navstevy = 0,
    this.pozadavky = 0,
    this.zapisy = 0,
    this.chybySluzby = 0,
    this.chybyKlientu = 0,
    this.prumerMs,
    this.ucty = 0,
    this.poDnech = const [],
    this.hodiny = const {},
    this.uzivatele = const [],
    this.neaktivni = const [],
    this.akce = const [],
    this.obrazovky = const [],
    this.verze = const [],
    this.chyby = const [],
  });

  final int dni;
  final DateTime od;
  final DateTime do_;
  final int pauzaNavstevy;
  final int lidi;
  final int navstevy;
  final int pozadavky;
  final int zapisy;
  final int chybySluzby;
  final int chybyKlientu;
  final int? prumerMs;
  final int ucty;
  final List<DenMonitoringu> poDnech;

  /// (den v týdnu 0 = pondělí, hodina) -> (požadavky, lidé).
  final Map<(int, int), ({int pozadavky, int lidi})> hodiny;
  final List<UzivatelMonitoringu> uzivatele;
  final List<UzivatelMonitoringu> neaktivni;
  final List<PolozkaPruhu> akce;
  final List<PolozkaPruhu> obrazovky;

  /// Nejnovější první.
  final List<PolozkaPruhu> verze;
  final List<ChybaMonitoringu> chyby;

  int get chybyCelkem => chybySluzby + chybyKlientu;
  String? get nejnovejsiVerze => verze.firstOrNull?.text;

  factory PrehledMonitoringu.fromJson(Map<String, dynamic> j) {
    final t = j['totals'] is Map<String, dynamic>
        ? j['totals'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return PrehledMonitoringu(
      dni: _cislo(j['days']),
      od: DateTime.parse(j['from'] as String),
      do_: DateTime.parse(j['to'] as String),
      pauzaNavstevy: _cislo(j['visitGapMinutes']),
      lidi: _cislo(t['users']),
      navstevy: _cislo(t['visits']),
      pozadavky: _cislo(t['requests']),
      zapisy: _cislo(t['writes']),
      chybySluzby: _cislo(t['serverErrors']),
      chybyKlientu: _cislo(t['clientErrors']),
      prumerMs: t['avgMs'] is num ? (t['avgMs'] as num).round() : null,
      ucty: _cislo(t['accounts']),
      poDnech: [
        for (final d in _seznam(j['daily'])) DenMonitoringu.fromJson(d),
      ],
      hodiny: {
        for (final h in _seznam(j['hours']))
          (_cislo(h['weekday']), _cislo(h['hour'])): (
            pozadavky: _cislo(h['requests']),
            lidi: _cislo(h['users']),
          ),
      },
      uzivatele: [
        for (final u in _seznam(j['users'])) UzivatelMonitoringu.fromJson(u),
      ],
      neaktivni: [
        for (final u in _seznam(j['inactive']))
          UzivatelMonitoringu(
            email: u['email'] as String,
            jmeno: _text(u['name']),
            naposledy: _cas(u['lastLoginAt']),
          ),
      ],
      akce: [
        for (final a in _seznam(j['actions']))
          PolozkaPruhu(
            text: _text(a['label']) ?? '',
            pocet: _cislo(a['count']),
            lidi: _cislo(a['users']),
            zvyraznit: a['write'] == true,
          ),
      ],
      obrazovky: [
        for (final o in _seznam(j['screens']))
          PolozkaPruhu(
            text: _text(o['label']) ?? '',
            pocet: _cislo(o['count']),
            lidi: _cislo(o['users']),
            stitek: popisKlienta(_text(o['client'])),
          ),
      ],
      verze: [
        for (final (i, v) in _seznam(j['versions']).indexed)
          PolozkaPruhu(
            text: _text(v['version']) ?? '',
            pocet: _cislo(v['users']),
            lidi: _cislo(v['users']),
            stitek: i == 0 ? 'nejnovější' : null,
            zvyraznit: i == 0,
          ),
      ],
      chyby: [
        for (final c in _seznam(j['errors'])) ChybaMonitoringu.fromJson(c),
      ],
    );
  }
}

/// Mřížka den v týdnu × hodina - aspoň 6–18, víc když se pracovalo dřív
/// nebo později. Síla 0–1 podle nejvytíženější hodiny.
({List<int> hodiny, List<List<({int pozadavky, int lidi, double sila})>> bunky})
mrizkaHodin(Map<(int, int), ({int pozadavky, int lidi})> hodiny) {
  final pouzite = [
    for (final e in hodiny.entries)
      if (e.value.pozadavky > 0) e.key.$2,
  ];
  final max = [
    1,
    ...hodiny.values.map((h) => h.pozadavky),
  ].reduce((a, b) => a > b ? a : b);
  final od = [6, ...pouzite].reduce((a, b) => a < b ? a : b);
  final do_ = [18, ...pouzite].reduce((a, b) => a > b ? a : b);
  final rozsah = [for (var h = od; h <= do_; h++) h];
  return (
    hodiny: rozsah,
    bunky: [
      for (var den = 0; den < 7; den++)
        [
          for (final hodina in rozsah)
            () {
              final h = hodiny[(den, hodina)];
              final pozadavky = h?.pozadavky ?? 0;
              return (
                pozadavky: pozadavky,
                lidi: h?.lidi ?? 0,
                sila: pozadavky / max,
              );
            }(),
        ],
    ],
  );
}

/// Druh řádku časové osy.
enum DruhOsy {
  cteni('Čtení'),
  zapis('Zápis'),
  obrazovka('Obrazovka'),
  udalost('Událost'),
  chyba('Chyba');

  const DruhOsy(this.popis);
  final String popis;

  static DruhOsy z(Object? kod) => switch (kod) {
    'zapis' => zapis,
    'obrazovka' => obrazovka,
    'udalost' => udalost,
    'chyba' => chyba,
    _ => cteni,
  };
}

class PolozkaOsy {
  const PolozkaOsy({
    required this.kdy,
    required this.od,
    required this.druh,
    required this.popis,
    this.pocet = 1,
    this.klient,
    this.zakazka,
    this.chyba,
  });

  /// Poslední výskyt; [od] první výskyt sbalené řady.
  final DateTime kdy;
  final DateTime od;
  final int pocet;
  final String? klient;
  final DruhOsy druh;
  final String popis;
  final String? zakazka;
  final String? chyba;

  factory PolozkaOsy.fromJson(Map<String, dynamic> j) {
    final kdy = _cas(j['at']) ?? DateTime(2026);
    return PolozkaOsy(
      kdy: kdy,
      od: _cas(j['from']) ?? kdy,
      pocet: _cislo(j['count']),
      klient: _text(j['client']),
      druh: DruhOsy.z(j['kind']),
      popis: _text(j['label']) ?? '',
      zakazka: _text(j['order']),
      chyba: _text(j['error']),
    );
  }
}

class OsaMonitoringu {
  const OsaMonitoringu({
    required this.email,
    this.jmeno,
    this.zkracena = false,
    this.polozky = const [],
  });

  final String email;
  final String? jmeno;
  final bool zkracena;
  final List<PolozkaOsy> polozky;

  factory OsaMonitoringu.fromJson(Map<String, dynamic> j) => OsaMonitoringu(
    email: j['email'] as String,
    jmeno: _text(j['name']),
    zkracena: j['truncated'] == true,
    polozky: [for (final p in _seznam(j['items'])) PolozkaOsy.fromJson(p)],
  );
}

/// Zdroj dat - implementuje ho stejná služba jako zakázky.
abstract interface class MonitoringDataSource {
  Future<PrehledMonitoringu> nactiMonitoring(int dni);
  Future<OsaMonitoringu> nactiOsuMonitoringu(String email, int dni);
}
