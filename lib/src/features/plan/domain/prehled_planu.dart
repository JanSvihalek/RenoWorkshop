import '../../orders/domain/entities/plan_klempirny.dart';

/// Pobočka s klempírnou - v plánu se vybírá, čí týden se ukazuje.
class PobockaPlanu {
  const PobockaPlanu({required this.kod, required this.nazev});

  /// Druhá číslice útvaru (`1` = Brno).
  final String kod;
  final String nazev;

  @override
  bool operator ==(Object other) =>
      other is PobockaPlanu && other.kod == kod && other.nazev == nazev;

  @override
  int get hashCode => Object.hash(kod, nazev);
}

/// Řádek plánu: zakázka a její blok na klempírně.
class PolozkaPlanu {
  const PolozkaPlanu({
    required this.zakazkaId,
    required this.spz,
    required this.model,
    required this.zakaznik,
    this.pobockaKod,
    this.aktivni = true,
    required this.plan,
  });

  final String zakazkaId;
  final String spz;
  final String model;
  final String zakaznik;
  final String? pobockaKod;

  /// Zakázka je v Heliosu ještě rozdělaná.
  final bool aktivni;
  final PlanKlempirny plan;

  factory PolozkaPlanu.fromJson(Map<String, dynamic> json) {
    final pobocka = json['branch'];
    return PolozkaPlanu(
      zakazkaId: json['orderId'] as String,
      spz: json['licensePlate'] as String? ?? '',
      model: json['model'] as String? ?? '',
      zakaznik: json['customerName'] as String? ?? '',
      pobockaKod: pobocka is Map<String, dynamic>
          ? pobocka['code'] as String?
          : null,
      aktivni: json['isActive'] as bool? ?? true,
      plan: PlanKlempirny.fromJson(json),
    );
  }
}

/// Plán na období: bloky, které se s ním překrývají, a pobočky klempíren.
class PrehledPlanu {
  const PrehledPlanu({required this.pobocky, required this.polozky});

  final List<PobockaPlanu> pobocky;
  final List<PolozkaPlanu> polozky;

  factory PrehledPlanu.fromJson(Map<String, dynamic> json) => PrehledPlanu(
    pobocky: [
      for (final p in json['branches'] as List<dynamic>? ?? const [])
        PobockaPlanu(
          kod: (p as Map<String, dynamic>)['code'] as String,
          nazev: p['label'] as String? ?? '',
        ),
    ],
    polozky: [
      for (final p in json['entries'] as List<dynamic>? ?? const [])
        PolozkaPlanu.fromJson(p as Map<String, dynamic>),
    ],
  );
}

/// Kód laku, který se v období opakuje - zakázky jde lakovat v jedné
/// várce.
class SpolecnyKod {
  const SpolecnyKod({required this.kod, required this.polozky});

  final String kod;
  final List<PolozkaPlanu> polozky;
}

/// Kódy laku, které mají v období aspoň dvě zakázky, od nejčastějšího.
/// Velikost písmen ani mezery okolo nehrají roli.
List<SpolecnyKod> spolecneKody(List<PolozkaPlanu> polozky) {
  final podleKodu = <String, List<PolozkaPlanu>>{};
  for (final p in polozky) {
    final kod = p.plan.kodLaku?.trim().toUpperCase();
    if (kod == null || kod.isEmpty) continue;
    (podleKodu[kod] ??= []).add(p);
  }
  return [
    for (final MapEntry(:key, :value) in podleKodu.entries)
      if (value.length >= 2) SpolecnyKod(kod: key, polozky: value),
  ]..sort((a, b) => b.polozky.length.compareTo(a.polozky.length));
}

/// Pondělí týdne, do kterého den patří.
DateTime pondeli(DateTime den) {
  // Kalendářně, ne přes Duration - při změně času by se posunula hodina.
  return DateTime(den.year, den.month, den.day - (den.weekday - 1));
}

/// Pracovní dny (po-pá) od pondělí [zacatek] na [tydnu] týdnů.
List<DateTime> pracovniDny(DateTime zacatek, int tydnu) => [
  for (var t = 0; t < tydnu; t++)
    for (var d = 0; d < 5; d++)
      DateTime(zacatek.year, zacatek.month, zacatek.day + t * 7 + d),
];
