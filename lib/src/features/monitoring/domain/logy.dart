/// Prohlížeč logů (Admin › Logy, jen admin) - jednotlivé řádky logu
/// přístupů a událostí s filtrem, řazením a stránkováním. Stejné jako
/// Admin › Logy na webu (`GET /admin/logs/access|events|options`).
library;

enum DruhLogu {
  pristupy('access', 'Přístupy'),
  udalosti('events', 'Události');

  const DruhLogu(this.kod, this.popis);
  final String kod;
  final String popis;
}

/// Sloupce, podle kterých jde řadit - kód pro službu a popisek.
const razeniPristupu = [
  ('cas', 'Čas'),
  ('email', 'Uživatel'),
  ('cesta', 'Akce'),
  ('stav', 'Stav'),
  ('trvani', 'Doba'),
];
const razeniUdalosti = [
  ('cas', 'Čas'),
  ('email', 'Uživatel'),
  ('typ', 'Typ'),
  ('nazev', 'Název'),
];

String _den(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Filtr logu. Prázdný text = nefiltruje.
class FiltrLogu {
  const FiltrLogu({
    required this.od,
    required this.do_,
    this.email = '',
    this.klient = '',
    this.zakazka = '',
    this.jenAkce = true,
    this.metoda = '',
    this.vysledek = '',
    this.cesta = '',
    this.minMs = '',
    this.typ = '',
    this.nazev = '',
    this.hledat = '',
  });

  /// Posledních 7 dní včetně dneška.
  factory FiltrLogu.vychozi(DateTime dnes) {
    final den = DateTime(dnes.year, dnes.month, dnes.day);
    return FiltrLogu(od: den.subtract(const Duration(days: 6)), do_: den);
  }

  final DateTime od;
  final DateTime do_;
  final String email;

  /// `aplikace` | `web` | `plan`.
  final String klient;
  final String zakazka;

  // Přístupy
  /// Jen co člověk udělal - bez automatického načítání (fotky a dokumenty
  /// s detailem, obnova seznamu). Chyby jsou vidět vždy.
  final bool jenAkce;
  final String metoda;

  /// `ok` | `chyby` | `4xx` | `5xx` | `401`.
  final String vysledek;
  final String cesta;
  final String minMs;

  // Události: `udalost` | `chyba` | `audit`.
  final String typ;
  final String nazev;
  final String hledat;

  FiltrLogu copyWith({
    DateTime? od,
    DateTime? do_,
    String? email,
    String? klient,
    String? zakazka,
    bool? jenAkce,
    String? metoda,
    String? vysledek,
    String? cesta,
    String? minMs,
    String? typ,
    String? nazev,
    String? hledat,
  }) => FiltrLogu(
    od: od ?? this.od,
    do_: do_ ?? this.do_,
    email: email ?? this.email,
    klient: klient ?? this.klient,
    zakazka: zakazka ?? this.zakazka,
    jenAkce: jenAkce ?? this.jenAkce,
    metoda: metoda ?? this.metoda,
    vysledek: vysledek ?? this.vysledek,
    cesta: cesta ?? this.cesta,
    minMs: minMs ?? this.minMs,
    typ: typ ?? this.typ,
    nazev: nazev ?? this.nazev,
    hledat: hledat ?? this.hledat,
  );

  /// Stejné období a volba Jen akce, jinak nic.
  FiltrLogu bezFiltru() => FiltrLogu(od: od, do_: do_, jenAkce: jenAkce);

  Map<String, String> _pole(DruhLogu druh) => {
    'email': email,
    'client': klient,
    'order': zakazka,
    if (druh == DruhLogu.pristupy) ...{
      'method': metoda,
      'result': vysledek,
      'path': cesta,
      'minMs': minMs,
    } else ...{
      'type': typ,
      'name': nazev,
      'q': hledat,
    },
  };

  /// Kolik polí filtru je vyplněných (bez období).
  int pocet(DruhLogu druh) =>
      _pole(druh).values.where((v) => v.trim().isNotEmpty).length;

  /// Query pro službu - jen neprázdná pole, která daný log zná.
  Map<String, String> dotaz(
    DruhLogu druh, {
    required String razeni,
    required bool vzestupne,
    required int offset,
    required int limit,
  }) => {
    'from': _den(od),
    'to': _den(do_),
    for (final e in _pole(druh).entries)
      if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
    if (druh == DruhLogu.pristupy) 'show': jenAkce ? 'akce' : 'vse',
    'sort': razeni,
    'dir': vzestupne ? 'asc' : 'desc',
    'offset': '$offset',
    'limit': '$limit',
  };

  @override
  bool operator ==(Object other) =>
      other is FiltrLogu &&
      other.od == od &&
      other.do_ == do_ &&
      other.email == email &&
      other.klient == klient &&
      other.zakazka == zakazka &&
      other.jenAkce == jenAkce &&
      other.metoda == metoda &&
      other.vysledek == vysledek &&
      other.cesta == cesta &&
      other.minMs == minMs &&
      other.typ == typ &&
      other.nazev == nazev &&
      other.hledat == hledat;

  @override
  int get hashCode => Object.hash(
    od,
    do_,
    email,
    klient,
    zakazka,
    jenAkce,
    metoda,
    vysledek,
    cesta,
    minMs,
    typ,
    nazev,
    hledat,
  );
}

String? _text(Object? x) => x is String && x.isNotEmpty ? x : null;
int _cislo(Object? x) => x is num ? x.toInt() : 0;
DateTime? _cas(Object? x) => x is String ? DateTime.tryParse(x) : null;

/// Jeden řádek logu - přístup nebo událost, ať je seznam jeden.
class ZaznamLogu {
  const ZaznamLogu({
    required this.id,
    required this.popis,
    this.kdy,
    this.email,
    this.jmeno,
    this.klient,
    this.verze,
    this.podpopis,
    this.zapis = false,
    this.auto = false,
    this.zakazka,
    this.stav,
    this.ms,
    this.typ,
    this.chyba,
    this.detaily = const [],
  });

  final String id;
  final DateTime? kdy;
  final String? email;
  final String? jmeno;
  final String? klient;
  final String? verze;

  /// Hlavní text: „Zapsal stav“ nebo název události.
  final String popis;

  /// Pod ním: `POST /api/orders/:id/stavy` nebo obrazovka.
  final String? podpopis;
  final bool zapis;

  /// Načetla to aplikace nebo web sami - ne akce uživatele.
  final bool auto;
  final String? zakazka;

  /// Přístupy: kód odpovědi a doba.
  final int? stav;
  final int? ms;

  /// Události: `udalost` | `chyba` | `audit`.
  final String? typ;

  /// Chyba nebo detail - krátce v řádku, celé v rozbalení.
  final String? chyba;

  /// Všechno ostatní do rozbalení.
  final List<(String, String)> detaily;

  bool get jeChyba => (stav ?? 0) >= 500 || typ == 'chyba';

  factory ZaznamLogu.pristup(Map<String, dynamic> j) => ZaznamLogu(
    id: '${j['id']}',
    kdy: _cas(j['at']),
    email: _text(j['email']),
    jmeno: _text(j['name']),
    klient: _text(j['client']),
    verze: _text(j['version']),
    popis: _text(j['label']) ?? '${j['method']} ${j['path']}',
    podpopis: '${j['method']} ${j['path']}',
    zapis: j['write'] == true,
    auto: j['auto'] == true,
    zakazka: _text(j['order']),
    stav: _cislo(j['status']),
    ms: _cislo(j['ms']),
    chyba: _text(j['error']),
    detaily: [
      for (final (k, v) in [
        ('Chyba', j['error']),
        ('Parametry', j['params']),
        ('E-mail', j['email']),
        ('Verze', j['version']),
        ('IP', j['ip']),
        ('Záznam', j['id']),
      ])
        if (_text(v is String ? v : v?.toString()) case final t?) (k, t),
    ],
  );

  factory ZaznamLogu.udalost(Map<String, dynamic> j) => ZaznamLogu(
    id: '${j['id']}',
    kdy: _cas(j['at']),
    email: _text(j['email']),
    jmeno: _text(j['name']),
    klient: _text(j['client']),
    verze: _text(j['version']),
    popis: _text(j['event']) ?? '',
    podpopis: _text(j['screen']),
    zakazka: _text(j['order']),
    typ: _text(j['type']),
    chyba: _text(j['error']) ?? _text(j['detail']),
    detaily: [
      for (final (k, v) in [
        ('Chyba', j['error']),
        ('Detail', j['detail']),
        ('Obrazovka', j['screen']),
        ('E-mail', j['email']),
        ('Zařízení', j['device']),
        ('Verze', j['version']),
        ('Přijato službou', j['receivedAt']),
        ('Záznam', j['id']),
      ])
        if (_text(v is String ? v : v?.toString()) case final t?) (k, t),
    ],
  );
}

class StrankaLogu {
  const StrankaLogu({required this.celkem, required this.polozky});

  final int celkem;
  final List<ZaznamLogu> polozky;

  factory StrankaLogu.fromJson(DruhLogu druh, Map<String, dynamic> j) =>
      StrankaLogu(
        celkem: _cislo(j['total']),
        polozky: [
          for (final p in j['items'] is List ? j['items'] as List : const [])
            if (p is Map<String, dynamic>)
              druh == DruhLogu.pristupy
                  ? ZaznamLogu.pristup(p)
                  : ZaznamLogu.udalost(p),
        ],
      );
}

/// Uživatelé a názvy událostí do výběru ve filtru.
class VolbyLogu {
  const VolbyLogu({this.uzivatele = const [], this.udalosti = const []});

  final List<({String email, String? jmeno})> uzivatele;
  final List<String> udalosti;

  factory VolbyLogu.fromJson(Map<String, dynamic> j) => VolbyLogu(
    uzivatele: [
      for (final u in j['users'] is List ? j['users'] as List : const [])
        if (u is Map<String, dynamic> && u['email'] is String)
          (email: u['email'] as String, jmeno: _text(u['name'])),
    ],
    udalosti: [
      for (final n in j['events'] is List ? j['events'] as List : const [])
        if (n is String) n,
    ],
  );
}

/// Zdroj dat - implementuje ho stejná služba jako zakázky.
abstract interface class LogyDataSource {
  Future<StrankaLogu> nactiLog(DruhLogu druh, Map<String, String> dotaz);
  Future<VolbyLogu> nactiVolbyLogu();
}
