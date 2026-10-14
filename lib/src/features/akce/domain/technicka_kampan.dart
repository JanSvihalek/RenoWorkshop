/// Technická kampaň BMW (svolávací akce) - týká se konkrétních vozidel
/// podle VIN.
///
/// Odkud se seznam vozidel bude brát natrvalo, zatím není jasné; do té
/// doby ho vkládají správci akcí (zkopírovaný z Excelu nebo z portálu BMW).
/// U zakázky se kampaně ukazují samy - server je dohledá podle VINu.
class TechnickaKampan {
  const TechnickaKampan({
    this.id,
    this.kod,
    required this.nazev,
    this.text = '',
    this.pocetVozidel = 0,
    this.zadalKdo,
  });

  /// `null` u kampaně, která se teprve zakládá.
  final String? id;

  /// Číslo kampaně od BMW, `null` = nezadané.
  final String? kod;
  final String nazev;
  final String text;

  /// Kolik VINů v kampani je.
  final int pocetVozidel;
  final String? zadalKdo;

  factory TechnickaKampan.fromJson(Map<String, dynamic> json) {
    final kod = (json['code'] as String?)?.trim();
    return TechnickaKampan(
      id: json['id'] as String?,
      kod: kod == null || kod.isEmpty ? null : kod,
      nazev: json['title'] as String? ?? '',
      text: json['text'] as String? ?? '',
      pocetVozidel: (json['vehicleCount'] as num?)?.toInt() ?? 0,
      zadalKdo: json['createdBy'] as String?,
    );
  }

  /// Tělo `POST`/`PUT` - VINy jdou vždy celé, server seznam nahradí.
  Map<String, dynamic> toJson(List<String> viny) => {
    'code': kod,
    'title': nazev,
    'text': text,
    'vins': viny,
  };

  TechnickaKampan copyWith({String? id, int? pocetVozidel}) => TechnickaKampan(
    id: id ?? this.id,
    kod: kod,
    nazev: nazev,
    text: text,
    pocetVozidel: pocetVozidel ?? this.pocetVozidel,
    zadalKdo: zadalKdo,
  );
}

/// Co server o kampaních vrátí: všechny kampaně a jestli je přihlášený
/// smí zadávat.
class PrehledKampani {
  const PrehledKampani({required this.kampane, required this.muzeUpravovat});

  final List<TechnickaKampan> kampane;
  final bool muzeUpravovat;

  factory PrehledKampani.fromJson(Map<String, dynamic> json) => PrehledKampani(
    muzeUpravovat: json['canEdit'] as bool? ?? false,
    kampane: [
      for (final k in json['campaigns'] as List<dynamic>? ?? const [])
        TechnickaKampan.fromJson(k as Map<String, dynamic>),
    ],
  );
}

/// Celý VIN (17 znaků) nebo krátký (posledních 7). Bez I, O a Q.
final _vin = RegExp(r'^(?:[A-HJ-NPR-Z0-9]{7}|[A-HJ-NPR-Z0-9]{17})$');

/// VINy z vloženého textu - z Excelu přijdou po řádcích, odjinud třeba
/// oddělené čárkou. Duplicity se vynechají, neplatné se vrátí zvlášť,
/// ať je správce opraví.
({List<String> platne, List<String> neplatne}) rozpoznejViny(String text) {
  final platne = <String>{};
  final neplatne = <String>{};
  for (final kus in text.toUpperCase().split(RegExp(r'[\s,;]+'))) {
    final vin = kus.replaceAll('-', '');
    if (vin.isEmpty) continue;
    (_vin.hasMatch(vin) ? platne : neplatne).add(vin);
  }
  return (platne: platne.toList(), neplatne: neplatne.toList());
}
