/// Barva vozu z Heliosu (číselník barev) - kód laku a název.
class BarvaVozu {
  const BarvaVozu({required this.kod, this.nazev});

  /// Kód laku (`475`, `C4P`).
  final String kod;
  final String? nazev;

  /// `475 · Black Sapphire`, bez názvu jen kód.
  String get popis => [kod, ?nazev].join(' · ');

  /// `null`, když API barvu neposlalo nebo nemá kód.
  static BarvaVozu? zJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final kod = (json['code'] as String?)?.trim();
    if (kod == null || kod.isEmpty) return null;
    final nazev = (json['name'] as String?)?.trim();
    return BarvaVozu(
      kod: kod,
      nazev: nazev == null || nazev.isEmpty ? null : nazev,
    );
  }

  Map<String, dynamic> toJson() => {'code': kod, 'name': nazev};
}

/// Kód laku zakázky: ručně zadaný v plánu, jinak barva vozu z Heliosu.
String? kodLakuZakazky(PlanKlempirny? plan, BarvaVozu? barva) {
  final rucni = plan?.kodLaku?.trim().toUpperCase();
  if (rucni != null && rucni.isNotEmpty) return rucni;
  return barva?.kod;
}

String _isoDen(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Typ úkonu v plánu - číselník na serveru.
class TypUkonu {
  const TypUkonu({required this.kod, required this.nazev, required this.barva});

  final String kod;
  final String nazev;

  /// Pozadí pruhu v plánu, `#RRGGBB`.
  final String barva;

  /// Úkony, u kterých se lakuje - jen ty jdou do společných kódů laku.
  /// `puvodni` je plán z doby, kdy zakázka měla jediný blok.
  bool get jeLakovna => kod == 'lakovna' || kod == 'puvodni';

  factory TypUkonu.fromJson(Map<String, dynamic> json) => TypUkonu(
    kod: json['code'] as String,
    nazev: json['label'] as String? ?? '',
    barva: json['color'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'code': kod,
    'label': nazev,
    'color': barva,
  };
}

/// Úkon v plánu zakázky: typ, od-do po celých dnech, poznámka a stav.
class UkonPlanu {
  const UkonPlanu({
    required this.id,
    required this.typ,
    required this.od,
    required this.do_,
    this.poznamka = '',
    this.hotovo = false,
    this.zaplanoval,
    this.zaplanovano,
    this.upravil,
    this.upraveno,
  });

  final int id;
  final TypUkonu typ;

  /// První a poslední den (oba včetně), bez času.
  final DateTime od;
  final DateTime do_;
  final String poznamka;

  /// Stav: Naplánováno, nebo Hotovo.
  final bool hotovo;
  final String? zaplanoval;
  final DateTime? zaplanovano;

  /// Kdo a kdy úkon naposledy změnil - i tím, že ho označil jako hotový.
  final String? upravil;
  final DateTime? upraveno;

  /// Kolik dní úkon trvá, včetně prvního a posledního.
  int get dni => do_.difference(od).inDays + 1;

  /// Překrývá se úkon s obdobím (oba konce včetně)?
  bool prekryva(DateTime zacatek, DateTime konec) =>
      !od.isAfter(konec) && !do_.isBefore(zacatek);

  factory UkonPlanu.fromJson(Map<String, dynamic> json) => UkonPlanu(
    id: json['id'] as int,
    typ: TypUkonu.fromJson(json['type'] as Map<String, dynamic>),
    od: DateTime.parse(json['from'] as String),
    do_: DateTime.parse(json['to'] as String),
    poznamka: json['note'] as String? ?? '',
    hotovo: json['status'] == 'hotovo',
    zaplanoval: json['plannedBy'] as String?,
    zaplanovano: DateTime.tryParse(json['plannedAt'] as String? ?? ''),
    upravil: json['updatedBy'] as String?,
    upraveno: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': typ.toJson(),
    'from': _isoDen(od),
    'to': _isoDen(do_),
    'note': poznamka,
    'status': hotovo ? 'hotovo' : 'naplanovano',
    'plannedBy': zaplanoval,
  };
}

/// Co se z okna posílá serveru při přidání nebo úpravě úkonu. Kód laku patří
/// k celé zakázce, `null` ho smaže.
class VstupUkonu {
  const VstupUkonu({
    required this.typKod,
    required this.od,
    required this.do_,
    this.kodLaku,
    this.poznamka = '',
    this.hotovo = false,
  });

  final String typKod;
  final DateTime od;
  final DateTime do_;
  final String? kodLaku;
  final String poznamka;
  final bool hotovo;

  Map<String, dynamic> toJson() => {
    'type': typKod,
    'from': _isoDen(od),
    'to': _isoDen(do_),
    'paintCode': kodLaku,
    'note': poznamka,
    'status': hotovo ? 'hotovo' : 'naplanovano',
  };
}

/// Plán zakázky na klempírně/lakovně: libovolně úkonů a společný kód laku.
///
/// [od], [do_] a [hotovo] jsou souhrn přes všechny úkony - první až poslední
/// den, hotovo, až když je hotové všechno. Plánují se pojistné události
/// z klempířských útvarů (11215, 12215, 15215 - seznam je na serveru). Do
/// Heliosu se nic nezapisuje.
class PlanKlempirny {
  const PlanKlempirny({
    required this.od,
    required this.do_,
    this.kodLaku,
    this.poznamka = '',
    this.hotovo = false,
    this.zaplanoval,
    this.zaplanovano,
    this.ukony = const [],
  });

  /// Souhrn dopočítaný z úkonů - totéž dělá server. [ukony] nesmí být prázdné.
  factory PlanKlempirny.zUkonu(List<UkonPlanu> ukony, {String? kodLaku}) {
    final serazene = [...ukony]..sort((a, b) => a.od.compareTo(b.od));
    final prvni = serazene.first;
    return PlanKlempirny(
      od: prvni.od,
      do_: serazene.fold(
        prvni.do_,
        (konec, u) => u.do_.isAfter(konec) ? u.do_ : konec,
      ),
      kodLaku: kodLaku,
      hotovo: serazene.every((u) => u.hotovo),
      zaplanoval: prvni.zaplanoval,
      zaplanovano: prvni.zaplanovano,
      ukony: serazene,
    );
  }

  /// První a poslední den přes všechny úkony (oba včetně), bez času.
  final DateTime od;
  final DateTime do_;

  /// Kód laku BMW (`416`, `C4P`). `null` = nezadaný.
  final String? kodLaku;
  final String poznamka;

  /// Hotovo, až když jsou hotové všechny úkony.
  final bool hotovo;
  final String? zaplanoval;
  final DateTime? zaplanovano;

  /// Úkony od nejdřívějšího.
  final List<UkonPlanu> ukony;

  /// Má zakázka v období aspoň jeden úkon? Souhrn od-do nestačí, mezi úkony
  /// může být mezera.
  bool prekryva(DateTime zacatek, DateTime konec) =>
      ukony.any((u) => u.prekryva(zacatek, konec));

  factory PlanKlempirny.fromJson(Map<String, dynamic> json) {
    final kod = (json['paintCode'] as String?)?.trim();
    return PlanKlempirny(
      od: DateTime.parse(json['from'] as String),
      do_: DateTime.parse(json['to'] as String),
      kodLaku: kod == null || kod.isEmpty ? null : kod,
      poznamka: json['note'] as String? ?? '',
      hotovo: json['status'] == 'hotovo',
      zaplanoval: json['plannedBy'] as String?,
      zaplanovano: DateTime.tryParse(json['plannedAt'] as String? ?? ''),
      ukony: [
        for (final u in json['blocks'] as List<dynamic>? ?? const [])
          UkonPlanu.fromJson(u as Map<String, dynamic>),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'from': _isoDen(od),
    'to': _isoDen(do_),
    'paintCode': kodLaku,
    'note': poznamka,
    'status': hotovo ? 'hotovo' : 'naplanovano',
    'plannedBy': zaplanoval,
    'blocks': [for (final u in ukony) u.toJson()],
  };
}
