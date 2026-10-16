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

/// Řádek plánu: zakázka klempířského útvaru a její blok na klempírně,
/// pokud už ho má.
class PolozkaPlanu {
  const PolozkaPlanu({
    required this.zakazkaId,
    required this.spz,
    required this.model,
    required this.zakaznik,
    this.pobockaKod,
    this.prijato,
    this.aktivni = true,
    this.plan,
    this.barva,
  });

  final String zakazkaId;
  final String spz;
  final String model;
  final String zakaznik;
  final String? pobockaKod;

  /// Kdy vůz přijel - zakázky bez plánu jdou od nejstarší.
  final DateTime? prijato;

  /// Zakázka je v Heliosu ještě rozdělaná.
  final bool aktivni;

  /// `null` = zakázka zatím nemá plán.
  final PlanKlempirny? plan;

  /// Barva vozu z Heliosu - kód laku, když ho plán nemá.
  final BarvaVozu? barva;

  /// Kód laku: ručně zadaný v plánu, jinak z barvy vozu.
  String? get kodLaku => kodLakuZakazky(plan, barva);

  factory PolozkaPlanu.fromJson(Map<String, dynamic> json) {
    final pobocka = json['branch'];
    final plan = json['plan'];
    return PolozkaPlanu(
      zakazkaId: json['orderId'] as String,
      spz: json['licensePlate'] as String? ?? '',
      model: json['model'] as String? ?? '',
      zakaznik: json['customerName'] as String? ?? '',
      pobockaKod: pobocka is Map<String, dynamic>
          ? pobocka['code'] as String?
          : null,
      prijato: DateTime.tryParse(json['receivedAt'] as String? ?? ''),
      aktivni: json['isActive'] as bool? ?? true,
      plan: plan is Map<String, dynamic> ? PlanKlempirny.fromJson(plan) : null,
      barva: BarvaVozu.zJson(json['vehicleColor']),
    );
  }
}

/// Plán na období: všechny rozdělané zakázky klempířských útvarů (s plánem
/// i bez), zakázky s blokem v období a pobočky klempíren.
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
/// Velikost písmen ani mezery okolo nehrají roli; zakázky bez plánu nebo
/// s plánem mimo období se nepočítají.
List<SpolecnyKod> spolecneKody(
  List<PolozkaPlanu> polozky,
  DateTime od,
  DateTime do_,
) {
  final podleKodu = <String, List<PolozkaPlanu>>{};
  for (final p in polozky) {
    final plan = p.plan;
    if (plan == null || !plan.prekryva(od, do_)) continue;
    final kod = p.kodLaku;
    if (kod == null) continue;
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

/// Řádky plánu rozdělené pro osu: s blokem v období (od začátku bloku),
/// s plánem jindy a bez plánu (od nejdéle čekající).
({
  List<PolozkaPlanu> vObdobi,
  List<PolozkaPlanu> jindy,
  List<PolozkaPlanu> bezPlanu,
})
rozdelPolozky(List<PolozkaPlanu> polozky, DateTime od, DateTime do_) {
  final vObdobi = <PolozkaPlanu>[];
  final jindy = <PolozkaPlanu>[];
  final bezPlanu = <PolozkaPlanu>[];
  for (final p in polozky) {
    final plan = p.plan;
    if (plan == null) {
      bezPlanu.add(p);
    } else if (plan.prekryva(od, do_)) {
      vObdobi.add(p);
    } else {
      jindy.add(p);
    }
  }
  int podlePlanu(PolozkaPlanu a, PolozkaPlanu b) =>
      a.plan!.od.compareTo(b.plan!.od);
  final daleko = DateTime(9999);
  vObdobi.sort(podlePlanu);
  jindy.sort(podlePlanu);
  bezPlanu.sort((a, b) => (a.prijato ?? daleko).compareTo(b.prijato ?? daleko));
  return (vObdobi: vObdobi, jindy: jindy, bezPlanu: bezPlanu);
}
