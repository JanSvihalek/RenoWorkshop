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

/// Plán zakázky na klempírně/lakovně - jeden blok od-do po celých dnech.
///
/// Plánují se pojistné události z klempířských útvarů (11215, 12215,
/// 15215 - seznam je na serveru). Do Heliosu se nic nezapisuje.
class PlanKlempirny {
  const PlanKlempirny({
    required this.od,
    required this.do_,
    this.kodLaku,
    this.poznamka = '',
    this.hotovo = false,
    this.zaplanoval,
    this.zaplanovano,
  });

  /// První a poslední den (oba včetně), bez času.
  final DateTime od;
  final DateTime do_;

  /// Kód laku BMW (`416`, `C4P`). `null` = nezadaný.
  final String? kodLaku;
  final String poznamka;

  /// Stav: Naplánováno, nebo Hotovo.
  final bool hotovo;
  final String? zaplanoval;
  final DateTime? zaplanovano;

  /// Kolik dní blok trvá, včetně prvního a posledního.
  int get dni => do_.difference(od).inDays + 1;

  /// Překrývá se blok s obdobím (oba konce včetně)?
  bool prekryva(DateTime zacatek, DateTime konec) =>
      !od.isAfter(konec) && !do_.isBefore(zacatek);

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
    );
  }

  Map<String, dynamic> toJson() => {
    'from': _iso(od),
    'to': _iso(do_),
    'paintCode': kodLaku,
    'note': poznamka,
    'status': hotovo ? 'hotovo' : 'naplanovano',
  };

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
