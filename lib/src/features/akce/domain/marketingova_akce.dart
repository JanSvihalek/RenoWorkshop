/// Marketingová akce - co právě platí, ať to technik při příjmu nabídne.
///
/// Akce chodí e-mailem od marketingu, v Heliosu nejsou; do aplikace je
/// zadávají správci akcí (seznam e-mailů na serveru). Zatím platí pro
/// všechny pobočky a vozy - vazba na modely a stáří vozu přijde později.
class MarketingovaAkce {
  const MarketingovaAkce({
    this.id,
    required this.nazev,
    required this.text,
    required this.od,
    required this.do_,
    this.zadalKdo,
  });

  /// `null` u akce, která se teprve zakládá.
  final String? id;
  final String nazev;
  final String text;

  /// První a poslední den platnosti (oba včetně), bez času.
  final DateTime od;
  final DateTime do_;
  final String? zadalKdo;

  /// Platí v daný den?
  bool plati(DateTime den) {
    final d = _den(den);
    return !d.isBefore(od) && !d.isAfter(do_);
  }

  /// Teprve začne.
  bool zacne(DateTime den) => _den(den).isBefore(od);

  /// Kolik dní zbývá do konce včetně dneška (končí dnes = 1).
  int zbyvaDni(DateTime den) => do_.difference(_den(den)).inDays + 1;

  /// Za kolik dní začne.
  int zacneZa(DateTime den) => od.difference(_den(den)).inDays;

  factory MarketingovaAkce.fromJson(Map<String, dynamic> json) =>
      MarketingovaAkce(
        id: json['id'] as String?,
        nazev: json['title'] as String? ?? '',
        text: json['text'] as String? ?? '',
        od: DateTime.parse(json['validFrom'] as String),
        do_: DateTime.parse(json['validTo'] as String),
        zadalKdo: json['createdBy'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'title': nazev,
    'text': text,
    'validFrom': _iso(od),
    'validTo': _iso(do_),
  };

  MarketingovaAkce copyWith({
    String? id,
    String? nazev,
    String? text,
    DateTime? od,
    DateTime? do_,
  }) => MarketingovaAkce(
    id: id ?? this.id,
    nazev: nazev ?? this.nazev,
    text: text ?? this.text,
    od: od ?? this.od,
    do_: do_ ?? this.do_,
    zadalKdo: zadalKdo,
  );

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Den bez času - akce se počítají po celých dnech.
DateTime _den(DateTime d) => DateTime(d.year, d.month, d.day);

/// Co server o akcích vrátí: akce, které ještě neskončily, a jestli je
/// přihlášený smí zadávat.
class PrehledAkci {
  const PrehledAkci({required this.akce, required this.muzeUpravovat});

  final List<MarketingovaAkce> akce;
  final bool muzeUpravovat;

  /// Akce platné v daný den.
  List<MarketingovaAkce> platne(DateTime den) =>
      akce.where((a) => a.plati(den)).toList();

  factory PrehledAkci.fromJson(Map<String, dynamic> json) => PrehledAkci(
    muzeUpravovat: json['canEdit'] as bool? ?? false,
    akce: [
      for (final a in json['campaigns'] as List<dynamic>? ?? const [])
        MarketingovaAkce.fromJson(a as Map<String, dynamic>),
    ],
  );
}
